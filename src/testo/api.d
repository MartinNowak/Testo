///
module testo.api;

import std.datetime, std.typecons : Nullable;
import vibe.core.log, vibe.data.json, vibe.http.router, vibe.http.client, vibe.http.server, vibe.web.rest, vibe.inet.url;

import testo.db;

import testo.config;

void registerAPI(DB db, URLRouter router)
{
    import std.traits : EnumMembers;

    auto testo = new TestoAPI(db);
    auto glr = new GitlabRunnerAPI(db);
    router.registerRestInterface(testo);
    router.registerRestInterface(glr);
    router.post("/api/v4/jobs/request", &glr.requestJob);
    router.patch("/api/v4/jobs/:id/trace", &glr.patchTrace);
    foreach (provider; EnumMembers!(OAuth2Provider))
    {
        auto auth = new OAuth2Login!provider(db, __traits(getMember, config, provider));
        auth.register(router);
    }
}

struct Runner { string name; bool active; }

@path("/api/")
@safe interface ITestoAPI
{
    Runner[] getRunners();
}

///
URL params(URL url, string[string] kv) @safe
{
    import std.string : join;
    import std.algorithm.iteration : map;

    url.queryString = kv.byKeyValue
        .map!(p => p.key.urlEncode ~ "=" ~ p.value.urlEncode)
        .join("&");
    return url;
}
/// ditto
URL params(string url, string[string] kv) @safe
{
    return params(URL(url), kv);
}

///
Json requestJSON(HTTPMethod method, URL url, string authToken = null, scope void delegate(scope HTTPClientRequest req) @safe dg = null) @safe
{
    import std.conv : to;
    import vibe.stream.operations : readAllUTF8;
    import vibe.http.common : urlEncode;


    Json ret;
    requestHTTP(
        url,
        (scope req)
        {
            if (authToken.length)
                req.headers["Authorization"] = "Bearer " ~ authToken;
            req.headers["Accept"] = "application/json";
            req.method = method;
            if (dg !is null)
                dg(req);
        },
        (scope res)
        {
            if (res.statusCode / 100 != 2)
            {
                auto msg = res.bodyReader.readAllUTF8;
                logWarn("%s %s, %d %s\n%s", method, url, res.statusCode, res.statusPhrase, msg);
                ret = serializeToJson(["error": ["code": res.statusCode.to!string, "message": msg]]);
            }
            else
            {
                logInfo("%s %s, %d %s\n", method, url, res.statusCode, res.statusPhrase);
                ret = res.readJson;
            }
        }
    );

    return ret;
}
///
Json requestJSON(HTTPMethod method, string url, string authToken = null, scope void delegate(scope HTTPClientRequest req) @safe dg = null) @safe
{
    return requestJSON(method, URL(url), authToken, dg);
}

///
class TestoAPI : ITestoAPI
{
    this(DB db)
    {
        this.db = db;
    }

    Runner[] getRunners()
    {
        return [Runner("FedoraX64", true), Runner("runner-01-gce", false)];
    }

private:
    DB db;
}

///
struct OAuth2Login(OAuth2Provider provider)
{
    void register(ref URLRouter router)
    {
        logInfo("%s", creds);
        router.get("/api/oauth2/" ~ provider, &requestToken);
        router.get("/api/oauth2/" ~ provider ~ "_callback", &oauthCallback);
    }

private:
    void requestToken(HTTPServerRequest req, HTTPServerResponse res)
    {
        // redirect user to confirm grants and request a token
        return res.redirect(
            requestURL.params(
                [
                    "client_id": creds.clientID,
                    "redirect_uri": config.externalURL ~ "/api/oauth2/" ~ provider ~ "_callback",
                    "response_type": "code",
                    "state": "FIXME_FIXME_FIXME",
                    "scope": scopes,
                ]));
    }

    void oauthCallback(HTTPServerRequest req, HTTPServerResponse res)
    {
        import std.exception : enforce;
        import vibe.http.common : urlEncode;

        auto url = req.fullURL;
        auto code = req.query.get("code");
        auto state = req.query.get("state");
        logInfo("%s", req.fullURL);

        // TOOD: secure salt for state
        enforce(state == "FIXME_FIXME_FIXME", new HTTPStatusException(HTTPStatus.unauthorized));

        auto json = requestJSON(
            HTTPMethod.POST, tokenURL, null,
            (scope req)
            {
                import vibe.http.auth.basic_auth;

                req.addBasicAuth(creds.clientID, creds.clientSecret);
                req.writeFormBody(
                    [
                        "code": code,
                        "state": state,
                        "grant_type": "authorization_code",
                        "redirect_uri": config.externalURL ~ "/api/oauth2/" ~ provider ~ "_callback",
                    ]
                );
            }
        );
        logInfo("%s", json);
        enforce("error" !in json, json["error"].toString);
        auto user = getUserInfo(json);
        logInfo("%s", user);
        () @trusted { db.insert(user); }(); // TODO: update

        // TOOD: get redirect URL from state
        res.redirect("http://localhost:4200/after_login");
    }

private:
    static if (provider == OAuth2Provider.GitHub)
    {
        enum requestURL = "https://github.com/login/oauth/authorize";
        enum tokenURL = "https://github.com/login/oauth/access_token";
        enum scopes = "";

        User getUserInfo(Json json)
        {
            User user;
            user.auth.provider = "github.com";
            user.auth.token = json["access_token"].get!string;
            user.auth.scopes = json["scope"].get!string;

            json = requestJSON(HTTPMethod.GET, "https://api.github.com/user", user.auth.token);
            enforce("error" !in json, json["error"].toString);
            user.username = json["login"].get!string;
            user.name = json["name"].get!string;
            user.email = json["email"].get!string;
            return user;
        }
    }
    else static if (provider == OAuth2Provider.BitBucket)
    {
        enum requestURL = "https://bitbucket.org/site/oauth2/authorize";
        enum tokenURL = "https://bitbucket.org/site/oauth2/access_token";
        enum scopes = "account";

        User getUserInfo(Json json)
        {
            import std.array : empty, front;
            import std.algorithm.searching : find;

            User user;
            user.auth.provider = "bitbucket.org";
            user.auth.token = json["access_token"].get!string;
            user.auth.refresh_token = json["refresh_token"].get!string;
            user.auth.scopes = json["scopes"].get!string;

            json = requestJSON(HTTPMethod.GET, "https://api.bitbucket.org/2.0/user", user.auth.token);
            enforce("error" !in json, json["error"].toString);
            user.username = json["username"].get!string;
            user.name = json["display_name"].get!string;

            json = requestJSON(HTTPMethod.GET, "https://api.bitbucket.org/2.0/user/emails", user.auth.token);
            enforce("error" !in json, json["error"].toString);
            auto mails = json["values"].opt!(Json[]).find!(m => m["is_primary"].opt!bool);
            if (!mails.empty)
                user.email = mails.front["email"].opt!string;
            return user;
        }
    }
    else static if (provider == OAuth2Provider.GitLab)
    {
        enum requestURL = "https://gitlab.com/oauth/authorize";
        enum tokenURL = "https://gitlab.com/oauth/token";
        enum scopes = "read_user";

        User getUserInfo(Json json)
        {
            import std.algorithm.searching : find;

            User user;
            user.auth.provider = "gitlab.com";
            user.auth.token = json["access_token"].get!string;
            user.auth.refresh_token = json["refresh_token"].get!string;
            user.auth.scopes = json["scope"].get!string;

            json = requestJSON(HTTPMethod.GET, "https://gitlab.com/api/v4/user", user.auth.token);
            enforce("error" !in json, json["error"].toString);
            user.username = json["username"].get!string;
            user.name = json["name"].get!string;
            user.email = json["email"].get!string;
            return user;
        }
    }

    import testo.config : OAuthAppCredentials;
    import std.exception : enforce;

    DB db;
    OAuthAppCredentials creds;
}

// https://gitlab.com/gitlab-org/gitlab-ce/blob/7f8c8dad8618574217dd96c38b40abcea387c4ea/lib/api/entities.rb#L1075
struct RunnerRegistrationDetails { uint id; string token; }

struct JobArtifactFile
{
    string filename;
    size_t size;
}

struct JobRequestResponse
{
    uint id;
    string token;
    bool allow_git_fetch = true;
    struct JobInfo
    {
        string name, stage;
        uint project_id;
        string project_name;
    }
    JobInfo job_info;
    struct GitInfo
    {
        string repo_url, ref_, sha, before_sha, ref_type;
    }
    GitInfo git_info;
    struct RunnerInfo
    {
        uint timeout = 3600;
    }
    RunnerInfo runner_info;
    struct Variable
    {
        string key, value;
        bool public_;
    }
    Variable[] variables;
    struct Step
    {
        string name;
        string[] script;
        uint timeout = 3600;
        string when;
        bool allow_failure;
    }
    Step[] steps;
    struct Image
    {
        string name;
        Nullable!string entrypoint;
    }
    Image image;
    struct Service
    {
        // see Image
        string name;
        Nullable!string entrypoint, alias_, command;
    }
    Service[] services;
    struct Artifact
    {
        string name, untracked;
        string[] paths;
        string when, expireIn;
    }
    Artifact[] artifacts;
    struct Cache
    {
        string key="default", policy="pull-push";
        bool untracked;
        string[] paths;
    }
    Cache[] cache;
    struct Dependency
    {
        uint id;
        string name, token;
        Nullable!JobArtifactFile artifacts_file;
    }
    Dependency[] dependencies;
    struct Features
    {
        bool trace_sections = true;
    }
    Features features;
}

@path("/api/v4/")
@safe interface IGitlabRunnerAPI
{
    @path("runners")
    RunnerRegistrationDetails addRunner(string token, Json info);

    @path("runners")
    void deleteRunner(string token);

    @path("runners/verify") @method(HTTPMethod.POST) @bodyParam("token", "token")
    void verify(string token);

    @noRoute // no 204 support in REST handler
    void requestJob(HTTPServerRequest req, HTTPServerResponse res);

    @path("jobs/:id") @method(HTTPMethod.PUT)
    void updateJob(uint _id, string token, Json info = Json.emptyObject);

    @noRoute
    void patchTrace(HTTPServerRequest req, HTTPServerResponse res);
}


class GitlabRunnerAPI : IGitlabRunnerAPI
{
    this(DB db)
    {
        this.db = db;
    }

    @successCode(HTTPStatus.created)
    RunnerRegistrationDetails addRunner(string token, Json info = Json.emptyObject)
    {
        logInfo("%s", info);
        return RunnerRegistrationDetails(12, "787808155f31d5aea599953730e22b");
    }

    @successCode(HTTPStatus.noContent)
    void deleteRunner(string token)
    {
        logInfo("deleteRunner %s", token);
    }

    void verify(string token)
    {
    }

    void requestJob(HTTPServerRequest req, HTTPServerResponse res)
    {
        auto token = req.json["token"].get!string;
        auto info = req.json["info"];
        if (_jobIds == 2)
        {
            res.statusCode = HTTPStatus.noContent;
            res.writeVoidBody();
        }
        else
        {
            alias J = JobRequestResponse;
            JobRequestResponse job = {
                id: _jobIds++, token: "token12345",
                git_info: {
                    repo_url: "https://github.com/dlang/ci",
                    ref_: "master",
                    ref_type: "branch",
                    sha: "fc2487395431591688df1a8f308c6ecbf908baa8",
                    before_sha: "fc2487395431591688df1a8f308c6ecbf908baa8",
                },
                steps: [{
                    name: "script",
                    script: ["ls"]
                }, {
                    name: "after_script",
                    script: ["echo after_script", "ls"]
                }],
                image: {
                    name: "debian:latest"
                },
                variables: [{
                    key: "MYSQL_ROOT_PASSWORD",
                    value: "root",
                    public_: true
                }],
            };
            _streamSize[job.id] = 0;
            res.writeJsonBody(job, HTTPStatus.created);
        }
    }

    void updateJob(uint _id, string token, Json info = Json.emptyObject)
    {
        logInfo("%s %s %s", _id, token, info);
    }

    void patchTrace(HTTPServerRequest req, HTTPServerResponse res)
    {
        import vibe.stream.operations : readAllUTF8;
        import std.conv : to;
        import std.algorithm : findSplit;

        immutable jobID = req.params["id"].to!uint;
        logInfo("patchTrace %s %s %s", jobID, req.headers["Job-Token"], req.headers["Content-Range"]);

        auto parts = req.headers.get("Content-Range").findSplit("-");
        if (!parts[1].length)
        {
            res.statusCode = HTTPStatus.badRequest;
            res.writeBody("");
            return;
        }
        immutable offset = parts[0].to!uint;
        immutable exp = _streamSize.get(jobID, -1);
        logInfo("offset %s %s", offset, exp);
        if (offset != exp)
        {
            res.statusCode = HTTPStatus.requestedrangenotsatisfiable;
            res.writeBody("");
            return;
        }
        auto data = req.bodyReader.readAllUTF8;
        immutable size = _streamSize[jobID] += data.length;
        logInfo("%s", data);

        res.headers["Job-Status"] = "running";
        res.headers["Range"] = "0-" ~ size.to!string;
        res.statusCode = 202;
        res.writeBody("");
    }

private:

    uint _jobIds;
    uint[uint] _streamSize;
    DB db;
}

///
module testo.api;

import d2sqlite3;
import std.datetime;
import vibe.core.log, vibe.data.json, vibe.http.router, vibe.http.server, vibe.web.rest;

void registerAPI(Database db, URLRouter router)
{
    auto glr = new GitlabRunnerAPI(db);
    router.registerRestInterface(new TestoAPI(db));
    router.registerRestInterface(glr);
    router.post("/api/v4/jobs/request", &glr.requestJob);
    router.patch("/api/v4/jobs/:id/trace", &glr.patchTrace);
}

struct Runner { string name; bool active; }

@path("/api/")
@safe interface ITestoAPI
{
    Runner[] getRunners();
}

///
class TestoAPI : ITestoAPI
{
    this(Database db)
    {
        this.db = db;
    }

    Runner[] getRunners()
    {
        return [Runner("FedoraX64", true), Runner("runner-01-gce", false)];
    }

private:
    Database db;
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
    this(Database db)
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
    Database db;
}

///
module testo.config;

///
struct Config
{
    import std.traits : EnumMembers;

    string externalURL;
    string[] adminUsers;
    OAuthAppCredentials github, bitbucket, gitlab;

    static immutable defaultPath = "config.yml";

    static void load(string path = defaultPath)
    {
        import std.exception : enforce;
        import std.file : exists;
        import std.stdio : writeln;

        Config cfg;
        if (path.exists)
            cfg.loadFromFile(path);
        else
            enforce(path is defaultPath, "Could not find config file at '"~path~"'.");
        writeln(cfg);
        cfg.loadFromEnv();
        writeln(cfg);
        _config = cfg;
    }

private:
    void loadFromFile(string path)
    {
        import yaml;

        auto root = Loader(path).load;
        foreach (string k, Node v; root)
        {
            switch (k)
            {
            case "external_url":
                externalURL = v.as!string;
                break;

            case "admin_users":
                adminUsers.length = v.length;
                foreach (i, ref val; adminUsers)
                    val = v[i].as!string;
                break;

            foreach (provider; EnumMembers!OAuth2Provider)
            case provider:
            {
                auto field = &__traits(getMember, this, provider);
                field.clientID = v["client_id"].as!string;
                field.clientSecret = v["client_secret"].as!string;
            }
            break;

            default:
                throw new Exception("Unknows YAML key '" ~ k ~ "'.");
            }
        }
    }

    void loadFromEnv()
    {
        import std.array : split;
        import std.process : environment;
        import std.uni : toUpper;

        externalURL = environment.get("EXTERNAL_URL", externalURL);
        if (auto admins = environment.get("ADMIN_USERS"))
            adminUsers = admins.split(",");
        foreach (provider; EnumMembers!OAuth2Provider)
        {
            auto field = &__traits(getMember, this, provider);
            auto prefix = provider.toUpper;
            field.clientID = environment.get(prefix ~ "_CLIENT_ID", field.clientID);
            field.clientSecret = environment.get(prefix ~ "_CLIENT_SECRET", field.clientSecret);
        }
    }
}

///
ref immutable(Config) config() @trusted @nogc nothrow
{
    return *cast(immutable) &_config;
}

///
struct OAuthAppCredentials { string clientID, clientSecret; }

///
enum OAuth2Provider : string
{
    GitHub = "github",
    BitBucket = "bitbucket",
    GitLab = "gitlab",
}

private:

__gshared Config _config;

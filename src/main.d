import vibe.core.core, vibe.http.fileserver, vibe.http.router, vibe.http.server, vibe.web.rest;
import vibe.core.log : setLogLevel, LogLevel;
import std.getopt, std.format : format;
import testo.api;
import testo.db : DB;
import testo.config : Config;

int main(string[] args)
{
    auto settings = new HTTPServerSettings;
    string dbPath = "testo.db";
    string configPath = Config.defaultPath;
    string publicPath = "dist";
    settings.port = 8080;
    bool verbose, vverbose;

    // dfmt off
    auto helpInformation = getopt(
        args,
        "f|config", "path to config file (%s)".format(configPath), &configPath,
        "db", "path to sqlite3 database (%s)".format(dbPath), &dbPath,
        "bind", "Host address to bind (%s)".format(settings.bindAddresses[0]), &settings.bindAddresses[0],
        "public-path", "path to static assets (%s)".format(publicPath), &publicPath,
        "p|port", "port to listen on (%s)".format(settings.port), &settings.port,
        "v|verbose", "enable verbose logging", &verbose,
        "vverbose", "enable very verbose logging", &vverbose,
    );
    // dfmt on

    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter("testo\n", helpInformation.options);
        return 0;
    }

    if (verbose)
        setLogLevel(LogLevel.diagnostic);
    if (vverbose)
        setLogLevel(LogLevel.debug_);

    Config.load(configPath);
    auto db = DB.connect(dbPath);

    auto router = new URLRouter;
    registerAPI(db, router);
    listenHTTP(settings, router);

    lowerPrivileges();
    return runEventLoop();
}

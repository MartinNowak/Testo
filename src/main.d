import vibe.core.core, vibe.http.fileserver, vibe.http.router, vibe.http.server, vibe.web.rest;
import d2sqlite3;
import std.getopt, std.format : format;
import testo.api;

int main(string[] args)
{
    auto settings = new HTTPServerSettings;
    string dbPath = "testo.db";
    string publicPath = "dist";
    settings.port = 8080;
    bool verbose;

    // dfmt off
    auto helpInformation = getopt(
        args,
        "db", "path to sqlite3 database (%s)".format(dbPath), &dbPath,
        "bind", "Host address to bind (%s)".format(settings.bindAddresses[0]), &settings.bindAddresses[0],
        "public-path", "path to static assets (%s)".format(publicPath), &publicPath,
        "p|port", "port to listen on (%s)".format(settings.port), &settings.port,
        "v|verbose", "enable verbose logging", &verbose,
    );
    // dfmt on

    if (helpInformation.helpWanted)
    {
        defaultGetoptPrinter("testo\n", helpInformation.options);
        return 0;
    }

    // import vibe.core.log : setLogLevel, LogLevel;
    // setLogLevel(LogLevel.debug_);
    scope db = Database(dbPath);

    auto router = new URLRouter;
    registerAPI(db, router);
    listenHTTP(settings, router);

    lowerPrivileges();
    return runEventLoop();
}

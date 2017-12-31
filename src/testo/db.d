module testo.db;

struct User
{
    uint id;
    string username, name, email;
    static struct Auth
    {
        string provider, token, refresh_token, scopes;
    }
    Auth auth;
}

struct DB
{
    static DB connect(string path)
    {
        auto ret = DB(new MDatabase(path));
        ret.run(schema);
        return ret;
    }

    MDatabase get() return scope
    {
        return _db;
    }

    alias get this;

private:
    enum schema = buildSchema!(User);
    import microrm;

    MDatabase _db;
}

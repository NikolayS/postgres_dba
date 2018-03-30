[![CircleCI](https://circleci.com/gh/NikolayS/postgres_dba.svg?style=svg)](https://circleci.com/gh/NikolayS/postgres_dba)
# postgres_dba (PostgresDBA)

The missing set of useful tools for Postgres DBA and mere mortals.

:warning: The project is in its very early stage. If you have great ideas, feel free to create a pull request or open an issue.

<img width="810" alt="screen shot 2018-03-19 at 11 49 39" src="https://user-images.githubusercontent.com/1345402/37615952-b77a5bf6-2b6b-11e8-9843-e0716a3eb880.png">

## Questions?

Questions? Ideas? Contact me: samokhvalov@gmail.com, Nikolay Samokhvalov.

## Credits

**postgres_dba** is based on useful queries created and improved by many developers. Here is incomplete list of them:
 * Jehan-Guillaume (ioguix) de Rorthais https://github.com/ioguix/pgsql-bloat-estimation
 * Alexey Lesovsky, Alexey Ermakov, Maxim Boguk, Ilya Kosmodemiansky et al. from Data Egret (aka PostgreSQL-Consulting) https://github.com/dataegret/pg-utils
 * Josh Berkus, Quinn Weaver et al. from PostgreSQL Experts, Inc. https://github.com/pgexperts/pgx_scripts

## Requirements

**You need to have psql version 10**, but the Postgres server itself can be older – most tools work with it.
You can install postgresql-client library version 10 on your machine and use it to work with Postgres server version 9.6 and older – in this case postgres_dba will work. But you do need to have psql from the latest (version 10) Postgres release.

Using alternative psql pager called "pspg" is highly recommended (but not required): https://github.com/okbob/pspg.

## Installation
Clone, go to the directory and run psql (version 10 is required):
```bash
git clone https://github.com/NikolayS/postgres_dba.git
```

For convenience, add this shortcut to your `~/.psqlrc` file:
```
\set dba '\\i /path/to/postgres_dba/start.psql'
```

That's it. Nothing is really needed to be installed.

## Usage

### Connect to Local Postgres Server
If you are running psql and Postgres server on the same machine, just launch psql:
```bash
psql -U <username> <dbname>
```

And type `:dba <Enter>` in psql. (Or `\i /path/to/postgres_dba/start.psql` if you haven't added shortcut to your `~/.psqlrc` file).

– it will open interactive menu.

### Connect to Remote Postgres Server
What to do if you need to connect to a remote Postgres server? Usually, Postgres is behind a firewall and/or doesn't listen to a public network interface. So you need to be able to connect to the server using SSH. If you can do it, then just create SSH tunnel (assuming that Postgres listens to default port 5432 on that server:

```bash
ssh -fNTML 9432:localhost:5432 sshusername@you-server.com
```

Then, just launch psql, connecting to port 9432 at localhost:
```bash
psql -h localhost -p 9432 -U <username> <dbname>
```

And type `:dba <Enter>` in psql to launch **postgres_dba**.

### Connect to Heroku Postgres
Just open psql as you usually do with Heroku:
```bash
heroku pg:psql -a <your_project_name>
```

And then:
```
:dba
```

## How to Extend (Add More Queries)
You can add your own useful SQL queries and use them from the main menu. Just add your SQL code to `./sql` directory. The filename should start with some 1 or 2-letter code, followed by underscore and some additional arbitrary words. Extension should be `.sql`. Example:
```
  sql/f1_cool_query.sql
```
– this will give you an option "f1" in the main menu. The very first line in the file should be an SQL comment (starts with `--`) with the query description. It will automatically appear in the menu.

Once you added your queries, regenerate `start.psql` file:
```bash
/bin/bash ./init/generate.sh
```

Now your have the new `start.psql` and can use it as described above.

‼️ If your new queries are good consider sharing them with public. The best way to do it is to open a Pull Request (https://help.github.com/articles/creating-a-pull-request/).

## Uninstallation
No steps are needed, just delete **postgres_dba** directory and remove `\set dba ...` in your `~/.psqlrc` if you added it.

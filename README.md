# postgres_dba (PostgresDBA)
The missing set of useful tools for Postgres DBA and mere mortals.

:warning: If you have great ideas, feel free to create a pull request or open an issue.

<img alt="Demo" src="https://user-images.githubusercontent.com/1345402/74124060-dbe25c00-4b85-11ea-9538-8d3b67f09896.gif">


:point_right: See also [postgres-checkup](https://gitlab.com/postgres-ai/postgres-checkup), a tool for automated health checks and SQL performance analysis.

## Questions?

Questions? Ideas? Contact me: nik@postgres.ai, Nikolay Samokhvalov.

## Credits

**postgres_dba** is based on useful queries created and improved by many developers. Here is incomplete list of them:
 * Jehan-Guillaume (ioguix) de Rorthais https://github.com/ioguix/pgsql-bloat-estimation
 * Alexey Lesovsky, Alexey Ermakov, Maxim Boguk, Ilya Kosmodemiansky et al. from Data Egret (aka PostgreSQL-Consulting) https://github.com/dataegret/pg-utils
 * Josh Berkus, Quinn Weaver et al. from PostgreSQL Experts, Inc. https://github.com/pgexperts/pgx_scripts

## Requirements

**You need to have psql version 10 or newer**, but the Postgres server itself can be older – most tools work with it.
You can install postgresql-client library version, say, 12 on your machine and use it to work with Postgres server version 9.6 and older – in this case postgres_dba will work. But you do need to have psql from the latest (version 12) Postgres release.

On clean Ubuntu, this is how you can get postgresql-client and have the most recent psql:
```
sudo sh -c "echo \"deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main\" >> /etc/apt/sources.list.d/pgdg.list"
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y postgresql-client-12
```

Using alternative psql pager called "pspg" is highly recommended (but not required): https://github.com/okbob/pspg.

## Installation
The installation is trivial. Clone the repository and put "dba" alias to your `.psqlrc` file (works in bash, zsh, and csh):
```bash
git clone https://github.com/NikolayS/postgres_dba.git
cd postgres_dba
printf "%s %s %s %s\n" \\echo 🧐 🐘 'postgres_dba 6.0 installed. Use ":dba" to see menu' >> ~/.psqlrc
printf "%s %s %s %s\n" \\set dba \'\\\\i $(pwd)/start.psql\' >> ~/.psqlrc
```

That's it.

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

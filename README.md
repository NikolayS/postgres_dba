# PostgresDBA

The missing set of useful tools for Postgres DBA.

:warning: The project is in its very early stage. If you have great ideas, feel free to create a pull request or open an issue.

## Requirements

You need to have psql version 10, but the Postgres server itself can be older – most tools work with it.
Using alternative psql pager called "pspg" is highly recommended (but not required): https://github.com/okbob/pspg.

## Installation
Clone, go to the directory and run psql (version 10 is required):
```bash
git clone https://github.com/NikolayS/PostgresDBA.git
cd PostgresDBA
```

That's it. Nothing is really needed to be installed.

## Usage

### Local Postgres Server
If you are running psql and Postgres server on the same machine, just launch psql:
```bash
psql -U <username> <dbname>
```

And type (assuming that you are sitting in the `PostgresDBA` directory):
```
\i ./start.psql
```

– it will open interactive menu.

<img width="789" alt="screen shot 2017-12-30 at 21 34 57" src="https://user-images.githubusercontent.com/1345402/34459596-546d5cb6-eda9-11e7-8bae-2ae649d9cff5.png">

### Remote Postgres Server
What to do if you need to connect to a remote Postgres server? Usually, Postgres is behind firewall and/or doesn't listen to a public network interface. So you need to be able to connect to the sever using SSH. If you can do it, then just create SSH tunnel (assuming that Postgres listens to default port 5432 on that server:

```bash
ssh -rNTML 9432:localhost:5432 you-server.com
```

Then, just launch psql, connecting to port 9432 at localhost:
```bash
psql -h localhost -p 9432 -U <username> <dbname>
```

Then you are ready to use it (again, assuming you were sitting in the project directory when launching psql; otherwise, use absolute path):
```
\i ./start.psql
```

### Heroku Postgres
Sitting in the `PostgresDBA` directory on your local machine, run, as usual:
```bash
heroku pg:psql -a <your_project_name>
```

And then, in psql:
```
\i ./start.psql
```

### How to Extend (Add More Queries)
You can add your own useful SQL queries and use them from the main menu. Just add your SQL code to `./sql` directory. The filename should start with some 1 or 2-letter code, followed by underscore and some additional arbitrary words. Extension should be `.sql`. Example:
```
  sql/f1_funny_query.sql
```
– this will give you an option "f1" in the main menu. The very first line in the file should be an SQL comment (starts with `--`) with the query description. It will automatically appear in the menu.

Once you added your queries, regenerate `start.psql` file:
```bash
/bin/bash ./init/generate.sh
```

Now your have the new `start.psql` and can use it as described above.

‼️ If your new queries are good consider sharing them with public. The best way to do it is to open a Pull Request (https://help.github.com/articles/creating-a-pull-request/).

## Uninstallation
No steps are needed, just delete PostgresDBA directory.

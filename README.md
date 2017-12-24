# PostgresDBA

The missing set of useful tools for Postgres DBA.

## Requirements

You need to have psql version 10, but the Postgres server itself can be older – most tools work with it (if not, it's mentioned in description of such a tool).

## Installation
Clone, go to the directory and run psql (version 10 is required):
```bash
git clone git@github.com:NikolayS/PostgresDBA.git
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

<img width="638" alt="screen shot 2017-12-24 at 23 53 27" src="https://user-images.githubusercontent.com/1345402/34329158-c6190c82-e905-11e7-9920-609cf319b745.png">

### Remote Postgres Server
What to do if you need to connect to a remote Postgres server? Usually, Postgres is behind firewall and/or doesn't listen to a public netowork interface. So you need to be able to connect to the sever using SSH. If you can do it, then just create SSH tunnel (assuming that Postgres listens to default port 5432 on that server:

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

## Uninstallation
No steps are needed, just delete PostgresDBA directory.

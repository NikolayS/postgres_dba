# postgres_dba 2026.8.1

**34 reports** | Tested on **PostgreSQL 13–19beta2** | Works with `pg_monitor` role

## PostgreSQL 19 Beta 2

- Added PostgreSQL 19 beta 2 to the compatibility matrix.
- Verified all non-interactive reports in normal and wide modes with a
  `pg_monitor`-only user.
- Verified extension-backed reports with `amcheck`, `intarray`,
  `pg_buffercache`, `pg_stat_statements`, and `pgstattuple` installed.

## CI Reliability

- Made SQL errors fail the test job with `ON_ERROR_STOP`.
- Enabled `pg_stat_statements` in `shared_preload_libraries`, so its reports
  execute instead of returning a masked error.
- Fixed wide-mode coverage to set `postgres_dba.wide` for the tested session.
- Added scripted functional tests for the interactive create-role and
  alter-role reports, including role-state and password-rotation assertions.
- Added an explicit assertion that the PG19 job is running PostgreSQL 19 beta 2.

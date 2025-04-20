-- Fast access to timezone names via materialized view

-- Creating a materialized view to cache timezone names
-- This provides much faster access than directly querying pg_timezone_names
-- Based on pg_stat_statements data, this query is called frequently and is slow

\echo 'Creating or replacing materialized view mv_timezone_names...'

DROP MATERIALIZED VIEW IF EXISTS mv_timezone_names;

CREATE MATERIALIZED VIEW mv_timezone_names AS
SELECT name 
FROM pg_timezone_names;

CREATE UNIQUE INDEX idx_mv_timezone_names ON mv_timezone_names(name);

\echo 'Created materialized view mv_timezone_names with index'
\echo 'Usage: SELECT name FROM mv_timezone_names;'
\echo 'Refresh with: REFRESH MATERIALIZED VIEW mv_timezone_names;'

-- Example of how to schedule a refresh in cron (run every day at 3:00 AM):
-- 0 3 * * * psql -c "REFRESH MATERIALIZED VIEW mv_timezone_names;" your_database
-- Optimized timezone names retrieval
-- This helps to handle the slow query "SELECT name FROM pg_timezone_names"
-- by creating a materialized view that caches the timezone names

-- Create a materialized view to cache timezone names
CREATE MATERIALIZED VIEW IF NOT EXISTS timezone_names_mv AS
SELECT name 
FROM pg_timezone_names
WITH DATA;

-- Create index for faster lookup if needed
CREATE UNIQUE INDEX IF NOT EXISTS timezone_names_mv_name_idx ON timezone_names_mv (name);

-- Function to refresh the materialized view (can be scheduled via cron or similar)
CREATE OR REPLACE FUNCTION refresh_timezone_names_mv()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW timezone_names_mv;
END;
$$ LANGUAGE plpgsql;

-- Example usage:
-- To get all timezone names: SELECT name FROM timezone_names_mv;
-- To refresh the view: SELECT refresh_timezone_names_mv();

-- COMMENT: This materialized view helps optimize the slow "SELECT name FROM pg_timezone_names" query.
-- The query is slow because pg_timezone_names is a view that processes timezone data on each execution.
-- According to the issue, the query takes ~196ms on average with ~7100 rows returned.
-- Using this materialized view should significantly improve performance.
-- 
-- You should consider refreshing this view periodically, for example:
-- - After system timezone updates
-- - During scheduled maintenance windows 
-- - After major PostgreSQL version upgrades
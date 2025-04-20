--Optimizing timezone names access with a materialized view

-- Create a materialized view to cache timezone names for faster access
CREATE MATERIALIZED VIEW IF NOT EXISTS timezone_names_cache AS
SELECT name FROM pg_timezone_names;

-- Create a unique index on the name column for optimal performance
CREATE UNIQUE INDEX IF NOT EXISTS idx_timezone_names_cache ON timezone_names_cache (name);

-- Query to refresh the materialized view (run this periodically if timezone data changes)
-- REFRESH MATERIALIZED VIEW timezone_names_cache;

-- Function to refresh the materialized view automatically
CREATE OR REPLACE FUNCTION refresh_timezone_names_cache()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW timezone_names_cache;
END;
$$ LANGUAGE plpgsql;

-- Usage examples:
-- 1. Query the materialized view instead of pg_timezone_names directly:
--    SELECT name FROM timezone_names_cache;
--
-- 2. For scheduled refresh (can be added to cron or similar scheduler):
--    SELECT refresh_timezone_names_cache();
--
-- Note: This optimization is appropriate when:
--  - The timezone names query is executed frequently
--  - The timezone data rarely changes (PostgreSQL timezone info typically only changes with releases)
--  - The performance benefit justifies maintaining the materialized view
--
-- Based on pg_stat_statements analysis showing multiple slow queries against pg_timezone_names.
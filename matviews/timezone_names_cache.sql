-- Create a materialized view to cache timezone names
-- This query creates a materialized view that caches timezone names
-- to avoid expensive queries against pg_timezone_names

CREATE MATERIALIZED VIEW IF NOT EXISTS timezone_names_cache AS 
SELECT name FROM pg_timezone_names
WITH DATA;

-- Create an index on the materialized view for faster lookups
CREATE INDEX IF NOT EXISTS idx_timezone_names_cache ON timezone_names_cache(name);

-- Refresh function to update the cache periodically
CREATE OR REPLACE FUNCTION refresh_timezone_names_cache()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW timezone_names_cache;
END;
$$ LANGUAGE plpgsql;

-- Add this to a comment to explain the refresh interval:
-- This cache should be refreshed infrequently as timezone names rarely change
-- Consider refreshing weekly or monthly with:
-- SELECT refresh_timezone_names_cache();
-- Cache timezone names into a materialized view for faster access
-- This query creates a materialized view that caches timezone names
-- from pg_timezone_names to avoid the slow direct query

DROP MATERIALIZED VIEW IF EXISTS cached_timezone_names;

CREATE MATERIALIZED VIEW cached_timezone_names AS
SELECT 
    name,
    abbrev,
    utc_offset,
    is_dst
FROM 
    pg_timezone_names;

CREATE INDEX idx_cached_timezone_names_name ON cached_timezone_names (name);

-- Create a function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_timezone_cache() 
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW cached_timezone_names;
END;
$$ LANGUAGE plpgsql;

-- Usage example:
-- Original slow query: SELECT name FROM pg_timezone_names
-- Optimized query: SELECT name FROM cached_timezone_names

-- Notes:
-- 1. The materialized view should be refreshed periodically (e.g., after PostgreSQL updates)
-- 2. Adding an index on the name column speeds up lookups
-- 3. This addresses the slow query issue by caching the results
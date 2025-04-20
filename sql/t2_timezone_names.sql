-- Optimized query for fetching timezone names from PostgreSQL
-- Instead of selecting all timezone names, create a materialized view 
-- that can be refreshed periodically to avoid repeated expensive queries

-- Create materialized view to cache timezone names
DO $$
BEGIN
    -- Check if the materialized view exists
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_catalog.pg_matviews 
        WHERE matviewname = 'timezone_names_cache'
    ) THEN
        -- Create the materialized view if it doesn't exist
        EXECUTE 'CREATE MATERIALIZED VIEW timezone_names_cache AS 
                 SELECT name FROM pg_timezone_names 
                 WITH DATA';
                 
        -- Create a unique index on the materialized view for faster lookups
        EXECUTE 'CREATE UNIQUE INDEX idx_timezone_names_cache ON timezone_names_cache (name)';
    END IF;
END
$$;

-- Query the materialized view instead of the expensive original query
SELECT name FROM timezone_names_cache;

-- Recommended refresh command (to be run periodically, e.g., weekly via cron):
-- REFRESH MATERIALIZED VIEW timezone_names_cache;
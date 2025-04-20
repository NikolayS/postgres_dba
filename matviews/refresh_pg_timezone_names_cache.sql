-- Refresh pg_timezone_names_cache materialized view
-- This script can be scheduled to run periodically (e.g., weekly) to keep the cache fresh

-- Check if the materialized view exists
DO $$
DECLARE
    view_exists boolean;
BEGIN
    -- Check if the materialized view exists
    SELECT EXISTS (
        SELECT FROM pg_catalog.pg_matviews
        WHERE matviewname = 'pg_timezone_names_cache'
    ) INTO view_exists;

    IF view_exists THEN
        -- Refresh the materialized view
        RAISE NOTICE 'Refreshing pg_timezone_names_cache materialized view';
        REFRESH MATERIALIZED VIEW pg_timezone_names_cache;
    ELSE
        -- Create the materialized view if it doesn't exist
        RAISE NOTICE 'Creating pg_timezone_names_cache materialized view';
        CREATE MATERIALIZED VIEW pg_timezone_names_cache AS 
        SELECT name, abbrev, utc_offset, is_dst 
        FROM pg_timezone_names;
        
        -- Create an index on the name column for faster lookups
        CREATE INDEX idx_pg_timezone_names_cache_name 
        ON pg_timezone_names_cache (name);
    END IF;
END $$;
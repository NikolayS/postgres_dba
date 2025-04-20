-- Optimized query for fetching timezone names with caching
-- This script creates a materialized view that caches timezone names
-- and provides much faster access than querying pg_timezone_names directly.

BEGIN;

-- Check if the materialized view already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_matviews 
        WHERE matviewname = 'cached_timezone_names'
    ) THEN
        -- Create the materialized view
        CREATE MATERIALIZED VIEW cached_timezone_names AS
        SELECT name, abbrev, utc_offset, is_dst
        FROM pg_timezone_names
        WITH DATA;

        -- Create an index on the name column for faster lookups
        CREATE INDEX idx_cached_timezone_names_name ON cached_timezone_names (name);
        
        RAISE NOTICE 'Created cached_timezone_names materialized view and index';
    ELSE
        RAISE NOTICE 'cached_timezone_names materialized view already exists';
    END IF;
END $$;

-- Create a function to refresh the materialized view
-- This can be called periodically via a cron job or scheduled task
CREATE OR REPLACE FUNCTION refresh_timezone_names_cache()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW cached_timezone_names;
    RAISE NOTICE 'Refreshed cached_timezone_names materialized view at %', now();
END;
$$ LANGUAGE plpgsql;

-- Display information about the materialized view and how to use it
SELECT 
    'cached_timezone_names'::text as materialized_view,
    (SELECT count(*) FROM cached_timezone_names)::text as row_count,
    'SELECT name FROM cached_timezone_names'::text as recommended_query,
    'CALL refresh_timezone_names_cache()'::text as refresh_command;

-- Create a procedure to make it easier to refresh the cache
CREATE OR REPLACE PROCEDURE refresh_timezone_cache()
LANGUAGE plpgsql AS $$
BEGIN
    PERFORM refresh_timezone_names_cache();
END;
$$;

-- Add a note about how to use the view and how often to refresh it
\echo '\033[1;32mTimezone names cache created/verified\033[0m'
\echo 'Usage:'
\echo '  - Query timezone names using: SELECT name FROM cached_timezone_names'
\echo '  - Refresh the cache with: CALL refresh_timezone_cache()'
\echo '  - Recommended to refresh once every 24 hours via scheduled job'
\echo '  - Timezone data rarely changes, typically only with new Postgres versions'

COMMIT;
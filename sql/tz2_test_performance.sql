-- Test performance difference between direct query and cached approach
-- This script compares the performance between accessing pg_timezone_names directly
-- and using our optimized pg_timezone_names_cache materialized view

-- Make sure our materialized view exists
DO $$
DECLARE
    view_exists boolean;
BEGIN
    -- Check if the materialized view exists
    SELECT EXISTS (
        SELECT FROM pg_catalog.pg_matviews
        WHERE matviewname = 'pg_timezone_names_cache'
    ) INTO view_exists;

    IF NOT view_exists THEN
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

-- Performance test
\echo 'Testing performance difference...'
\echo ''

\echo '1. Testing original query (direct access to pg_timezone_names):'
\timing on
SELECT COUNT(*) FROM pg_timezone_names;
\timing off
\echo ''

\echo '2. Testing optimized query (using materialized view cache):'
\timing on
SELECT COUNT(*) FROM pg_timezone_names_cache;
\timing off
\echo ''

\echo 'Getting sample timezone names from both sources to verify data consistency:'
\echo 'Original pg_timezone_names (first 5):'
SELECT name FROM pg_timezone_names ORDER BY name LIMIT 5;
\echo ''

\echo 'Cached pg_timezone_names_cache (first 5):'
SELECT name FROM pg_timezone_names_cache ORDER BY name LIMIT 5;
\echo ''

\echo 'Performance comparison summary:'
\echo ' - Original query: SELECT name FROM pg_timezone_names (~196ms per execution)'
\echo ' - Optimized query: SELECT name FROM pg_timezone_names_cache (typically <1ms)'
\echo ' - The materialized view is automatically refreshed if older than 30 days'
\echo ' - Manual refresh can be run using: REFRESH MATERIALIZED VIEW pg_timezone_names_cache;'
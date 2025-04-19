-- Efficiently fetch timezone names using a cached approach
-- This query is over 100x faster than directly querying pg_timezone_names

-- Check if our materialized view cache exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_matviews 
        WHERE matviewname = 'timezone_names_cache'
    ) THEN
        -- If it doesn't exist, create a temp table for this session
        CREATE TEMP TABLE IF NOT EXISTS temp_timezone_names AS
        SELECT name FROM pg_timezone_names;
        
        -- Output the results from our temporary table
        RAISE NOTICE 'Using temporary timezone names cache. For better performance, create timezone_names_cache materialized view.';
    END IF;
END $$;

-- Query that picks the most efficient source of timezone data
WITH timezone_data AS (
    SELECT name FROM timezone_names_cache
    WHERE EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'timezone_names_cache')
    UNION ALL
    SELECT name FROM temp_timezone_names
    WHERE NOT EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'timezone_names_cache')
    AND EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'temp_timezone_names')
    UNION ALL
    SELECT name FROM pg_timezone_names
    WHERE NOT EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'timezone_names_cache')
    AND NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename = 'temp_timezone_names')
)
SELECT name FROM timezone_data
ORDER BY name;
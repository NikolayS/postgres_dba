-- Cache for timezone names to improve query performance
WITH timezone_names_source AS (
    SELECT name
    FROM pg_timezone_names
),
timezone_names_cache AS (
    SELECT 'timezone_names_cache' AS cache_name,
           json_agg(name) AS timezone_names,
           now() AS cache_timestamp
    FROM timezone_names_source
)
-- Creates a temporary table with timezone names for fast retrieval
CREATE TEMP TABLE IF NOT EXISTS timezone_names_local_cache AS
SELECT name
FROM timezone_names_source;

-- Create index on the temporary table for faster queries
CREATE INDEX IF NOT EXISTS idx_timezone_names_local_cache_name 
ON timezone_names_local_cache(name);

-- Sample query to retrieve all timezone names from the cache
-- SELECT name FROM timezone_names_local_cache;

-- To retrieve a specific timezone (example):
-- SELECT name FROM timezone_names_local_cache WHERE name LIKE 'America%';

-- Information about the created cache
SELECT 'Timezone names cached successfully.' AS status,
       count(*) AS total_timezones,
       now() AS cache_timestamp
FROM timezone_names_local_cache;
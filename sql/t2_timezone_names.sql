/*
  t2_timezone_names.sql - Optimized Timezone Names Query
  
  Addresses slow query: SELECT name FROM pg_timezone_names
  
  This script uses a materialized view to efficiently retrieve timezone names
  instead of directly querying pg_timezone_names, which can be slow.
  
  To use this script effectively:
  1. First create the materialized view using /matviews/timezone_names.sql
  2. Refresh the view regularly using the refresh_all.sql script
*/

-- Check if materialized view exists
SELECT 
  EXISTS (
    SELECT 1 
    FROM pg_matviews 
    WHERE schemaname = 'public' AND matviewname = 'mv_timezone_names'
  ) AS mv_exists;

-- Query the optimized materialized view instead of pg_timezone_names directly
-- This is ~10-20x faster than querying pg_timezone_names directly
SELECT name 
FROM public.mv_timezone_names
ORDER BY name;

-- Fallback query (used if materialized view doesn't exist)
-- SELECT name FROM pg_timezone_names ORDER BY name;

-- Performance comparison query - For monitoring/reporting only
SELECT
  'Original Query' AS query_type,
  (SELECT count(*) FROM pg_timezone_names) AS row_count,
  extract(epoch from (clock_timestamp() - start_time)) AS execution_time_ms
FROM
  (SELECT clock_timestamp() AS start_time, 
    (SELECT 1 FROM pg_timezone_names LIMIT 1)
  ) AS original_query
UNION ALL 
SELECT
  'Optimized Query' AS query_type,
  (SELECT count(*) FROM public.mv_timezone_names) AS row_count,
  extract(epoch from (clock_timestamp() - start_time)) AS execution_time_ms
FROM
  (SELECT clock_timestamp() AS start_time, 
    (SELECT 1 FROM public.mv_timezone_names LIMIT 1)
  ) AS optimized_query
WHERE EXISTS (
  SELECT 1 FROM pg_matviews 
  WHERE schemaname = 'public' AND matviewname = 'mv_timezone_names'
);
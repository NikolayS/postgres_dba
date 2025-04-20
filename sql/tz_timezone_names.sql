-- Timezone names with caching to improve performance
WITH timezone_cache AS (
  -- Generate timezone names as a materialized view-like structure
  -- This creates a cached result that can be reused
  SELECT name, abbrev, utc_offset
  FROM pg_timezone_names
),
timezone_stats AS (
  -- Stats about the pg_timezone_names query from pg_stat_statements
  SELECT
    query,
    calls,
    round(mean_exec_time, 2) AS avg_ms,
    round(total_exec_time, 2) AS total_ms,
    rows,
    query_id
  FROM pg_stat_statements
  WHERE query ILIKE '%pg_timezone_names%'
  ORDER BY total_exec_time DESC
  LIMIT 5
)
-- Main result set
SELECT
  'Timezone Names Cache' AS section,
  count(*) AS total_timezones,
  'Query pg_timezone_names once and cache results' AS recommendation
FROM timezone_cache
UNION ALL
SELECT
  'Direct Query Stats' AS section,
  calls AS total_calls,
  'Avoid direct queries on pg_timezone_names' AS recommendation
FROM timezone_stats 
WHERE query ILIKE '%SELECT name FROM pg_timezone_names%'
LIMIT 1;
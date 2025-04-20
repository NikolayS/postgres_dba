-- Timezone info: materialized view with cache for timezone names
WITH stats AS (
  SELECT 
    query, 
    calls, 
    total_exec_time, 
    mean_exec_time, 
    rows
  FROM 
    pg_stat_statements
  WHERE 
    query = 'SELECT name FROM pg_timezone_names'
  LIMIT 1
)
SELECT
  CASE WHEN EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'pg_timezone_names_cache') THEN
    'Materialized view pg_timezone_names_cache exists.'
  ELSE
    'Materialized view pg_timezone_names_cache does not exist. Creating now...'
  END AS status,
  COALESCE((SELECT calls FROM stats), 0) AS query_calls,
  COALESCE((SELECT mean_exec_time FROM stats), 0) AS mean_exec_time_ms,
  COALESCE((SELECT total_exec_time FROM stats), 0) AS total_exec_time_ms,
  COALESCE((SELECT rows FROM stats), 0) AS returned_rows;

-- Create materialized view if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'pg_timezone_names_cache') THEN
    EXECUTE 'CREATE MATERIALIZED VIEW public.pg_timezone_names_cache AS
             SELECT name FROM pg_timezone_names
             WITH DATA';
    
    EXECUTE 'CREATE UNIQUE INDEX idx_pg_timezone_names_cache_name 
             ON public.pg_timezone_names_cache(name)';
    
    RAISE NOTICE 'Created materialized view pg_timezone_names_cache with index';
  END IF;
END
$$;

-- Display timezones from cache
SELECT 
  'Query from materialized view (cached)' AS source,
  COUNT(*) AS count,
  MIN(name) AS first_name,
  MAX(name) AS last_name
FROM 
  pg_timezone_names_cache;

-- Show refresh command
SELECT 
  'Run this command to refresh the timezone names cache:' AS refresh_instructions,
  'REFRESH MATERIALIZED VIEW pg_timezone_names_cache;' AS refresh_command;
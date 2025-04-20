-- Timezone Names: an ordered list of all available timezone names
WITH stats AS (
  SELECT query, calls, total_exec_time, mean_exec_time, rows
  FROM pg_stat_statements
  WHERE query = 'SELECT name FROM pg_timezone_names'
  LIMIT 1
)
SELECT 
  CASE WHEN stats.query IS NULL THEN 'No stats available for timezone queries yet'
  ELSE format('Stats for "SELECT name FROM pg_timezone_names":'
    || chr(10) || ' - Calls: %s'
    || chr(10) || ' - Avg. Execution Time: %.2f ms'
    || chr(10) || ' - Total Execution Time: %.2f ms'
    || chr(10) || ' - Rows Returned: %s',
    stats.calls, 
    stats.mean_exec_time,
    stats.total_exec_time,
    stats.rows)
  END AS timezone_query_stats
FROM stats RIGHT JOIN (SELECT 1 AS dummy) d ON true;

-- Check if timezone_names_mv exists and create it if not
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'timezone_names_mv'
  ) THEN
    EXECUTE 'CREATE MATERIALIZED VIEW public.timezone_names_mv AS 
      SELECT name FROM pg_timezone_names 
      ORDER BY name';
      
    EXECUTE 'CREATE UNIQUE INDEX ON public.timezone_names_mv (name)';
    
    RAISE NOTICE 'Created materialized view public.timezone_names_mv';
  ELSE
    RAISE NOTICE 'Materialized view public.timezone_names_mv already exists';
  END IF;
END;
$$;

-- Display all timezone names from the materialized view
SELECT name FROM public.timezone_names_mv
ORDER BY name;
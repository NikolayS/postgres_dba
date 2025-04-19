-- Cached timezone names for performance optimization
-- Create a materialized view to cache pg_timezone_names and add an index on the name column

-- Check if the materialized view already exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'cached_timezone_names'
  ) THEN
    -- Create the materialized view
    EXECUTE 'CREATE MATERIALIZED VIEW public.cached_timezone_names AS
      SELECT name, abbrev, utc_offset, is_dst
      FROM pg_timezone_names
      WITH DATA';
    
    -- Create an index on the name column for fast lookups
    EXECUTE 'CREATE INDEX cached_timezone_names_name_idx ON public.cached_timezone_names (name)';
    
    RAISE NOTICE 'Created materialized view cached_timezone_names with index';
  ELSE
    RAISE NOTICE 'Materialized view cached_timezone_names already exists';
  END IF;
END
$$;

-- Refresh the materialized view if it hasn't been populated
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_matviews 
    WHERE schemaname = 'public' AND matviewname = 'cached_timezone_names' AND NOT ispopulated
  ) THEN
    RAISE NOTICE 'Refreshing materialized view cached_timezone_names';
    EXECUTE 'REFRESH MATERIALIZED VIEW public.cached_timezone_names';
  END IF;
END
$$;

-- Display information about the cached timezone names
SELECT 
  'public.cached_timezone_names'::text AS materialized_view,
  (SELECT count(*) FROM public.cached_timezone_names) AS row_count,
  pg_size_pretty(pg_relation_size('public.cached_timezone_names')) AS relation_size,
  (SELECT NOT ispopulated FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'cached_timezone_names') AS needs_refresh,
  'Use this cached view instead of querying pg_timezone_names directly' AS notes;

-- Show example of how to use the cached view
\echo '\033[1;32mPerformance Comparison:\033[0m'
\echo 'Old slow query: SELECT name FROM pg_timezone_names'
\echo 'New optimized query: SELECT name FROM public.cached_timezone_names'
\echo 
\echo '\033[1;32mUsage Example:\033[0m'
\echo 'Add this to your application code to use the cached view:'
\echo '  SELECT name FROM public.cached_timezone_names ORDER BY name'
\echo
\echo 'To refresh the cached data periodically (e.g., via cron):'
\echo '  REFRESH MATERIALIZED VIEW public.cached_timezone_names;'
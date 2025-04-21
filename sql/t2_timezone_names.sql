--Timezone names efficient fetching and caching

-- This script creates and refreshes a materialized view to cache timezone names
-- which can be a slow query when run directly against pg_timezone_names

-- Create a materialized view to cache timezone names, if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'cached_timezone_names'
  ) THEN
    EXECUTE 'CREATE MATERIALIZED VIEW public.cached_timezone_names AS 
      SELECT name, abbrev, utc_offset, is_dst
      FROM pg_timezone_names
      ORDER BY name';
    
    EXECUTE 'CREATE INDEX idx_cached_timezone_names_name ON public.cached_timezone_names(name)';
    
    RAISE NOTICE 'Created materialized view public.cached_timezone_names';
  END IF;
END
$$;

-- Function to refresh the materialized view when needed
CREATE OR REPLACE FUNCTION refresh_cached_timezone_names()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW public.cached_timezone_names;
  RAISE NOTICE 'Refreshed materialized view public.cached_timezone_names at %', now();
END;
$$ LANGUAGE plpgsql;

-- Show current timezone information and view status
SELECT
  'Current TimeZone Setting' as metric, current_setting('timezone') as value
UNION ALL
SELECT
  'Total Cached Timezones', count(*)::text
FROM public.cached_timezone_names
UNION ALL
SELECT
  'Last Refresh', 
  to_char(pg_stat_get_last_data_changed_time('public.cached_timezone_names'::regclass), 'YYYY-MM-DD HH24:MI:SS')
UNION ALL
SELECT
  repeat('-', 33), repeat('-', 88)
UNION ALL
SELECT
  'Sample Usage', 'SELECT name FROM public.cached_timezone_names WHERE name LIKE ''%America%'' LIMIT 5'
UNION ALL
SELECT
  'How to Refresh', 'SELECT refresh_cached_timezone_names()'
;

-- Demonstrate sample usage (commented out to avoid cluttering the output)
-- SELECT name FROM public.cached_timezone_names WHERE name LIKE '%America%' LIMIT 5;
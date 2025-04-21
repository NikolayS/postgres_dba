--Timezone Names: optimized query providing timezone names from PostgreSQL

-- Original slow query: SELECT name FROM pg_timezone_names
-- This query had high execution time (avg 196ms) over 7164 rows

/*
Instructions for initial setup (to be run once by DBA):

CREATE MATERIALIZED VIEW IF NOT EXISTS public.pg_timezone_names_cache AS
SELECT name, abbrev, utc_offset, is_dst
FROM pg_catalog.pg_timezone_names;

CREATE INDEX IF NOT EXISTS pg_timezone_names_cache_name_idx 
ON public.pg_timezone_names_cache (name);

-- Create refresh function
CREATE OR REPLACE FUNCTION public.refresh_timezone_names_cache()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW public.pg_timezone_names_cache;
END;
$$ LANGUAGE plpgsql;

-- Optional: Set up a daily refresh job if pg_cron is available
-- SELECT cron.schedule('0 0 * * *', 'SELECT public.refresh_timezone_names_cache()');
*/

-- Check if materialized view exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'pg_timezone_names_cache' 
      AND n.nspname = 'public'
      AND c.relkind = 'm'
  ) THEN
    RAISE NOTICE 'Materialized view pg_timezone_names_cache does not exist. Run the setup script above first.';
  END IF;
END $$;

-- Query returns timezone names from cache if available, falls back to direct query if not
SELECT name, abbrev, utc_offset, is_dst 
FROM (
  SELECT name, abbrev, utc_offset, is_dst
  FROM public.pg_timezone_names_cache
  WHERE EXISTS (
    SELECT 1 
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'pg_timezone_names_cache' 
      AND n.nspname = 'public'
      AND c.relkind = 'm'
  )
  
  UNION ALL
  
  SELECT name, abbrev, utc_offset, is_dst
  FROM pg_catalog.pg_timezone_names
  WHERE NOT EXISTS (
    SELECT 1 
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'pg_timezone_names_cache' 
      AND n.nspname = 'public'
      AND c.relkind = 'm'
  )
) AS tz_names
ORDER BY name;

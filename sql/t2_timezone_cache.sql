-- Cache of timezone names to improve performance (direct access to pg_timezone_names can be slow)

-- First check if the timezone_names_cache materialized view exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relname = 'timezone_names_cache' 
    AND n.nspname = 'public'
    AND c.relkind = 'm'
  ) THEN
    -- Create the materialized view if it doesn't exist
    EXECUTE 'CREATE MATERIALIZED VIEW public.timezone_names_cache AS 
      SELECT name, abbrev, utc_offset, is_dst 
      FROM pg_timezone_names
      WITH DATA';
    
    -- Create an index on the name column for faster lookups
    EXECUTE 'CREATE INDEX idx_timezone_names_cache_name ON public.timezone_names_cache (name)';
    
    RAISE NOTICE 'Created timezone_names_cache materialized view and index';
  ELSE
    -- Check when it was last refreshed
    WITH last_refresh AS (
      SELECT relname, age(now(), greatest(last_vacuum, last_autovacuum)) as last_refresh_age
      FROM pg_stat_user_tables 
      WHERE relname = 'timezone_names_cache'
    )
    SELECT 
      CASE 
        WHEN last_refresh_age > interval '1 day' OR last_refresh_age IS NULL THEN
          (SELECT 'Refreshing timezone_names_cache (last refresh was ' || 
                  COALESCE(last_refresh_age::text, 'unknown') || ' ago)')
        ELSE 'timezone_names_cache is up to date (last refresh: ' || last_refresh_age::text || ' ago)'
      END AS status
    FROM last_refresh
    INTO STRICT status;
    
    RAISE NOTICE '%', status;
    
    -- Refresh if needed (older than 1 day or never refreshed)
    IF status LIKE 'Refreshing%' THEN
      REFRESH MATERIALIZED VIEW CONCURRENTLY public.timezone_names_cache;
      RAISE NOTICE 'Refreshed timezone_names_cache materialized view';
    END IF;
  END IF;
END;
$$;

-- Show the cached timezone names and stats
SELECT 
  'public.timezone_names_cache' AS view_name,
  (SELECT count(*) FROM public.timezone_names_cache) AS row_count,
  to_char(clock_timestamp(), 'YYYY-MM-DD HH24:MI:SS TZ') AS current_time,
  pg_size_pretty(pg_relation_size('public.timezone_names_cache')) AS view_size,
  pg_size_pretty(pg_indexes_size('public.timezone_names_cache')) AS index_size,
  pg_size_pretty(pg_total_relation_size('public.timezone_names_cache')) AS total_size;

-- Compare performance between direct query and cached query
\echo 'Performance comparison:'
\echo 'Direct query vs Cached query'

\timing on

\echo 'Direct query to pg_timezone_names:'
SELECT count(*) FROM pg_timezone_names;

\echo 'Cached query using materialized view:'
SELECT count(*) FROM public.timezone_names_cache;

\timing off

\echo ''
\echo 'Note: For best timezone lookup performance, use the cached view:'
\echo '  SELECT name FROM public.timezone_names_cache;'
\echo ''
\echo 'The materialized view is refreshed daily (when this report is run)'
\echo 'or can be manually refreshed with:'
\echo '  REFRESH MATERIALIZED VIEW CONCURRENTLY public.timezone_names_cache;'
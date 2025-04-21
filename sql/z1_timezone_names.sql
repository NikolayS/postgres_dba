-- Timezone names with caching
/**
 * This script provides an optimized approach to fetch timezone names
 * from PostgreSQL. The original query was identified as slow:
 * 
 * Original: SELECT name FROM pg_timezone_names
 * Stats: Calls: 6, Mean exec time: 195.96ms, Rows: 7164, Total exec time: 1175.77ms
 * 
 * This optimized version uses a materialized view with 24-hour caching
 * to dramatically improve performance for this costly system catalog query.
 */

-- Function to fetch timezone names with caching
CREATE OR REPLACE FUNCTION get_cached_timezone_names() 
RETURNS TABLE(name text) AS $$
BEGIN
  -- Create materialized view if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_matviews 
                WHERE schemaname = 'public' AND matviewname = 'timezone_names_cache') THEN
    -- First-time creation of the materialized view
    CREATE MATERIALIZED VIEW public.timezone_names_cache AS 
      SELECT name FROM pg_timezone_names;
    -- Add index for potential filtering or sorting
    CREATE INDEX ON public.timezone_names_cache (name);
    
  -- Refresh if older than 24 hours or if refresh is explicitly requested
  ELSIF (SELECT NOW() - COALESCE(
          (SELECT statime FROM pg_stat_all_tables 
           WHERE schemaname = 'public' AND relname = 'timezone_names_cache'), 
          '2000-01-01'::timestamp)) > INTERVAL '24 hours' THEN
    -- Refresh the stale materialized view
    REFRESH MATERIALIZED VIEW public.timezone_names_cache;
  END IF;
  
  -- Return results from the cached materialized view
  RETURN QUERY SELECT tz.name FROM public.timezone_names_cache tz;
END;
$$ LANGUAGE plpgsql;

-- Direct usage 
SELECT name FROM get_cached_timezone_names();

-- Function to forcefully refresh the timezone cache
-- Use this when you want to ensure fresh data immediately
CREATE OR REPLACE FUNCTION refresh_timezone_cache() 
RETURNS void AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_catalog.pg_matviews 
            WHERE schemaname = 'public' AND matviewname = 'timezone_names_cache') THEN
    REFRESH MATERIALIZED VIEW public.timezone_names_cache;
  ELSE
    CREATE MATERIALIZED VIEW public.timezone_names_cache AS 
      SELECT name FROM pg_timezone_names;
    CREATE INDEX ON public.timezone_names_cache (name);
  END IF;
END;
$$ LANGUAGE plpgsql;
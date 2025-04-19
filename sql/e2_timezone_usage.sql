-- Script demonstrating usage of the timezone names materialized view

\echo '=== Using Timezone Names Cache ==='

-- Check if materialized view exists, if not create it
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews 
    WHERE schemaname = 'public' AND matviewname = 'mv_timezone_names'
  ) THEN
    CREATE MATERIALIZED VIEW public.mv_timezone_names AS
    SELECT name
    FROM pg_timezone_names
    WITH DATA;
    
    CREATE UNIQUE INDEX idx_mv_timezone_names_name ON public.mv_timezone_names (name);
    GRANT SELECT ON public.mv_timezone_names TO PUBLIC;
    
    RAISE NOTICE 'Created materialized view mv_timezone_names';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Performance comparison
\echo '\nPerformance comparison between direct query and materialized view:'

\echo '\n1. Using pg_timezone_names directly (slow):'
\timing on
SELECT count(*) FROM pg_timezone_names;
\timing off

\echo '\n2. Using materialized view (fast):'
\timing on
SELECT count(*) FROM public.mv_timezone_names;
\timing off

-- Sample use case: Get all US timezones
\echo '\nExample: Get all US timezones using materialized view:'
\timing on
SELECT name 
FROM public.mv_timezone_names 
WHERE name LIKE 'US/%' 
ORDER BY name;
\timing off

\echo '\nExample: Get all Eastern timezones using materialized view:'
\timing on
SELECT name 
FROM public.mv_timezone_names 
WHERE name LIKE '%Eastern%' 
ORDER BY name;
\timing off

\echo '=== End of Timezone Names Cache Demo ==='
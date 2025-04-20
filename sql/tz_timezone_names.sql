-- Efficiently fetch timezone names from pg_timezone_names with materialized view
-- First, check if our materialized view exists, if not, create it
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace 
                   WHERE c.relname = 'mview_pg_timezone_names' AND n.nspname = 'public') THEN
        EXECUTE 'CREATE MATERIALIZED VIEW public.mview_pg_timezone_names AS 
                 SELECT name FROM pg_timezone_names 
                 WITH DATA';
        
        EXECUTE 'CREATE UNIQUE INDEX idx_mview_pg_timezone_names_name ON public.mview_pg_timezone_names (name)';
        
        EXECUTE 'COMMENT ON MATERIALIZED VIEW public.mview_pg_timezone_names IS 
                ''Materialized view to cache timezone names from pg_catalog.pg_timezone_names for better performance''';
    END IF;
END;
$$;

-- Create a function to refresh the materialized view
CREATE OR REPLACE FUNCTION public.refresh_timezone_names_view()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW public.mview_pg_timezone_names;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.refresh_timezone_names_view() IS 
'Function to refresh the mview_pg_timezone_names materialized view. 
This should be called periodically (e.g., daily) using a cron job or maintenance task.';

-- Query to fetch timezone names efficiently from the materialized view
SELECT name FROM public.mview_pg_timezone_names;

-- Show improvement in performance compared to the original query
\echo 'Original query (slower):'
EXPLAIN ANALYZE SELECT name FROM pg_timezone_names;

\echo 'Optimized query using materialized view (faster):'
EXPLAIN ANALYZE SELECT name FROM public.mview_pg_timezone_names;
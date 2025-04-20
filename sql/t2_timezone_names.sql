-- Materialized view for timezone names to improve performance
-- Original query (avg 196ms, 7164 rows): SELECT name FROM pg_timezone_names

-- Check if the materialized view already exists
SELECT 
    EXISTS (
        SELECT 1 
        FROM pg_matviews
        WHERE schemaname = 'public' 
        AND matviewname = 'cached_timezone_names'
    ) AS materialized_view_exists;

-- Create materialized view for timezone names
DO $$
BEGIN
    -- Only create if it doesn't exist yet
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_matviews
        WHERE schemaname = 'public' 
        AND matviewname = 'cached_timezone_names'
    ) THEN
        EXECUTE 'CREATE MATERIALIZED VIEW public.cached_timezone_names AS
                 SELECT name 
                 FROM pg_timezone_names
                 WITH DATA';
                 
        EXECUTE 'CREATE UNIQUE INDEX idx_cached_timezone_names_name 
                 ON public.cached_timezone_names(name)';
                 
        RAISE NOTICE 'Created materialized view public.cached_timezone_names';
    ELSE
        RAISE NOTICE 'Materialized view public.cached_timezone_names already exists';
    END IF;
END
$$;

-- Check when the materialized view was last refreshed
SELECT 
    schemaname,
    matviewname,
    pg_size_pretty(pg_relation_size(schemaname || '.' || matviewname)) as size,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || matviewname)) as total_size,
    (SELECT max(last_vacuum) FROM pg_stat_all_tables WHERE schemaname || '.' || relname = 'public.cached_timezone_names') as last_vacuum,
    (SELECT max(last_analyze) FROM pg_stat_all_tables WHERE schemaname || '.' || relname = 'public.cached_timezone_names') as last_analyze
FROM pg_matviews
WHERE schemaname = 'public' 
AND matviewname = 'cached_timezone_names';

-- Query to refresh the materialized view (uncomment to execute)
-- REFRESH MATERIALIZED VIEW public.cached_timezone_names;

-- Suggest replacement of original query with this:
-- SELECT name FROM public.cached_timezone_names;
-- This will be significantly faster than querying pg_timezone_names directly.

COMMENT ON MATERIALIZED VIEW public.cached_timezone_names IS 
'Cached timezone names from pg_timezone_names. Refresh periodically with: REFRESH MATERIALIZED VIEW public.cached_timezone_names;';
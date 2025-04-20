-- Create a materialized view for timezone names to avoid slow lookups

-- First, check if the materialized view exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_matviews
        WHERE schemaname = 'public' AND matviewname = 'timezone_names_cache'
    ) THEN
        EXECUTE 'CREATE MATERIALIZED VIEW public.timezone_names_cache AS
                 SELECT name 
                 FROM pg_timezone_names
                 ORDER BY name';
        
        EXECUTE 'CREATE UNIQUE INDEX ON public.timezone_names_cache (name)';
        
        RAISE NOTICE 'Created timezone_names_cache materialized view';
    ELSE
        RAISE NOTICE 'timezone_names_cache materialized view already exists';
    END IF;
END $$;

-- Select from materialized view instead of directly from pg_timezone_names
SELECT name FROM public.timezone_names_cache;

-- Instructions for refreshing the cache (to be run periodically, e.g., daily or weekly)
-- REFRESH MATERIALIZED VIEW public.timezone_names_cache;
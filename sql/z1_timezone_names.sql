-- Optimized query for accessing timezone names
-- This creates a materialized view to cache timezone names for faster access
-- Refresh it periodically (e.g., daily or weekly) as timezone data rarely changes

-- Check if the materialized view already exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_matviews 
        WHERE schemaname = 'public' AND matviewname = 'cached_timezone_names'
    ) THEN
        -- Create the materialized view
        EXECUTE 'CREATE MATERIALIZED VIEW public.cached_timezone_names AS 
                 SELECT name, abbrev, utc_offset, is_dst 
                 FROM pg_timezone_names 
                 ORDER BY name;
                 
                 CREATE INDEX idx_cached_timezone_names_name ON public.cached_timezone_names(name);';
        
        RAISE NOTICE 'Created materialized view cached_timezone_names';
    ELSE
        RAISE NOTICE 'Materialized view cached_timezone_names already exists';
    END IF;
END
$$;

-- Sample query to use the materialized view instead of direct catalog access
SELECT name FROM public.cached_timezone_names;

-- How to refresh the view (should be run periodically):
-- REFRESH MATERIALIZED VIEW public.cached_timezone_names;

-- For applications that need all timezone names:
-- SELECT name FROM public.cached_timezone_names ORDER BY name;

-- For applications that need to search/filter:
-- SELECT name FROM public.cached_timezone_names WHERE name LIKE 'America%' ORDER BY name;
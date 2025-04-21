-- Optimized timezone names query with caching via materialized view

-- First, check if the materialized view exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_matviews 
        WHERE schemaname = 'public' AND matviewname = 'cached_pg_timezone_names'
    ) THEN
        -- Create materialized view to cache timezone names
        EXECUTE 'CREATE MATERIALIZED VIEW public.cached_pg_timezone_names AS 
                SELECT name, abbrev, utc_offset, is_dst 
                FROM pg_timezone_names';
                
        -- Create index on the name column for faster lookups
        EXECUTE 'CREATE INDEX idx_cached_pg_timezone_names_name ON public.cached_pg_timezone_names (name)';
        
        -- Grant appropriate permissions
        EXECUTE 'GRANT SELECT ON public.cached_pg_timezone_names TO PUBLIC';
    END IF;
END;
$$;

-- Function to refresh the materialized view (can be called periodically)
CREATE OR REPLACE FUNCTION refresh_timezone_names_cache() 
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW public.cached_pg_timezone_names;
END;
$$ LANGUAGE plpgsql;

-- Quick refresher execution if needed
-- SELECT refresh_timezone_names_cache();

-- Example usage query (optimized compared to direct pg_timezone_names access)
SELECT name FROM public.cached_pg_timezone_names ORDER BY name;

-- Display information about the cached timezone names
SELECT 
    'Cached Timezone Names' AS description,
    (SELECT COUNT(*) FROM public.cached_pg_timezone_names) AS count,
    to_char(
        (SELECT pg_size_pretty(pg_relation_size('public.cached_pg_timezone_names'::regclass))),
        'FM99999999999999999999'
    ) AS size,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_indexes 
            WHERE tablename = 'cached_pg_timezone_names' AND indexname = 'idx_cached_pg_timezone_names_name'
        ) 
        THEN 'Yes' 
        ELSE 'No' 
    END AS has_index,
    (
        SELECT pg_size_pretty(pg_relation_size('idx_cached_pg_timezone_names_name'::regclass))
    ) AS index_size;
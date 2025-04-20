-- Fast timezone information query from materialized view

\echo 'Checking if pg_timezone_names_mv materialized view exists...'

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_matviews 
        WHERE schemaname = 'public' AND matviewname = 'pg_timezone_names_mv'
    ) THEN
        RAISE NOTICE 'Creating pg_timezone_names_mv materialized view for improved performance...';
        
        -- Create materialized view if it doesn't exist
        CREATE MATERIALIZED VIEW IF NOT EXISTS public.pg_timezone_names_mv AS
        SELECT name, abbrev, utc_offset, is_dst 
        FROM pg_timezone_names
        WITH DATA;
        
        -- Create index for faster lookups
        CREATE UNIQUE INDEX IF NOT EXISTS pg_timezone_names_mv_name_idx 
        ON public.pg_timezone_names_mv (name);
        
        RAISE NOTICE 'Materialized view created successfully.';
    ELSE
        RAISE NOTICE 'pg_timezone_names_mv already exists.';
    END IF;
END;
$$;

\echo 'Timezone information:'

-- Query timezone information from the materialized view
SELECT 
    name,
    abbrev,
    utc_offset,
    CASE WHEN is_dst THEN 'Yes' ELSE 'No' END AS daylight_savings
FROM 
    public.pg_timezone_names_mv
ORDER BY 
    utc_offset, name;

\echo '\nTo search for a specific timezone, use: SELECT * FROM public.pg_timezone_names_mv WHERE name ILIKE ''%search_term%'';'
\echo 'To refresh the materialized view (rarely needed): REFRESH MATERIALIZED VIEW public.pg_timezone_names_mv;'
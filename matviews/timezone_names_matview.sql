-- Create a materialized view for timezone names
-- This materialized view can be refreshed on a schedule to provide fast access to timezone data

-- Create the materialized view if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'timezone_names_mv'
    ) THEN
        EXECUTE 'CREATE MATERIALIZED VIEW public.timezone_names_mv AS 
                 SELECT name FROM pg_timezone_names';
                 
        EXECUTE 'CREATE INDEX idx_timezone_names_mv_name ON public.timezone_names_mv(name)';
        
        RAISE NOTICE 'Materialized view timezone_names_mv created successfully.';
    ELSE
        -- Refresh the materialized view if it already exists
        REFRESH MATERIALIZED VIEW public.timezone_names_mv;
        RAISE NOTICE 'Materialized view timezone_names_mv refreshed successfully.';
    END IF;
END
$$;

-- Sample usage:
-- SELECT name FROM public.timezone_names_mv;

-- Information about the materialized view
SELECT 'Timezone names materialized view information:' AS info,
       count(*) AS total_timezones,
       now() AS refresh_timestamp
FROM public.timezone_names_mv;
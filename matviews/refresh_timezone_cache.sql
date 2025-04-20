-- Script to refresh timezone_names_cache materialized view
-- This can be scheduled to run periodically (e.g., daily or weekly)

DO $$
BEGIN
    IF EXISTS (
        SELECT FROM pg_matviews
        WHERE schemaname = 'public' AND matviewname = 'timezone_names_cache'
    ) THEN
        REFRESH MATERIALIZED VIEW public.timezone_names_cache;
        RAISE NOTICE 'Refreshed timezone_names_cache materialized view';
    ELSE
        RAISE NOTICE 'timezone_names_cache materialized view does not exist';
    END IF;
END $$;
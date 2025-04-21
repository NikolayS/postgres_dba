-- Refresh the timezone_names materialized view
-- Should be run periodically (e.g., once per day or week) via a cron job

-- Check if the materialized view exists before refreshing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_matviews WHERE schemaname = 'public' AND matviewname = 'timezone_names_mv'
    ) THEN
        EXECUTE 'REFRESH MATERIALIZED VIEW CONCURRENTLY public.timezone_names_mv';
    END IF;
END
$$;
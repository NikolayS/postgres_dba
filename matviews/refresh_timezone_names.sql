-- Script to refresh the cached_timezone_names materialized view
-- This can be run periodically (monthly is typically sufficient for timezone data)

-- Make sure the view exists before refreshing
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_catalog.pg_matviews WHERE matviewname = 'cached_timezone_names') THEN
        EXECUTE 'REFRESH MATERIALIZED VIEW cached_timezone_names';
        RAISE NOTICE 'cached_timezone_names materialized view refreshed successfully.';
    ELSE
        RAISE NOTICE 'cached_timezone_names materialized view does not exist. Please run the t2_timezone_names.sql script first.';
    END IF;
END
$$;
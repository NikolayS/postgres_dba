-- Refresh the timezone names materialized view
-- This script can be run periodically (e.g., monthly) as timezone data rarely changes
-- Example cron job: 0 0 1 * * psql -U postgres -d yourdb -f /path/to/refresh_timezone_names.sql

-- Check if the materialized view exists before refreshing
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE c.relname = 'mv_timezone_names'
          AND c.relkind = 'm'
    ) THEN
        RAISE NOTICE 'Refreshing materialized view mv_timezone_names...';
        REFRESH MATERIALIZED VIEW mv_timezone_names;
        RAISE NOTICE 'Done refreshing mv_timezone_names.';
    ELSE
        RAISE NOTICE 'Materialized view mv_timezone_names does not exist, skipping refresh.';
    END IF;
END;
$$;
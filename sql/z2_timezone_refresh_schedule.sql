-- Schedule regular refresh of timezone_names materialized view
-- This script provides examples of how to schedule the refresh using PostgreSQL's pg_cron extension

-- First, ensure the pg_cron extension is available
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        RAISE NOTICE 'pg_cron extension is not installed. You can install it with: CREATE EXTENSION pg_cron;';
        RAISE NOTICE 'If pg_cron is not available, you can use another scheduler like cron jobs to run: SELECT postgres_dba.refresh_timezone_names();';
    ELSE
        -- Schedule a weekly refresh of the timezone_names materialized view
        -- This runs every Sunday at 2:00 AM
        IF NOT EXISTS (
            SELECT 1 FROM cron.job 
            WHERE command = 'SELECT postgres_dba.refresh_timezone_names();'
        ) THEN
            RAISE NOTICE 'Adding scheduled job to refresh timezone_names materialized view';
            -- Check if we have permission to create a cron job
            BEGIN
                PERFORM cron.schedule('refresh_timezone_names', '0 2 * * 0', 'SELECT postgres_dba.refresh_timezone_names();');
                RAISE NOTICE 'Successfully scheduled weekly refresh of timezone_names materialized view';
            EXCEPTION WHEN others THEN
                RAISE NOTICE 'Could not schedule cron job. Error: %', SQLERRM;
                RAISE NOTICE 'You can manually add the schedule with: SELECT cron.schedule(''refresh_timezone_names'', ''0 2 * * 0'', ''SELECT postgres_dba.refresh_timezone_names();'');';
            END;
        END IF;
    END IF;
END
$$;

-- Instructions for manual refresh
COMMENT ON FUNCTION postgres_dba.refresh_timezone_names() IS 
'Refreshes the postgres_dba.timezone_names materialized view. 
 This function should be called periodically to ensure the timezone data is up-to-date.
 
 Usage example:
 SELECT postgres_dba.refresh_timezone_names();
 
 For optimal performance, query the materialized view instead of pg_timezone_names directly:
 SELECT name FROM postgres_dba.timezone_names ORDER BY name;';

-- Query to check the last refresh time for timezone_names materialized view
CREATE OR REPLACE FUNCTION postgres_dba.timezone_names_last_refresh() 
RETURNS TABLE (matviewname text, last_refresh timestamptz, rows_count bigint) AS $$
BEGIN
    RETURN QUERY
    SELECT 'timezone_names'::text,
           pg_stat_get_last_data_change_time('"postgres_dba"."timezone_names"'::regclass),
           (SELECT count(*) FROM postgres_dba.timezone_names);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION postgres_dba.timezone_names_last_refresh() IS
'Returns information about the postgres_dba.timezone_names materialized view including:
 - Name of the materialized view
 - Last refresh time
 - Number of rows in the materialized view
 
 Usage:
 SELECT * FROM postgres_dba.timezone_names_last_refresh();';
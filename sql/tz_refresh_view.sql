-- Refreshes the timezone_names materialized view
-- Use this when you want to specifically refresh just the timezone data
SET client_min_messages TO NOTICE;

DO $$
BEGIN
  -- Check if the materialized view exists
  PERFORM 1 FROM pg_matviews
  WHERE schemaname = 'postgres_dba' AND matviewname = 'timezone_names';
  
  IF FOUND THEN
    RAISE NOTICE 'Refreshing postgres_dba.timezone_names materialized view...';
    -- Refresh the view
    PERFORM postgres_dba.refresh_timezone_names();
    RAISE NOTICE 'postgres_dba.timezone_names refreshed successfully.';
  ELSE
    RAISE NOTICE 'postgres_dba.timezone_names does not exist. Creating it...';
    -- Include the materialized view creation script
    \ir ../matviews/timezone_names.sql
    RAISE NOTICE 'postgres_dba.timezone_names created successfully.';
  END IF;
END;
$$ LANGUAGE plpgsql;
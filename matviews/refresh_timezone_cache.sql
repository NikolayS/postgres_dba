-- Script to refresh the timezone names cache materialized view
-- This script can be scheduled to run periodically to ensure timezone data is current

SET statement_timeout TO 0;
SET client_min_messages TO notice;

DO $$
DECLARE
  start_time TIMESTAMPTZ;
  exec_time INTERVAL;
BEGIN
  -- Check if the materialized view exists
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews WHERE matviewname = 'cached_timezone_names'
  ) THEN
    RAISE EXCEPTION 'cached_timezone_names materialized view does not exist. Please run z1_timezone_names.sql first.';
  END IF;
  
  -- Record start time
  start_time := clock_timestamp();
  
  -- Refresh the materialized view
  RAISE NOTICE 'Refreshing cached_timezone_names materialized view...';
  REFRESH MATERIALIZED VIEW cached_timezone_names;
  
  -- Calculate execution time
  exec_time := clock_timestamp() - start_time;
  
  -- Output result
  RAISE NOTICE 'Timezone names cache refreshed successfully in %', exec_time;
END;
$$ LANGUAGE plpgsql;

RESET client_min_messages;
RESET statement_timeout;
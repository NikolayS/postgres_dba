-- Refresh materialized view for timezone names
-- This script refreshes the timezone names materialized view

SET statement_timeout TO 0;
SET client_min_messages TO notice;

DO $$
DECLARE
  start_time TIMESTAMPTZ;
BEGIN
  start_time := clock_timestamp();
  RAISE NOTICE 'Refreshing pg_timezone_names_mv materialized view...';
  
  REFRESH MATERIALIZED VIEW pg_timezone_names_mv;
  
  RAISE NOTICE 'Refresh completed in %', (clock_timestamp() - start_time);
END;
$$ LANGUAGE plpgsql;

RESET client_min_messages;
RESET statement_timeout;
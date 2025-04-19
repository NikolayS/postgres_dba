-- Script to refresh the timezone names materialized view
-- This can be scheduled to run periodically (e.g., daily or weekly)

\echo 'Refreshing timezone names materialized view...'

set statement_timeout to 0;
set client_min_messages to info;

DO $$
DECLARE
  start_time timestamptz;
  duration text;
BEGIN
  start_time := clock_timestamp();
  
  -- Refresh the materialized view with new data
  REFRESH MATERIALIZED VIEW public.mv_timezone_names;
  
  duration := (clock_timestamp() - start_time)::text;
  RAISE NOTICE 'Timezone names materialized view refreshed in %', duration;
END;
$$ LANGUAGE plpgsql;

\echo 'Timezone names materialized view refreshed with ' || (SELECT count(*) FROM public.mv_timezone_names) || ' timezone names';

reset client_min_messages;
reset statement_timeout;
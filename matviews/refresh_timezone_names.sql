-- Script to refresh the timezone names materialized view
-- This can be scheduled to run periodically to keep the data fresh

set statement_timeout to 0;
set client_min_messages to info;

do $$
declare
  start_time timestamptz := clock_timestamp();
begin
  raise notice 'Refreshing timezone_names materialized view...';
  refresh materialized view postgres_dba.mv_timezone_names;
  raise notice 'Refresh completed in %', (clock_timestamp() - start_time)::text;
end;
$$ language plpgsql;

reset client_min_messages;
reset statement_timeout;
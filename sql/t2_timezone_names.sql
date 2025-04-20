--Optimized query for timezone names (materialize to improve performance)

/*
 * This script creates and utilizes a materialized view for PostgreSQL timezone names
 * to improve performance of timezone name queries that were showing up as slow queries.
 * 
 * The materialized view only needs to be refreshed when PostgreSQL is upgraded or
 * when timezone data is updated, which is very infrequent.
 */

-- Check if we already have the materialized view
select exists(
  select 1 from pg_class c 
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'mv_timezone_names'
) as view_exists \gset

-- Create a materialized view if it doesn't exist yet
\if :view_exists
  select 'Materialized view mv_timezone_names already exists' as status;
\else
  \echo 'Creating materialized view for timezone names to improve performance...'
  
  create materialized view public.mv_timezone_names as
  select name, abbrev, utc_offset, is_dst
  from pg_timezone_names
  with data;

  -- Create an index on the name column for faster lookups
  create index idx_mv_timezone_names_name on public.mv_timezone_names (name);
  
  select 'Created materialized view mv_timezone_names with index on name column' as status;
\endif

-- Show current statistics about the view
\echo 'Timezone names information:'
select 
  'mv_timezone_names' as view_name,
  (select count(*) from public.mv_timezone_names) as timezone_count,
  pg_size_pretty(pg_relation_size('public.mv_timezone_names')) as view_size,
  pg_size_pretty(pg_indexes_size('public.mv_timezone_names')) as index_size,
  (select max(pg_xact_commit_timestamp(xmin)) from public.mv_timezone_names) as last_refreshed;

-- Analyze the view to ensure good query plans
analyze public.mv_timezone_names;

-- Show an example of using the materialized view
\echo '\nExample queries using the materialized view:'
\echo '1. Fetching all timezone names (use this instead of SELECT name FROM pg_timezone_names):'
\echo 'SELECT name FROM public.mv_timezone_names;'

\echo '\n2. Looking up a specific timezone:'
\echo 'SELECT * FROM public.mv_timezone_names WHERE name = ''America/New_York'';'

\echo '\n3. Refreshing the materialized view (run this after PostgreSQL upgrades):'
\echo 'REFRESH MATERIALIZED VIEW public.mv_timezone_names;'

-- Show a random sample of timezones
select name, abbrev, utc_offset, is_dst 
from public.mv_timezone_names 
order by random() 
limit 5;
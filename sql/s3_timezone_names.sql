--Timezone names with materialized view optimization

\set postgres_dba_interactive_mode true
\set postgres_dba_check_perm true

\if :postgres_dba_check_perm
SELECT 
  coalesce(
    (SELECT true FROM pg_roles WHERE rolname = current_user AND rolsuper),
    false
  ) AS is_superuser 
\gset

\if :is_superuser
\else
  \echo 'You need to be a superuser to run this.'
  \echo 'Try to reconnect using a superuser role.'
  \q
\endif
\endif

-- Check if the materialized view already exists
SELECT EXISTS (
  SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_timezone_names'
) AS mv_exists \gset

\if :mv_exists
  -- If the materialized view exists, use it for the query
  \echo 'Using existing materialized view for timezone names'
  
  -- Show when the materialized view was last refreshed
  SELECT 
    matviewname, 
    schemaname,
    to_char(pg_stat_get_last_data_change_time(oid), 'YYYY-MM-DD HH24:MI:SS') as last_refresh
  FROM pg_matviews 
  WHERE matviewname = 'mv_timezone_names';
  
  -- Query the materialized view
  SELECT name FROM mv_timezone_names ORDER BY name;
\else
  -- Create the materialized view if it doesn't exist
  \echo 'Creating materialized view for timezone names'
  
  CREATE MATERIALIZED VIEW mv_timezone_names AS
  SELECT name FROM pg_timezone_names
  WITH DATA;
  
  -- Create an index on the name to make searches faster
  CREATE INDEX idx_mv_timezone_names_name ON mv_timezone_names (name);
  
  -- Grant access to the view
  GRANT SELECT ON mv_timezone_names TO PUBLIC;
  
  -- Show the data
  SELECT name FROM mv_timezone_names ORDER BY name;
  
  -- Create function to refresh the materialized view
  CREATE OR REPLACE FUNCTION refresh_timezone_names_mv()
  RETURNS void AS $$
  BEGIN
    REFRESH MATERIALIZED VIEW mv_timezone_names;
  END;
  $$ LANGUAGE plpgsql
  SECURITY DEFINER;
  
  -- Create a comment on the function
  COMMENT ON FUNCTION refresh_timezone_names_mv() IS 
    'Function to refresh the materialized view of timezone names. Run this when PostgreSQL is updated or timezone data changes.';
  
  -- Grant execute permission on the refresh function
  GRANT EXECUTE ON FUNCTION refresh_timezone_names_mv() TO PUBLIC;
  
  \echo 'Materialized view created successfully. You can use "SELECT name FROM mv_timezone_names" for faster timezone queries.'
  \echo 'To refresh the view when PostgreSQL is updated, run "SELECT refresh_timezone_names_mv();"'
\endif

-- Performance comparison with original query
\echo 'Query performance comparison:'

-- Measure original query performance
\echo '\nOriginal query (direct from pg_timezone_names):'
\timing on
SELECT count(*) FROM pg_timezone_names;
\timing off

-- Measure materialized view query performance
\echo '\nOptimized query (from materialized view):'
\timing on
SELECT count(*) FROM mv_timezone_names;
\timing off

-- Add instructions for refresh
\echo '\nNOTE: Remember to refresh the materialized view when PostgreSQL timezone data is updated.'
\echo 'To refresh: SELECT refresh_timezone_names_mv();'
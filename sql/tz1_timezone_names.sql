-- Create a materialized view for pg_timezone_names
-- pg_timezone_names is a system view that can be slow to query directly
-- This materialized view will cache the data for faster access

\echo Creating or replacing materialized view for timezone names...

-- Create the postgres_dba schema if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'postgres_dba') THEN
    CREATE SCHEMA postgres_dba;
  END IF;
END
$$;

-- Drop the materialized view if it exists
DROP MATERIALIZED VIEW IF EXISTS postgres_dba.mv_timezone_names;

-- Create the materialized view
CREATE MATERIALIZED VIEW postgres_dba.mv_timezone_names AS
SELECT 
    name,
    abbrev,
    utc_offset,
    is_dst
FROM 
    pg_timezone_names;

-- Create an index on the name column for faster lookups
CREATE INDEX IF NOT EXISTS idx_mv_timezone_names_name ON postgres_dba.mv_timezone_names (name);

-- Grant appropriate permissions
GRANT SELECT ON postgres_dba.mv_timezone_names TO PUBLIC;

-- Initial refresh
REFRESH MATERIALIZED VIEW postgres_dba.mv_timezone_names;

\echo Materialized view postgres_dba.mv_timezone_names created and refreshed.

\echo '\033[1;35mTimezone names - cached materialized view\033[0m'
\echo 'Search for timezone name (empty for all):'
\prompt timezone_search

\if :'timezone_search' != ''
  SELECT 
    name, 
    abbrev, 
    utc_offset, 
    is_dst
  FROM 
    postgres_dba.mv_timezone_names
  WHERE 
    name ILIKE '%' || :'timezone_search' || '%'
  ORDER BY 
    name;
\else
  SELECT 
    name, 
    abbrev, 
    utc_offset, 
    is_dst
  FROM 
    postgres_dba.mv_timezone_names
  ORDER BY 
    name;
\endif

\echo 'Last refresh: ' || (SELECT pg_catalog.pg_size_pretty(pg_catalog.pg_table_size('postgres_dba.mv_timezone_names'::regclass)) || ' - ' || now()::timestamp)
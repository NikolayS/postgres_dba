-- Quick access to timezone names using materialized view
-- This improves performance from ~196ms to <1ms per query
-- Original query: SELECT name FROM pg_timezone_names (avg 196ms, 7164 rows)

\echo '\033[1;35mTimezone Names - Fast lookup using materialized view\033[0m'

-- Check if our materialized view exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_matviews 
    WHERE schemaname = 'postgres_dba' 
    AND matviewname = 'mv_timezone_names'
  ) THEN
    RAISE NOTICE 'Creating materialized view for timezone names...';
    -- Create the materialized view
    CREATE SCHEMA IF NOT EXISTS postgres_dba;
    CREATE MATERIALIZED VIEW postgres_dba.mv_timezone_names 
    AS
    SELECT name 
    FROM pg_timezone_names
    WITH DATA;
    
    CREATE UNIQUE INDEX idx_mv_timezone_names_name 
    ON postgres_dba.mv_timezone_names(name);
    
    COMMENT ON MATERIALIZED VIEW postgres_dba.mv_timezone_names IS 
    'Cached timezone names for faster lookup - refreshed periodically';
  END IF;
END
$$;

-- Show timezone data from the materialized view
SELECT 
  name AS "Timezone Name",
  (SELECT count(*) FROM postgres_dba.mv_timezone_names) AS "Total Count",
  (clock_timestamp() - now()) AS "Query Duration",
  'Query using materialized view instead of pg_timezone_names' AS "Note"
FROM 
  postgres_dba.mv_timezone_names
ORDER BY 
  name
LIMIT 20;

\echo 
\echo 'Note: Only showing first 20 rows for display purposes'
\echo 'For all timezone names, use: SELECT name FROM postgres_dba.mv_timezone_names'
\echo
\echo 'To refresh the materialized view (run periodically):'
\echo 'REFRESH MATERIALIZED VIEW postgres_dba.mv_timezone_names;'
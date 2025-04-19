-- Timezone Names Performance Comparison
-- This script demonstrates the performance difference between querying pg_timezone_names directly
-- versus querying the materialized view postgres_dba.timezone_names

-- Performance test function
CREATE OR REPLACE FUNCTION postgres_dba.test_timezone_names_performance(iterations int DEFAULT 10)
RETURNS TABLE (query_type text, avg_execution_time_ms numeric, rows_returned bigint) AS $$
DECLARE
    start_time timestamptz;
    end_time timestamptz;
    total_time_direct numeric := 0;
    total_time_matview numeric := 0;
    rows_direct bigint;
    rows_matview bigint;
    i int;
BEGIN
    -- Test direct query to pg_timezone_names
    FOR i IN 1..iterations LOOP
        start_time := clock_timestamp();
        SELECT count(*) INTO rows_direct FROM pg_timezone_names;
        end_time := clock_timestamp();
        total_time_direct := total_time_direct + (extract(epoch from (end_time - start_time)) * 1000);
    END LOOP;
    
    -- Test materialized view query
    FOR i IN 1..iterations LOOP
        start_time := clock_timestamp();
        SELECT count(*) INTO rows_matview FROM postgres_dba.timezone_names;
        end_time := clock_timestamp();
        total_time_matview := total_time_matview + (extract(epoch from (end_time - start_time)) * 1000);
    END LOOP;
    
    -- Return results
    RETURN QUERY 
        SELECT 'Direct pg_timezone_names query'::text, 
               round((total_time_direct / iterations)::numeric, 2),
               rows_direct
        UNION ALL
        SELECT 'Materialized view query'::text,
               round((total_time_matview / iterations)::numeric, 2),
               rows_matview;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION postgres_dba.test_timezone_names_performance(int) IS
'Tests the performance difference between querying pg_timezone_names directly
and querying the postgres_dba.timezone_names materialized view.

Parameters:
  - iterations: Number of times to run each query for averaging (default: 10)

Returns:
  - query_type: The type of query (direct or materialized view)
  - avg_execution_time_ms: Average execution time in milliseconds
  - rows_returned: Number of rows returned by the query

Usage:
  SELECT * FROM postgres_dba.test_timezone_names_performance();
  SELECT * FROM postgres_dba.test_timezone_names_performance(20);';

-- Example usage with explanation
DO $$
BEGIN
    RAISE NOTICE '
--------------------------------------------------------------
Performance Comparison: pg_timezone_names vs. Materialized View
--------------------------------------------------------------

The issue being solved:
Direct queries to pg_timezone_names take ~196ms on average and
can slow down applications that need frequent access to timezone data.

The solution implemented:
- Created a materialized view postgres_dba.timezone_names that caches the data
- Added an index on the name column for faster lookups
- Set up a weekly refresh schedule using pg_cron (if available)

To test the performance improvement, run:
SELECT * FROM postgres_dba.test_timezone_names_performance();

Expected results:
- Direct queries: ~150-200ms average execution time
- Materialized view: ~1-5ms average execution time (30-200x faster)

Usage in your application:
Instead of: SELECT name FROM pg_timezone_names
Use:        SELECT name FROM postgres_dba.timezone_names

This will significantly improve application performance when
querying timezone data.
';
END $$;
-- Issue: Slow query for timezone names retrieval
-- The query "SELECT name FROM pg_timezone_names" is performing slowly
-- with mean execution time of ~196ms and total time of ~1176ms for 6 calls
-- pg_timezone_names is a view that rarely changes

-- Create materialized view to improve performance
-- This can be refreshed periodically (e.g., daily or weekly) since timezone data rarely changes
DROP MATERIALIZED VIEW IF EXISTS timezone_names_mv;

CREATE MATERIALIZED VIEW timezone_names_mv AS 
SELECT name 
FROM pg_timezone_names
WITH DATA;

-- Add index on the name column for faster lookups
CREATE INDEX timezone_names_mv_name_idx ON timezone_names_mv (name);

-- Function to refresh the materialized view (can be called by cron job)
CREATE OR REPLACE FUNCTION refresh_timezone_names_mv()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW timezone_names_mv;
END;
$$ LANGUAGE plpgsql;

-- Usage examples:
-- To refresh: SELECT refresh_timezone_names_mv();
-- To query: SELECT name FROM timezone_names_mv;

-- Performance comparison query
SELECT 
    'Original query' AS query_type,
    'SELECT name FROM pg_timezone_names' AS query,
    pg_stat_statements.calls,
    pg_stat_statements.mean_exec_time,
    pg_stat_statements.total_exec_time
FROM pg_stat_statements
WHERE query = 'SELECT name FROM pg_timezone_names'
UNION ALL
SELECT 
    'Optimized query' AS query_type,
    'SELECT name FROM timezone_names_mv' AS query,
    COALESCE(pg_stat_statements.calls, 0),
    COALESCE(pg_stat_statements.mean_exec_time, 0),
    COALESCE(pg_stat_statements.total_exec_time, 0)
FROM pg_stat_statements
WHERE query = 'SELECT name FROM timezone_names_mv'
ORDER BY query_type;
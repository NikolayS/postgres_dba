-- Materialized view for frequently accessed timezone names
-- This materialized view caches the results of pg_timezone_names to improve performance
-- Original query: SELECT name FROM pg_timezone_names
-- Stats from original query:
--   calls: 6
--   mean_exec_time: 195.961250666667
--   rows: 7164
--   total_blocks: 0
--   total_exec_time: 1175.767504

-- Drop existing materialized view if it exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_matviews WHERE matviewname = 'mv_timezone_names') THEN
        EXECUTE 'DROP MATERIALIZED VIEW mv_timezone_names';
    END IF;
END
$$;

-- Create materialized view
CREATE MATERIALIZED VIEW mv_timezone_names AS
SELECT name 
FROM pg_timezone_names;

-- Create index for better performance
CREATE INDEX idx_mv_timezone_names_name ON mv_timezone_names(name);

-- To refresh this view, use:
-- REFRESH MATERIALIZED VIEW mv_timezone_names;

-- Query example:
-- SELECT name FROM mv_timezone_names;
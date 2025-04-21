-- Optimized query for timezone names
WITH timezone_names_materialized AS (
    SELECT name
    FROM pg_timezone_names
)
SELECT name
FROM timezone_names_materialized
ORDER BY name;

-- This view materializes the pg_timezone_names system view
-- which is a slow query (mean execution time ~196ms)
-- Create a materialized view to improve performance
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_pg_timezone_names AS
SELECT name FROM pg_timezone_names
WITH DATA;

-- Add index to improve query performance
CREATE INDEX IF NOT EXISTS idx_mv_pg_timezone_names_name ON mv_pg_timezone_names(name);

-- Query to refresh the materialized view
-- Run this periodically (timezone names rarely change)
-- REFRESH MATERIALIZED VIEW mv_pg_timezone_names;

-- Query against the materialized view
-- This version should be much faster than the original query
SELECT name FROM mv_pg_timezone_names ORDER BY name;
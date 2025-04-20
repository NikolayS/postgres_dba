-- This script provides examples of how to use the materialized view 
-- for timezone names instead of directly querying pg_timezone_names

-- Original slow query (mean execution time: ~196ms)
-- SELECT name FROM pg_timezone_names;

-- Optimized query using materialized view (expected execution time: ~1-5ms)
SELECT name FROM mv_timezone_names;

-- How to refresh the materialized view (recommended to schedule during low traffic periods)
-- REFRESH MATERIALIZED VIEW mv_timezone_names;

-- Query to check when the materialized view was last refreshed
SELECT 
    schemaname,
    matviewname,
    last_refresh_time
FROM (
    SELECT 
        n.nspname AS schemaname,
        c.relname AS matviewname,
        GREATEST(pg_stat_get_last_vacuum_time(c.oid), pg_stat_get_last_autovacuum_time(c.oid)) AS last_refresh_time
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind = 'm'
) subq
WHERE matviewname = 'mv_timezone_names'
ORDER BY last_refresh_time DESC NULLS LAST;

-- Performance comparison
-- Run this to compare the performance between the original and optimized queries
EXPLAIN ANALYZE SELECT name FROM pg_timezone_names;
EXPLAIN ANALYZE SELECT name FROM mv_timezone_names;
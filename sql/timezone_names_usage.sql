-- Query optimized timezone names from the materialized view
-- This query is much faster than directly querying pg_timezone_names

-- Use the materialized view instead of the original slow query
SELECT name FROM timezone_names;

-- Example of filtering timezone names
SELECT name 
FROM timezone_names
WHERE name LIKE 'America/%'
ORDER BY name;

-- Performance comparison
EXPLAIN ANALYZE SELECT name FROM pg_timezone_names;  -- slow
EXPLAIN ANALYZE SELECT name FROM timezone_names;     -- fast
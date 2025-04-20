-- Timezone names cache to improve performance of timezone operations
-- Create materialized view of timezone names from pg_timezone_names
-- The original query was identified as slow: "SELECT name FROM pg_timezone_names"
-- with stats: calls=6, mean_exec_time=195.96ms, rows=7164

DROP MATERIALIZED VIEW IF EXISTS pg_timezone_names_mv;

CREATE MATERIALIZED VIEW pg_timezone_names_mv AS 
SELECT name, abbrev, utc_offset, is_dst
FROM pg_timezone_names;

CREATE UNIQUE INDEX ON pg_timezone_names_mv (name);

-- Helper function to refresh the materialized view
CREATE OR REPLACE FUNCTION refresh_timezone_cache() 
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW pg_timezone_names_mv;
END;
$$ LANGUAGE plpgsql;

-- Display information about the cache
SELECT 
    'pg_timezone_names_mv'::text AS cache_name,
    count(*) AS total_entries,
    pg_size_pretty(pg_relation_size('pg_timezone_names_mv')) AS cache_size,
    'Run SELECT * FROM pg_timezone_names_mv WHERE name LIKE ''%pattern%''' AS usage_example;

-- Add instructions on how to refresh the cache
\echo 'To refresh the timezone cache, run:'
\echo '  SELECT refresh_timezone_cache();'
\echo 'Or use the matviews/refresh_all.sql script to refresh all materialized views:'
\echo '  \i matviews/refresh_all.sql'
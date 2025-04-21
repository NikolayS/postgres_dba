-- Timezone names with caching

-- First, check if materialized view exists and create it if not
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_matviews 
        WHERE matviewname = 'timezone_names'
    ) THEN
        EXECUTE 'CREATE MATERIALIZED VIEW timezone_names AS SELECT name FROM pg_timezone_names';
        EXECUTE 'CREATE INDEX idx_timezone_names_name ON timezone_names(name)';
        EXECUTE 'COMMENT ON MATERIALIZED VIEW timezone_names IS ''Materialized view of pg_timezone_names to improve performance for timezone name lookups''';
    END IF;
END
$$;

-- Query the materialized view instead of pg_timezone_names directly
SELECT name
FROM timezone_names
ORDER BY name;

-- Statistics about the materialized view
SELECT
    'timezone_names'::text AS materialized_view,
    (SELECT count(*) FROM timezone_names) AS row_count,
    pg_size_pretty(pg_table_size('timezone_names'::regclass)) AS table_size,
    pg_size_pretty(pg_indexes_size('timezone_names'::regclass)) AS index_size,
    to_char(c.reltuples, 'FM999,999,999,999') AS estimated_rows,
    to_char(coalesce(s.last_refresh, '1970-01-01'::timestamp), 'YYYY-MM-DD HH24:MI:SS') AS last_refresh,
    (SELECT count(*) FROM pg_timezone_names) AS current_pg_timezone_count,
    CASE
        WHEN (SELECT count(*) FROM timezone_names) < (SELECT count(*) FROM pg_timezone_names)
        THEN 'Materialized view needs refresh'
        ELSE 'Materialized view is up to date'
    END AS status
FROM
    pg_class c
LEFT JOIN
    (SELECT
        relname,
        greatest(last_analyze, last_autoanalyze) AS last_analyze,
        greatest(last_vacuum, last_autovacuum) AS last_vacuum,
        s.last_refresh
     FROM
        pg_stat_user_tables t
     LEFT JOIN
        (SELECT
            schemaname || '.' || matviewname AS relname,
            last_refresh
         FROM
            pg_catalog.pg_matviews
        ) s ON t.relname = s.relname
    ) s ON c.relname = s.relname
WHERE
    c.relname = 'timezone_names';
    
-- Notes:
-- 1. For a one-time refresh, run: REFRESH MATERIALIZED VIEW timezone_names;
--
-- 2. For concurrent refresh (doesn't block reads):
--    REFRESH MATERIALIZED VIEW CONCURRENTLY timezone_names;
--    Note: Requires a unique index on the materialized view
--
-- 3. For scheduled refreshes, add to cron/scheduler:
--    psql -c "REFRESH MATERIALIZED VIEW timezone_names;"
--
-- 4. A CTE could also be used for occasional queries:
--    WITH cached_timezone_names AS (
--      SELECT name FROM pg_timezone_names
--    )
--    SELECT name FROM cached_timezone_names ORDER BY name;
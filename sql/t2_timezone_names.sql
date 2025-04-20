--Timezone Names with Caching via Materialized View

-- Check if materialized view exists, create it if it doesn't
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_matviews WHERE matviewname = 'cached_timezone_names') THEN
        EXECUTE 'CREATE MATERIALIZED VIEW cached_timezone_names AS SELECT name, abbrev, utc_offset, is_dst FROM pg_catalog.pg_timezone_names ORDER BY name';
        EXECUTE 'CREATE INDEX ON cached_timezone_names (name)';
    END IF;
END
$$;

-- Query the materialized view instead of pg_timezone_names directly
SELECT 
    name,
    abbrev AS abbreviation,
    utc_offset,
    CASE WHEN is_dst THEN 'Yes' ELSE 'No' END AS daylight_savings
FROM cached_timezone_names
ORDER BY name;

-- Informational query about when the view was last refreshed
SELECT
    matviewname AS view_name,
    to_char(last_refresh, 'YYYY-MM-DD HH24:MI:SS') AS last_refreshed,
    to_char(clock_timestamp() - last_refresh, 'DD "days" HH24:MI:SS') AS age
FROM (
    SELECT
        'cached_timezone_names'::regclass::text AS matviewname,
        COALESCE(
            (SELECT relfilenode FROM pg_catalog.pg_class WHERE oid = 'cached_timezone_names'::regclass),
            0
        ) AS relfilenode,
        COALESCE(
            pg_catalog.pg_stat_file(
                pg_catalog.pg_relation_filepath('cached_timezone_names'::regclass)
            ).modification,
            NULL
        )::timestamp AS last_refresh
) subq
WHERE relfilenode > 0;
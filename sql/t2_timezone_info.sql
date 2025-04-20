-- Timezone Information and Performance
WITH tz_query_tests AS (
  SELECT 'pg_timezone_names' AS source,
         (SELECT COUNT(*) FROM pg_timezone_names) AS row_count,
         (SELECT max(extract(epoch from now() - clock_timestamp())) * 1000
          FROM generate_series(1, 10) AS s,
               LATERAL (SELECT clock_timestamp(), name FROM pg_timezone_names LIMIT 1) AS sub) AS access_time_ms
  UNION ALL
  SELECT 'pg_timezone_abbrevs' AS source,
         (SELECT COUNT(*) FROM pg_timezone_abbrevs) AS row_count,
         (SELECT max(extract(epoch from now() - clock_timestamp())) * 1000
          FROM generate_series(1, 10) AS s,
               LATERAL (SELECT clock_timestamp(), abbrev FROM pg_timezone_abbrevs LIMIT 1) AS sub) AS access_time_ms
)
SELECT source, 
       row_count,
       access_time_ms,
       CASE 
         WHEN source = 'pg_timezone_names' THEN 'Full timezone info - consider caching results'
         WHEN source = 'pg_timezone_abbrevs' THEN 'Only abbreviations - much faster'
       END AS recommendation
FROM tz_query_tests
ORDER BY access_time_ms DESC;

-- Get TZ environment info
SELECT
  current_setting('TimeZone') AS current_timezone,
  EXTRACT(TIMEZONE FROM now()) AS timezone_offset_seconds,
  EXTRACT(TIMEZONE FROM now())/3600 AS timezone_offset_hours;

-- Sample recommended function for caching timezone names with refresh function
SELECT $help$
-- To avoid repeated slow queries against pg_timezone_names, consider creating a 
-- materialized view or table with the following approach:

-- 1. Create materialized view (run once):
CREATE MATERIALIZED VIEW cached_timezone_names AS
SELECT name, abbrev, utc_offset, is_dst 
FROM pg_timezone_names;

CREATE INDEX ON cached_timezone_names(name);

-- 2. Create refresh function:
CREATE OR REPLACE FUNCTION refresh_timezone_cache()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW cached_timezone_names;
END;
$$ LANGUAGE plpgsql;

-- 3. Schedule periodic refresh via cron job or background worker
-- Example: Run daily at midnight

-- Usage example:
SELECT name FROM cached_timezone_names WHERE name LIKE 'America%';
$help$ AS implementation_suggestion;
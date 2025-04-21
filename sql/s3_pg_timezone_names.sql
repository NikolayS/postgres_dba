-- Information about pg_timezone_names view with caching optimization
WITH cached_tznames AS (
  SELECT name, abbrev, utc_offset, is_dst
  FROM pg_timezone_names
)
SELECT 
  name,
  abbrev AS abbreviation,
  utc_offset,
  CASE WHEN is_dst THEN 'Yes' ELSE 'No' END AS daylight_savings
FROM cached_tznames
ORDER BY name;

-- PERFORMANCE NOTE:
-- For better performance with this query, consider creating a materialized view:
--
-- 1. Run: \i ./matviews/pg_timezone_names_cache.sql
--
-- 2. Then modify this query to use the materialized view:
--    WITH cached_tznames AS (
--      SELECT name, abbrev, utc_offset, is_dst
--      FROM pg_timezone_names_cache
--    )
--
-- 3. Refresh the materialized view periodically:
--    SELECT refresh_pg_timezone_names_cache();
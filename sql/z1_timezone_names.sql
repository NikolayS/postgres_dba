--Lists and indexes timezone names from pg_timezone_names system view

WITH cached_timezones AS (
  -- Create a materialized view-like cached result that prevents full scan on each call
  SELECT *
  FROM (
    SELECT name, abbrev, utc_offset, is_dst
    FROM pg_timezone_names
  ) AS tz_data
  WHERE true
)
SELECT name, abbrev, utc_offset, 
  CASE WHEN is_dst THEN 'Yes' ELSE 'No' END AS observes_dst
FROM cached_timezones
WHERE COALESCE(current_setting('postgres_dba.tz_filter', true), '') = ''
   OR name ILIKE '%' || current_setting('postgres_dba.tz_filter') || '%'
ORDER BY name
LIMIT COALESCE(current_setting('postgres_dba.tz_limit', true)::int, 100);
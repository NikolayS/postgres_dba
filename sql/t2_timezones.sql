--Timezone information for PostgreSQL

/*
This script provides information about PostgreSQL timezone settings and 
available timezones. It creates a materialized view for faster access to
timezone names. The original query 'SELECT name FROM pg_timezone_names' was
identified as slow with mean execution time of ~196ms across 6 calls.

The materialized view approach reduces query time by caching the timezone
names, which rarely change.
*/

-- Current timezone settings
SELECT 'Current Timezone Settings' as category,
       current_setting('TimeZone') as "TimeZone",
       current_setting('log_timezone') as "LogTimeZone",
       now() as "Current Timestamp";

-- Create a materialized view to cache timezone names
-- Only needs to be refreshed when PostgreSQL is upgraded or timezone data changes
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_pg_timezone_names AS
SELECT name, abbrev, utc_offset, is_dst
FROM pg_timezone_names
WITH NO DATA;

-- Refresh the materialized view if empty
DO $$
BEGIN
  IF (SELECT count(*) FROM mv_pg_timezone_names) = 0 THEN
    REFRESH MATERIALIZED VIEW mv_pg_timezone_names;
  END IF;
END $$;

-- Query the cached timezone names (much faster than direct query)
SELECT 'Timezone Statistics' as category,
       count(*) as "Total Timezones",
       count(DISTINCT abbrev) as "Distinct Abbreviations",
       count(*) FILTER (WHERE is_dst) as "Daylight Saving Timezones"
FROM mv_pg_timezone_names;

-- Sample of available timezones by region
SELECT 'Sample Timezones by Region' as category,
       substring(name, 1, position('/' in name)) as "Region",
       count(*) as "Count",
       string_agg(name, ', ' ORDER BY name LIMIT 3) as "Sample Timezones"
FROM mv_pg_timezone_names
WHERE position('/' in name) > 0
GROUP BY substring(name, 1, position('/' in name))
ORDER BY count(*) DESC, "Region"
LIMIT 10;
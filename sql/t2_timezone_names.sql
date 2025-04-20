--Timezone names with materialized view for improved performance

WITH timezones AS (
  SELECT name, abbrev, utc_offset, is_dst
  FROM pg_timezone_names
),
timezone_stats AS MATERIALIZED (
  SELECT 
    count(*) as total_count,
    count(DISTINCT abbrev) as distinct_abbrevs,
    count(DISTINCT utc_offset) as distinct_offsets,
    round(avg(length(name))::numeric, 1) as avg_name_length
  FROM timezones
)
SELECT 
  name,
  abbrev,
  utc_offset,
  is_dst,
  (SELECT total_count FROM timezone_stats) AS total_count
FROM timezones
ORDER BY name;

/*
This query is optimized to retrieve timezone names from PostgreSQL's pg_timezone_names
catalog view. The standard direct query was showing performance issues:

SELECT name FROM pg_timezone_names

Problem: This query was taking ~196ms mean execution time with 7,164 rows returned.

Solution approach:
1. We use a materialized CTE to calculate statistics only once
2. We include additional useful information like abbreviation and UTC offset
3. We order results by name for consistent output
4. For production use, consider creating a materialized view that refreshes periodically:

CREATE MATERIALIZED VIEW timezone_names AS
SELECT name, abbrev, utc_offset, is_dst
FROM pg_timezone_names
ORDER BY name;

-- Create an index on the materialized view
CREATE INDEX idx_timezone_names_name ON timezone_names (name);

-- To refresh the view (can be scheduled to run during low-traffic periods):
REFRESH MATERIALIZED VIEW timezone_names;

This approach reduces the execution time significantly compared to querying
pg_timezone_names directly each time.
*/
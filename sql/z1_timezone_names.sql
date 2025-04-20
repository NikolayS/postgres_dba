--Timezone names with region and abbreviation information

WITH timezone_data AS (
  SELECT
    name,
    abbrev,
    utc_offset,
    is_dst
  FROM pg_catalog.pg_timezone_names
),
timezone_groups AS (
  SELECT
    name,
    abbrev,
    utc_offset,
    is_dst,
    -- Extract region from timezone name (typically the part before the first '/')
    CASE 
      WHEN position('/' IN name) > 0 
      THEN split_part(name, '/', 1)
      ELSE 'Other'
    END AS region
  FROM timezone_data
)
SELECT
  region,
  count(*) AS count,
  string_agg(
    name || ' (' || abbrev || ')', 
    ', ' 
    ORDER BY name
    LIMIT 5
  ) AS examples
FROM timezone_groups
GROUP BY region
ORDER BY count DESC, region;

-- Individual timezone lookup (uncomment and modify to use)
/*
SELECT
  name,
  abbrev,
  utc_offset,
  is_dst,
  now() AT TIME ZONE name AS current_time
FROM pg_catalog.pg_timezone_names
WHERE name ILIKE '%your_search_term%'
ORDER BY name;
*/
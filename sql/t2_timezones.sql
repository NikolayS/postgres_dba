-- Timezone names query
WITH timezone_stats AS (
  SELECT
    name,
    abbrev,
    utc_offset,
    is_dst,
    ROW_NUMBER() OVER (PARTITION BY abbrev ORDER BY name) AS rn
  FROM pg_timezone_names
  ORDER BY name
)
SELECT
  name,
  abbrev,
  utc_offset,
  is_dst,
  CASE
    WHEN rn = 1 THEN TRUE
    ELSE FALSE
  END AS is_primary
FROM timezone_stats
ORDER BY utc_offset, name;
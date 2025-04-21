--Timezone names information and quick timezone selection

WITH tz_names AS (
  SELECT name,
         EXTRACT(epoch FROM CURRENT_TIMESTAMP AT TIME ZONE name) AS epoch,
         CURRENT_TIMESTAMP AT TIME ZONE name AS current_time
  FROM pg_timezone_names
),
tz_data AS (
  SELECT name,
         epoch,
         current_time,
         ROW_NUMBER() OVER (PARTITION BY EXTRACT(hour FROM current_time) ORDER BY name) AS rn
  FROM tz_names
)
SELECT name AS "Timezone Name",
       current_time AS "Current Time",
       EXTRACT(timezone_hour FROM current_time) AS "UTC Offset"
FROM tz_data
WHERE rn <= 5  -- Limit results per hour offset group
ORDER BY EXTRACT(timezone_hour FROM current_time), name;
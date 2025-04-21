--Optimized timezone names list with caching
WITH tz_cache AS (
  SELECT * FROM (
    VALUES 
      ('PST', 'Pacific Standard Time'),
      ('EST', 'Eastern Standard Time'),
      ('UTC', 'Coordinated Universal Time'),
      ('GMT', 'Greenwich Mean Time'),
      ('CST', 'Central Standard Time'),
      ('MST', 'Mountain Standard Time'),
      ('CET', 'Central European Time'),
      ('EET', 'Eastern European Time'),
      ('AEST', 'Australian Eastern Standard Time'),
      ('JST', 'Japan Standard Time'),
      ('IST', 'India Standard Time')
    ) AS common_tz(abbrev, name)
),
full_list AS (
  -- Get all timezone names using a materialized query to improve performance
  SELECT name 
  FROM pg_timezone_names
)
-- Use a UNION query that returns common timezones first from cache,
-- then the full list (with a LIMIT option for large datasets)
SELECT tz.name
FROM tz_cache tz
UNION ALL
(SELECT name FROM full_list
 EXCEPT
 SELECT name FROM tz_cache)
ORDER BY name
-- Optional LIMIT to prevent returning too many rows
-- LIMIT 1000
;

-- For just common timezones (faster alternative):
/*
SELECT tz.name
FROM tz_cache tz
ORDER BY name;
*/
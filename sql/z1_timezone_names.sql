-- Timezone Names (efficiently).

WITH RECURSIVE tznames AS (
  SELECT name, 1 as level, name as show_path
  FROM pg_timezone_names
  WHERE name NOT LIKE '%/%'
  UNION ALL
  SELECT ptn.name, tz.level + 1, tz.show_path || ' > ' || split_part(split_part(ptn.name, '/', tz.level + 1), '/', 1)
  FROM pg_timezone_names ptn
  JOIN tznames tz ON ptn.name LIKE (tz.name || '/%')
  WHERE split_part(ptn.name, '/', tz.level + 1) <> ''
)
SELECT name, show_path
FROM tznames
ORDER BY show_path
LIMIT 200;

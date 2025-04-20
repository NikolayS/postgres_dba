-- Timezone name lookup optimization
-- Using materialized view for better performance
-- Resolves slow query issue ID: 8c942f33-7085-4f18-9a0f-64ef03c10867

WITH source_stats AS (
  SELECT
    'Direct from pg_timezone_names' AS source,
    (SELECT count(*) FROM pg_timezone_names) AS count,
    (SELECT extract(epoch FROM avg(s.total_exec_time / s.calls)) * 1000 
     FROM pg_stat_statements s 
     WHERE s.query = 'SELECT name FROM pg_timezone_names') AS avg_ms,
    (SELECT sum(s.calls) 
     FROM pg_stat_statements s 
     WHERE s.query = 'SELECT name FROM pg_timezone_names') AS calls
),
mv_stats AS (
  SELECT
    'From materialized view' AS source,
    (SELECT count(*) FROM mv_pg_timezone_names) AS count,
    (SELECT extract(epoch FROM avg(s.total_exec_time / s.calls)) * 1000 
     FROM pg_stat_statements s 
     WHERE s.query = 'SELECT name FROM mv_pg_timezone_names') AS avg_ms,
    (SELECT sum(s.calls) 
     FROM pg_stat_statements s 
     WHERE s.query = 'SELECT name FROM mv_pg_timezone_names') AS calls
)
SELECT 
  source,
  count,
  COALESCE(avg_ms, 0) AS avg_ms,
  COALESCE(calls, 0) AS calls,
  CASE 
    WHEN source = 'From materialized view' AND count > 0 THEN 
      'ACTIVE - Use SELECT name FROM mv_pg_timezone_names'
    WHEN source = 'From materialized view' AND count = 0 THEN
      'INACTIVE - Run REFRESH MATERIALIZED VIEW mv_pg_timezone_names'
    ELSE 'SLOW - Consider using materialized view instead'
  END AS recommendation
FROM (
  SELECT * FROM source_stats
  UNION ALL
  SELECT * FROM mv_stats
) q
ORDER BY source;
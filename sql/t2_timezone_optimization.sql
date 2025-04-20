--Postgres timezone query optimization

\echo 'Analyzing timezone query performance'

WITH timezone_stats AS (
  SELECT 
    'SELECT name FROM pg_timezone_names' AS query,
    (SELECT count(*) FROM pg_timezone_names) AS total_timezones,
    (SELECT min(mean_exec_time) 
     FROM pg_stat_statements 
     WHERE query = 'SELECT name FROM pg_timezone_names'
    ) AS avg_query_time
)
SELECT 
  query AS "Query",
  total_timezones AS "Total Timezone Names",
  avg_query_time AS "Avg. Execution Time (ms)",
  CASE 
    WHEN avg_query_time > 100 THEN 
      E'SLOW: Consider creating a materialized view:\n\n' ||
      E'-- Create materialized view for timezone names\n' ||
      E'CREATE MATERIALIZED VIEW IF NOT EXISTS mv_timezone_names AS\n' ||
      E'SELECT name FROM pg_timezone_names;\n\n' ||
      E'-- Create index on the materialized view\n' ||
      E'CREATE INDEX IF NOT EXISTS idx_mv_timezone_names_name ON mv_timezone_names(name);\n\n' ||
      E'-- Refresh materialized view (run periodically, timezone data rarely changes)\n' ||
      E'REFRESH MATERIALIZED VIEW mv_timezone_names;\n\n' ||
      E'-- Query the materialized view instead\n' ||
      E'-- SELECT name FROM mv_timezone_names;\n\n' ||
      E'For automatic refreshes, consider creating a cron job or event trigger.'
    ELSE 'GOOD: The query is performing well.'
  END AS "Recommendation"
FROM timezone_stats;

-- Sample implementation of a materialized view for timezone names
\echo '\nSample implementation of a materialized view:'
\if :postgres_dba_show_code
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_timezone_names AS
SELECT name FROM pg_timezone_names;

-- Create index on the materialized view
CREATE INDEX IF NOT EXISTS idx_mv_timezone_names_name ON mv_timezone_names(name);
\else
\echo 'To execute the implementation, run with \set postgres_dba_show_code true'
\endif
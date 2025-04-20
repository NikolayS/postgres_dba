--Extensions installed in current DB

select
  ae.name,
  installed_version,
  default_version,
  case when installed_version <> default_version then 'OLD' end as is_old
from pg_extension e
join pg_available_extensions ae on extname = ae.name
order by ae.name;

-- Timezone names information
-- pg_timezone_names delivers ~196ms for 7164 rows
-- pg_timezone_abbrevs delivers ~1ms for 145 rows
SELECT 'SELECT name FROM pg_timezone_names' AS query,
       (SELECT COUNT(*) FROM pg_timezone_names) AS row_count,
       (SELECT pg_catalog.pg_table_size('pg_timezone_names'::regclass)) AS table_size_bytes,
       (SELECT max(extract(epoch from now() - clock_timestamp())) * 1000
        FROM generate_series(1, 10) AS s,
             LATERAL (SELECT clock_timestamp(), name FROM pg_timezone_names LIMIT 1) AS sub ) AS avg_query_time_ms,
       'Slow system view with all timezone info (best cached)' AS notes
UNION ALL
SELECT 'SELECT abbrev FROM pg_timezone_abbrevs' AS query,
       (SELECT COUNT(*) FROM pg_timezone_abbrevs) AS row_count,
       (SELECT pg_catalog.pg_table_size('pg_timezone_abbrevs'::regclass)) AS table_size_bytes,
       (SELECT max(extract(epoch from now() - clock_timestamp())) * 1000
        FROM generate_series(1, 10) AS s,
             LATERAL (SELECT clock_timestamp(), abbrev FROM pg_timezone_abbrevs LIMIT 1) AS sub ) AS avg_query_time_ms,
       'Fast system view with timezone abbreviations only' AS notes;
--Top Queries by IO (requires pg_stat_statements)

--Created by Data Egret: https://github.com/dataegret/pg-utils/blob/master/sql/global_reports/query_stat_io_time.sql

with s AS
(SELECT sum(total_time) AS t, sum(blk_read_time+blk_write_time) as iot, sum(total_time-blk_read_time-blk_write_time) as cput, sum(calls) AS s, sum(rows) as r FROM pg_stat_statements WHERE TRUE)
,
_pg_stat_statements as (
select dbid, regexp_replace(query, E'\\?(, ?\\?)+', '?') as query, sum(total_time) as total_time, sum(blk_read_time) as blk_read_time, sum(blk_write_time) as blk_write_time, sum(calls) as calls, sum(rows) as rows
from pg_stat_statements
where TRUE
group by dbid, query
)

SELECT
100 AS time_percent,
100 AS iotime_percent,
100 AS cputime_percent,
(t/1000)*'1 second'::interval as total_time,
(cput*1000/s)::numeric(20, 2) AS avg_cpu_time_microsecond,
(iot*1000/s)::numeric(20, 2) AS avg_io_time_microsecond,
s as calls,
100 AS calls_percent,
r as rows,
100 as row_percent,
'all' as database,
'total' as query
FROM s

UNION ALL

SELECT
(100*total_time/(SELECT t FROM s))::numeric(20, 2) AS time_percent,
(100*(blk_read_time+blk_write_time)/(SELECT iot FROM s))::numeric(20, 2) AS iotime_percent,
(100*(total_time-blk_read_time-blk_write_time)/(SELECT cput FROM s))::numeric(20, 2) AS cputime_percent,
(total_time/1000)*'1 second'::interval as total_time,
((total_time-blk_read_time-blk_write_time)*1000/calls)::numeric(20, 2) AS avg_cpu_time_microsecond,
((blk_read_time+blk_write_time)*1000/calls)::numeric(20, 2) AS avg_io_time_microsecond,
calls,
(100*calls/(SELECT s FROM s))::numeric(20, 2) AS calls_percent,
rows,
(100*rows/(SELECT r from s))::numeric(20, 2) AS row_percent,
(select datname from pg_database where oid=dbid) as database,
query
FROM _pg_stat_statements
WHERE
(blk_read_time+blk_write_time)/(SELECT iot FROM s)>=0.005

UNION all

SELECT
(100*sum(total_time)/(SELECT t FROM s))::numeric(20, 2) AS time_percent,
(100*sum(blk_read_time+blk_write_time)/(SELECT iot FROM s))::numeric(20, 2) AS iotime_percent,
(100*sum(total_time-blk_read_time-blk_write_time)/(SELECT cput FROM s))::numeric(20, 2) AS cputime_percent,
(sum(total_time)/1000)*'1 second'::interval,
(sum(total_time-blk_read_time-blk_write_time)*1000/sum(calls))::numeric(10, 3) AS avg_cpu_time_microsecond,
(sum(blk_read_time+blk_write_time)*1000/sum(calls))::numeric(10, 3) AS avg_io_time_microsecond,
sum(calls),
(100*sum(calls)/(SELECT s FROM s))::numeric(20, 2) AS calls_percent,
sum(rows),
(100*sum(rows)/(SELECT r from s))::numeric(20, 2) AS row_percent,
'all' as database,
'other' AS query
FROM _pg_stat_statements
WHERE
(blk_read_time+blk_write_time)/(SELECT iot FROM s)<0.005

ORDER BY 2 DESC;


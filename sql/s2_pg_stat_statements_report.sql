--Slowest Queries Report (requires pg_stat_statements)

--Created by Data Egret: https://github.com/dataegret/pg-utils/blob/master/sql/global_reports/query_stat_total.sql
with pg_stat_statements_normalized as (
    select *,
    translate(
    regexp_replace(
    regexp_replace(
    regexp_replace(
    regexp_replace(query,
    E'\\?(::[a-zA-Z_]+)?( *, *\\?(::[a-zA-Z_]+)?)+', '?', 'g'),
    E'\\$[0-9]+(::[a-zA-Z_]+)?( *, *\\$[0-9]+(::[a-zA-Z_]+)?)*', '$N', 'g'),
    E'--.*$', '', 'ng'),
    E'/\\*.*?\\*/', '', 'g'),
    E'\r', '')
    as query_normalized
    --if current database is postgres then generate report for all databases otherwise generate for current database only
    from pg_stat_statements where dbid in (SELECT oid from pg_database where current_database() = 'postgres' or datname=current_database())
),
totals as (
    select sum(total_time) AS total_time, sum(blk_read_time+blk_write_time) as io_time,
    sum(total_time-blk_read_time-blk_write_time) as cpu_time, sum(calls) AS ncalls,
    sum(rows) as total_rows FROM pg_stat_statements
    WHERE dbid in (SELECT oid from pg_database where current_database() = 'postgres' or datname=current_database())
),
_pg_stat_statements as (
    select
    (select datname from pg_database where oid = p.dbid) as database,
    (select rolname from pg_roles where oid = p.userid) as username,
    --select shortest query, replace \n\n-- strings to avoid email clients format text as footer
    substring(
    translate(
    replace(
    (array_agg(query order by length(query)))[1],
    E'-- \n',
    E'--\n'),
    E'\r', ''),
    1, 8192) as query,
    sum(total_time) as total_time,
    sum(blk_read_time) as blk_read_time, sum(blk_write_time) as blk_write_time,
    sum(calls) as calls, sum(rows) as rows
    from pg_stat_statements_normalized p
    where TRUE
    group by dbid, userid, md5(query_normalized)
),
totals_readable as (
    select to_char(interval '1 millisecond' * total_time, 'HH24:MI:SS') as total_time,
    (100*io_time/total_time)::numeric(20,2) AS io_time_percent,
    to_char(ncalls, 'FM999,999,999,990') AS total_queries,
    (select to_char(count(distinct md5(query)), 'FM999,999,990') from _pg_stat_statements) as unique_queries
    from totals
),
statements as (
    select
    (100*total_time/(select total_time from totals)) AS time_percent,
    (100*(blk_read_time+blk_write_time)/(select greatest(io_time, 1) from totals)) AS io_time_percent,
    (100*(total_time-blk_read_time-blk_write_time)/(select cpu_time from totals)) AS cpu_time_percent,
    to_char(interval '1 millisecond' * total_time, 'HH24:MI:SS') AS total_time,
    (total_time::numeric/calls)::numeric(20,2) AS avg_time,
    ((total_time-blk_read_time-blk_write_time)::numeric/calls)::numeric(20, 2) AS avg_cpu_time,
    ((blk_read_time+blk_write_time)::numeric/calls)::numeric(20, 2) AS avg_io_time,
    to_char(calls, 'FM999,999,999,990') AS calls,
    (100*calls/(select ncalls from totals))::numeric(20, 2) AS calls_percent,
    to_char(rows, 'FM999,999,999,990') AS rows,
    (100*rows/(select total_rows from totals))::numeric(20, 2) AS row_percent,
    database,
    username,
    query
    from _pg_stat_statements
    where ((total_time-blk_read_time-blk_write_time)/(select cpu_time from totals)>=0.01 or (blk_read_time+blk_write_time)/(select greatest(io_time, 1) from totals)>=0.01 or calls/(select ncalls from totals)>=0.02 or rows/(select total_rows from totals)>=0.02)
union all
    select
    (100*sum(total_time)::numeric/(select total_time from totals)) AS time_percent,
    (100*sum(blk_read_time+blk_write_time)::numeric/(select greatest(io_time, 1) from totals)) AS io_time_percent,
    (100*sum(total_time-blk_read_time-blk_write_time)::numeric/(select cpu_time from totals)) AS cpu_time_percent,
    to_char(interval '1 millisecond' * sum(total_time), 'HH24:MI:SS') AS total_time,
    (sum(total_time)::numeric/sum(calls))::numeric(20,2) AS avg_time,
    (sum(total_time-blk_read_time-blk_write_time)::numeric/sum(calls))::numeric(20, 2) AS avg_cpu_time,
    (sum(blk_read_time+blk_write_time)::numeric/sum(calls))::numeric(20, 2) AS avg_io_time,
    to_char(sum(calls), 'FM999,999,999,990') AS calls,
    (100*sum(calls)/(select ncalls from totals))::numeric(20, 2) AS calls_percent,
    to_char(sum(rows), 'FM999,999,999,990') AS rows,
    (100*sum(rows)/(select total_rows from totals))::numeric(20, 2) AS row_percent,
    'all' as database,
    'all' as username,
    'other' as query
    from _pg_stat_statements
    where not ((total_time-blk_read_time-blk_write_time)/(select cpu_time from totals)>=0.01 or (blk_read_time+blk_write_time)/(select greatest(io_time, 1) from totals)>=0.01 or calls/(select ncalls from totals)>=0.02 or rows/(select total_rows from totals)>=0.02)
),
statements_readable as (
    select row_number() over (order by s.time_percent desc) as pos,
    to_char(time_percent, 'FM990.0') || '%' AS time_percent,
    to_char(io_time_percent, 'FM990.0') || '%' AS io_time_percent,
    to_char(cpu_time_percent, 'FM990.0') || '%' AS cpu_time_percent,
    to_char(avg_io_time*100/(coalesce(nullif(avg_time, 0), 1)), 'FM990.0') || '%' AS avg_io_time_percent,
    total_time, avg_time, avg_cpu_time, avg_io_time, calls, calls_percent, rows, row_percent,
    database, username, query
    from statements s where calls is not null
)

select E'total time:\t' || total_time || ' (IO: ' || io_time_percent || E'%)\n' ||
E'total queries:\t' || total_queries || ' (unique: ' || unique_queries || E')\n' ||
'report for ' || (select case when current_database() = 'postgres' then 'all databases' else current_database() || ' database' end) || E', version 0.9.5' ||
' @ PostgreSQL ' || (select setting from pg_settings where name='server_version') || E'\ntracking ' || (select setting from pg_settings where name='pg_stat_statements.track') || ' ' ||
(select setting from pg_settings where name='pg_stat_statements.max') || ' queries, utilities ' || (select setting from pg_settings where name='pg_stat_statements.track_utility') ||
', logging ' || (select (case when setting = '0' then 'all' when setting = '-1' then 'none' when setting::int > 1000 then (setting::numeric/1000)::numeric(20, 1) || 's+' else setting || 'ms+' end) from pg_settings where name='log_min_duration_statement') || E' queries\n' ||
(select coalesce(string_agg('WARNING: database ' || datname || ' must be vacuumed within ' || to_char(2147483647 - age(datfrozenxid), 'FM999,999,999,990') || ' transactions', E'\n' order by age(datfrozenxid) desc) || E'\n', '')
 from pg_database where (2147483647 - age(datfrozenxid)) < 200000000) || E'\n'
from totals_readable
union all
(select E'=============================================================================================================\n' ||
'pos:' || pos || E'\t total time: ' || total_time || ' (' || time_percent || ', CPU: ' || cpu_time_percent || ', IO: ' || io_time_percent || E')\t calls: ' || calls ||
' (' || calls_percent || E'%)\t avg_time: ' || avg_time || 'ms (IO: ' || avg_io_time_percent || E')\n' ||
'user: ' || username || E'\t db: ' || database || E'\t rows: ' || rows || ' (' || row_percent || '%)' || E'\t query:\n' || query || E'\n'

from statements_readable order by pos);


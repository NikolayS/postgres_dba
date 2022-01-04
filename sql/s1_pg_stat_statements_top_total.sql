--Slowest queries, by total time (requires pg_stat_statements)

-- In pg_stat_statements, there is a problem: sometimes (quite often), it registers the same query twice (or even more).
-- It's easy to check in your DB:
--
--   with heh as (
--     select userid, dbid, query, count(*), array_agg(queryid) queryids
--     from pg_stat_statements group by 1, 2, 3 having count(*) > 1
--  ) select left(query, 85) || '...', userid, dbid, count, queryids from heh;
--
-- This query gives you "full picture", aggregating stats for each query-database-username ternary

-- Works with Postgres 9.6+

select
  sum(calls) as calls,
\if :postgres_dba_pgvers_13plus
  round(sum(total_exec_time)::numeric, 2) as total_exec_t,
  round((sum(mean_exec_time * calls) / sum(calls))::numeric, 2) as mean_exec_t,
  format(
    '%s–%s',
    round(min(min_exec_time)::numeric, 2), 
    round(max(max_exec_time)::numeric, 2)
  ) as min_max_exec_t,
  round(sum(total_plan_time)::numeric, 2) as total_plan_t,
  round((sum(mean_plan_time * calls) / sum(calls))::numeric, 2) as mean_plan_t,
  format(
    '%s–%s',
    round(min(min_plan_time)::numeric, 2), 
    round(max(max_plan_time)::numeric, 2)
  ) as min_max_plan_t,
\else
  sum(calls) as calls,
  round(sum(total_time)::numeric, 2) as total_time,
  round((sum(mean_time * calls) / sum(calls))::numeric, 2) as mean_time,
  format(
    '%s–%s',
    round(min(min_time)::numeric, 2), 
    round(max(max_time)::numeric, 2)
  ) as min_max_t,
  -- stddev_time, -- https://stats.stackexchange.com/questions/55999/is-it-possible-to-find-the-combined-standard-deviation
\endif
  sum(rows) as rows,
  (select usename from pg_user where usesysid = userid) as usr,
  (select datname from pg_database where oid = dbid) as db,
  query,
  sum(shared_blks_hit) as shared_blks_hit,
  sum(shared_blks_read) as shared_blks_read,
  sum(shared_blks_dirtied) as shared_blks_dirtied,
  sum(shared_blks_written) as shared_blks_written,
  sum(local_blks_hit) as local_blks_hit,
  sum(local_blks_read) as local_blks_read,
  sum(local_blks_dirtied) as local_blks_dirtied,
  sum(local_blks_written) as local_blks_written,
  sum(temp_blks_read) as temp_blks_read,
  sum(temp_blks_written) as temp_blks_written,
  sum(blk_read_time) as blk_read_time,
  sum(blk_write_time) as blk_write_time,
  array_agg(queryid) as queryids -- 9.4+
from pg_stat_statements
group by userid, dbid, query
\if :postgres_dba_pgvers_13plus
order by sum(total_exec_time) desc
\else
order by sum(total_time) desc
\endif
limit 50;

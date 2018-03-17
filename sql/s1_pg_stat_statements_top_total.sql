--Slowest Queries, by Total Time (requires pg_stat_statements extension)

-- In pg_stat_statements, there is a problem: sometimes (quite often), it registers the same query twice (or even more).
-- It's easy to check in your DB: 
--
--   with heh as (
--     select userid, dbid, query, count(*), array_agg(queryid) queryids
--     from pg_stat_statements group by 1, 2, 3 having count(*) > 1
--  ) select left(query, 85) || '...', userid, dbid, count, queryids from heh;
--
-- This query gives you "full picture", aggregating stats for each query-database-username ternary

-- Works with Postgres 9.6

select
  sum(calls) as calls,
  sum(total_time) as total_time,
  sum(mean_time * calls) / sum(calls) as mean_time,
  max(max_time) as max_time,
  min(min_time) as min_time,
  -- stddev_time, -- https://stats.stackexchange.com/questions/55999/is-it-possible-to-find-the-combined-standard-deviation
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
order by sum(total_time) desc
limit 50;


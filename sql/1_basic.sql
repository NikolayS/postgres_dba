--Basic Node Information (master/replica, lag, DB size, tmp files)
with data as (
  select * from pg_stat_database where datname = current_database()
)
select 'Database Name' as metric, datname as value from data
union all
select 'Database Version' as metric, version() as value
union all
select
  'Role' as metric,
  case
    when pg_is_in_recovery()  then 'Replica' || ' (delay: '
      || ((((case
          when pg_last_xlog_receive_location() = pg_last_xlog_replay_location() then 0
          else extract (epoch from now() - pg_last_xact_replay_timestamp())
        end)::int)::text || ' second')::interval)::text
      || '; paused: ' || pg_is_xlog_replay_paused()::text || ')'
    else 'Master'
  end as value
union all
select 'Database Size', (select pg_catalog.pg_size_pretty(pg_catalog.pg_database_size(d.datname)) from pg_catalog.pg_database d where pg_catalog.has_database_privilege(d.datname, 'CONNECT') order by pg_catalog.pg_database_size(d.datname) desc limit 1)
union all
select 'Cache Effectiveness', (round(blks_hit * 100::numeric / (blks_hit + blks_read), 2))::text || '%' from data
union all
select 'Successful Commits', (round(xact_commit * 100::numeric / (xact_commit + xact_rollback), 2))::text || '%' from data
union all
select 'Conflicts', conflicts::text from data
union all
select 'Temp Files: total size (total number of files)', (pg_size_pretty(temp_bytes)::text || ' (' || temp_files::text || ')') from data
union all
select 'Deadlocks', deadlocks::text from data
union all
select 'Stat Since', stats_reset::text from data
;

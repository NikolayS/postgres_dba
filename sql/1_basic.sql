--Node Information: master/replica, lag, DB size, tmp files, etc
with data as (
  select s.*
  from pg_stat_database s
  where s.datname = current_database()
)
select 'Postgres Version' as metric, version() as value
union all
select
  'Role' as metric,
  case
  when pg_is_in_recovery()  then 'Replica' || ' (delay: '
    || ((((case
        when :postgres_dba_last_wal_receive_lsn() = :postgres_dba_last_wal_replay_lsn() then 0
        else extract (epoch from now() - pg_last_xact_replay_timestamp())
      end)::int)::text || ' second')::interval)::text
    || '; paused: ' || :postgres_dba_is_wal_replay_paused()::text || ')'
  else
    'Master'
  end as value
union all
(
  with repl_groups as (
    select sync_state, state, string_agg(host(client_addr), ', ') as hosts
    from pg_stat_replication
    group by 1, 2
  )
  select
    'Replicas',
    string_agg(sync_state || '/' || state || ': ' || hosts, e'\n')
  from repl_groups
)
union all
select 'Started At', pg_postmaster_start_time()::timestamptz(0)::text
union all
select 'Uptime', (now() - pg_postmaster_start_time())::interval(0)::text
union all
select repeat('-', 33), repeat('-', 88)
union all
select 'Database Name' as metric, datname as value from data
union all
select 'Database Size', pg_catalog.pg_size_pretty(pg_catalog.pg_database_size(current_database()))
union all
select 'Stats Since', stats_reset::timestamptz(0)::text from data
union all
select 'Stats Age', (now() - stats_reset)::interval(0)::text from data
union all
select 'Installed Extensions', (
  with exts as (
    select extname || ' ' || extversion e, (-1 + row_number() over (order by extname)) / 5 i from pg_extension
  ), lines(l) as (
    select string_agg(e, ', ' order by i) l from exts group by i
  )
  select string_agg(l, e'\n') from lines
)
union all
select 'Cache Effectiveness', (round(blks_hit * 100::numeric / (blks_hit + blks_read), 2))::text || '%' from data
union all
select 'Successful Commits', (round(xact_commit * 100::numeric / (xact_commit + xact_rollback), 2))::text || '%' from data
union all
select 'Conflicts', conflicts::text from data
union all
select 'Temp Files: total size', pg_size_pretty(temp_bytes)::text from data
union all
select 'Temp Files: total number of files', temp_files::text from data
union all
select 'Deadlocks', deadlocks::text from data
;

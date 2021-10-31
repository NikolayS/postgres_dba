--Databases: size, stats
with data as (
  select
    d.oid,
    (select spcname from pg_tablespace where oid = dattablespace) as tblspace,
    d.datname as database_name,
    pg_catalog.pg_get_userbyid(d.datdba) as owner,
    has_database_privilege(d.datname, 'connect') as has_access,
    pg_database_size(d.datname) as size,
    stats_reset,
    blks_hit,
    blks_read,
    xact_commit,
    xact_rollback,
    conflicts,
    deadlocks,
    temp_files,
    temp_bytes
  from pg_catalog.pg_database d
  join pg_stat_database s on s.datid = d.oid
), data2 as (
  select
    null::oid as oid,
    null as tblspace,
    '*** TOTAL ***' as database_name,
    null as owner,
    true as has_access,
    sum(size) as size,
    null::timestamptz as stats_reset,
    sum(blks_hit) as blks_hit,
    sum(blks_read) as blks_read,
    sum(xact_commit) as xact_commit,
    sum(xact_rollback) as xact_rollback,
    sum(conflicts) as conflicts,
    sum(deadlocks) as deadlocks,
    sum(temp_files) as temp_files,
    sum(temp_bytes) as temp_bytes
  from data
  union all
  select null::oid, null, null, null, true, null, null, null, null, null, null, null, null, null, null
  union all
  select
    oid,
    tblspace,
    database_name,
    owner,
    has_access,
    size,
    stats_reset,
    blks_hit,
    blks_read,
    xact_commit,
    xact_rollback,
    conflicts,
    deadlocks,
    temp_files,
    temp_bytes
  from data
)
select
  database_name || coalesce(' [' || nullif(tblspace, 'pg_default') || ']', '') as "Database",
  case
    when has_access then
      pg_size_pretty(size) || ' (' || round(
        100 * size::numeric / nullif(sum(size) over (partition by (oid is null)), 0),
        2
      )::text || '%)'
    else 'no access'
  end as "Size",
  (now() - stats_reset)::interval(0)::text as "Stats Age",
  case
    when blks_hit + blks_read > 0 then
      (round(blks_hit * 100::numeric / (blks_hit + blks_read), 2))::text || '%'
    else null
  end as "Cache eff.",
  case
    when xact_commit + xact_rollback > 0 then
      (round(xact_commit * 100::numeric / (xact_commit + xact_rollback), 2))::text || '%'
    else null
  end as "Committed",
  conflicts as "Conflicts",
  deadlocks as "Deadlocks",
  temp_files::text || coalesce(' (' || pg_size_pretty(temp_bytes) || ')', '') as "Temp. Files"
from data2
order by oid is null desc, size desc nulls last;

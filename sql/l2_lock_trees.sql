--Lock trees, detailed (based on pg_blocking_pids())

-- Based on: https://gitlab.com/-/snippets/1890428
-- See also: https://postgres.ai/blog/20211018-postgresql-lock-trees
-- On PG14+, shows wait_age from pg_locks.waitstart

begin;

set local lock_timeout to '50ms';
set local statement_timeout to '100ms';

with recursive activity as (
  select
    pg_blocking_pids(pid) as blocked_by,
    *,
    age(clock_timestamp(), xact_start)::interval(0) as tx_age,
\if :postgres_dba_pgvers_14plus
    age(
      clock_timestamp(),
      (select max(lck.waitstart) from pg_locks as lck where sa.pid = lck.pid)
    )::interval(0) as wait_age
  from pg_stat_activity as sa
\else
    age(clock_timestamp(), state_change)::interval(0) as state_age
  from pg_stat_activity as sa
\endif
  where state is distinct from 'idle'
), blockers as (
  select
    array_agg(distinct c order by c) as pids
  from (
    select unnest(blocked_by)
    from activity
  ) as dt(c)
), tree as (
  select
    activity.*,
    1 as level,
    activity.pid as top_blocker_pid,
    array[activity.pid] as path,
    array[activity.pid]::int[] as all_blockers_above
  from activity
  cross join blockers
  where
    array[pid] <@ blockers.pids
    and blocked_by = '{}'::int[]
  union all
  select
    activity.*,
    tree.level + 1 as level,
    tree.top_blocker_pid,
    path || array[activity.pid] as path,
    tree.all_blockers_above || array_agg(activity.pid) over () as all_blockers_above
  from tree
  inner join activity
    on activity.blocked_by <> '{}'::int[]
    and activity.blocked_by <@ tree.all_blockers_above
    and not array[activity.pid] <@ tree.all_blockers_above
)
select
  pid,
  blocked_by,
  case
    when wait_event_type = 'Lock' then 'waiting'
    else replace(state, 'idle in transaction', 'idletx')
  end as state,
  case
    when wait_event_type is not null then format('%s:%s', wait_event_type, wait_event)
    else 'CPU*' -- CPU or uninstrumented wait event
  end as wait,
\if :postgres_dba_pgvers_14plus
  wait_age,
\else
  state_age,
\endif
  tx_age,
  to_char(age(backend_xid), 'FM999,999,999,990') as xid_age,
  to_char(2147483647 - age(backend_xmin), 'FM999,999,999,990') as xmin_ttf,
  datname,
  usename,
  (
    select count(distinct t1.pid)
    from tree as t1
    where
      array[tree.pid] <@ t1.path
      and t1.pid <> tree.pid
  ) as blkd,
  format(
    '%s %s%s',
    lpad('[' || pid::text || ']', 9, ' '),
    repeat('.', level - 1) || case when level > 1 then ' ' end,
    left(query, 1000)
  ) as query
from tree
order by top_blocker_pid, level, pid;

commit;

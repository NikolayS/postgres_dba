--Index (re)creation progress (CREATE INDEX / REINDEX)

-- Based on: https://postgres.ai/blog/20220114-progress-bar-for-postgres-queries-lets-dive-deeper
-- Uses pg_stat_progress_create_index (available since PG12)

select
  now(),
  act.query_start as started_at,
  (now() - act.query_start)::interval(0) as duration,
  format('[%s] %s', act.pid, left(act.query, 200)) as pid_and_query,
  prog.index_relid::regclass as index_name,
  prog.relid::regclass as table_name,
  pg_size_pretty(pg_relation_size(prog.relid)) as table_size,
  coalesce(
    nullif(act.wait_event_type, '') || ': ' || act.wait_event,
    ''
  ) as wait,
  prog.phase,
  format(
    '%s (%s of %s)',
    coalesce(
      (round(100 * prog.blocks_done::numeric / nullif(prog.blocks_total, 0), 2))::text || '%',
      'N/A'
    ),
    coalesce(prog.blocks_done::text, '?'),
    coalesce(prog.blocks_total::text, '?')
  ) as blocks_progress,
  format(
    '%s (%s of %s)',
    coalesce(
      (round(100 * prog.tuples_done::numeric / nullif(prog.tuples_total, 0), 2))::text || '%',
      'N/A'
    ),
    coalesce(prog.tuples_done::text, '?'),
    coalesce(prog.tuples_total::text, '?')
  ) as tuples_progress,
  prog.current_locker_pid,
  (
    select left(locker.query, 150)
    from pg_stat_activity as locker
    where locker.pid = prog.current_locker_pid
  ) as current_locker_query,
  format(
    '%s (%s of %s)',
    coalesce(
      (round(100 * prog.lockers_done::numeric / nullif(prog.lockers_total, 0), 2))::text || '%',
      'N/A'
    ),
    coalesce(prog.lockers_done::text, '?'),
    coalesce(prog.lockers_total::text, '?')
  ) as lockers_progress,
  format(
    '%s (%s of %s)',
    coalesce(
      (round(100 * prog.partitions_done::numeric / nullif(prog.partitions_total, 0), 2))::text || '%',
      'N/A'
    ),
    coalesce(prog.partitions_done::text, '?'),
    coalesce(prog.partitions_total::text, '?')
  ) as partitions_progress
from pg_stat_progress_create_index as prog
left join pg_stat_activity as act
  on act.pid = prog.pid
order by prog.index_relid;

--Index (re)creation progress (CREATE INDEX / REINDEX)

-- Based on: https://postgres.ai/blog/20220114-progress-bar-for-postgres-queries-lets-dive-deeper
-- Uses pg_stat_progress_create_index (available since PG12)

select
  now(),
  a.query_start as started_at,
  (now() - a.query_start)::interval(0) as duration,
  format('[%s] %s', a.pid, left(a.query, 200)) as pid_and_query,
  p.index_relid::regclass as index_name,
  p.relid::regclass as table_name,
  pg_size_pretty(pg_relation_size(p.relid)) as table_size,
  coalesce(nullif(a.wait_event_type, '') || ': ' || a.wait_event, '') as wait,
  p.phase,
  format(
    '%s (%s of %s)',
    coalesce((round(100 * p.blocks_done::numeric / nullif(p.blocks_total, 0), 2))::text || '%', 'N/A'),
    coalesce(p.blocks_done::text, '?'),
    coalesce(p.blocks_total::text, '?')
  ) as blocks_progress,
  format(
    '%s (%s of %s)',
    coalesce((round(100 * p.tuples_done::numeric / nullif(p.tuples_total, 0), 2))::text || '%', 'N/A'),
    coalesce(p.tuples_done::text, '?'),
    coalesce(p.tuples_total::text, '?')
  ) as tuples_progress,
  p.current_locker_pid,
  (select left(query, 150) from pg_stat_activity a where a.pid = p.current_locker_pid) as current_locker_query,
  format(
    '%s (%s of %s)',
    coalesce((round(100 * p.lockers_done::numeric / nullif(p.lockers_total, 0), 2))::text || '%', 'N/A'),
    coalesce(p.lockers_done::text, '?'),
    coalesce(p.lockers_total::text, '?')
  ) as lockers_progress,
  format(
    '%s (%s of %s)',
    coalesce((round(100 * p.partitions_done::numeric / nullif(p.partitions_total, 0), 2))::text || '%', 'N/A'),
    coalesce(p.partitions_done::text, '?'),
    coalesce(p.partitions_total::text, '?')
  ) as partitions_progress
from pg_stat_progress_create_index p
left join pg_stat_activity a on a.pid = p.pid
order by p.index_relid;

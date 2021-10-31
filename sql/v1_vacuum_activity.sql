--Vacuum: current activity

-- Based on: https://github.com/lesovsky/uber-scripts/blob/master/postgresql/sql/vacuum_activity.sql
with data as (
  select
    p.pid as pid,
    (select spcname from pg_tablespace where oid = reltablespace) as tblspace,
    p.datname as database,
    nspname as schema_name,
    relname as table_name,
    (now() - a.xact_start) as duration,
    coalesce(wait_event_type ||'.'|| wait_event, null) as waiting,
    case
      when a.query ~* '^autovacuum.*to prevent wraparound' then 'wraparound'
      when a.query ~* '^vacuum' then 'user'
      else 'auto'
    end as mode,
    p.phase,
    pg_size_pretty(pg_total_relation_size(relid)) as total_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_indexes_size(relid)) as table_size,
    pg_size_pretty(pg_indexes_size(relid)) as index_size,
    pg_size_pretty(p.heap_blks_scanned * current_setting('block_size')::int) as scanned,
    pg_size_pretty(p.heap_blks_vacuumed * current_setting('block_size')::int) as vacuumed,
    round(100.0 * p.heap_blks_scanned / p.heap_blks_total, 2) as scanned_pct,
    round(100.0 * p.heap_blks_vacuumed / p.heap_blks_total, 2) as vacuumed_pct,
    p.index_vacuum_count,
    round(100.0 * p.num_dead_tuples / p.max_dead_tuples, 2) as dead_pct,
    p.num_dead_tuples,
    p.max_dead_tuples
  from pg_stat_progress_vacuum p
  left join pg_stat_activity a using (pid)
  left join pg_class c on c.oid = p.relid
  left join pg_namespace n on n.oid = c.relnamespace
)
select
  pid as "PID",
  duration::interval(0)::text as "Duration",
  mode as "Mode",
  database || coalesce(
    e'\n' || coalesce(nullif(schema_name, 'public') || '.', '') || table_name || coalesce(' [' || tblspace || ']', ''),
    ''
  ) as "DB & Table",
  table_size as "Table",
  index_size as "Indexes",
  waiting as "Wait",
  phase as "Phase",
  scanned || ' (' || scanned_pct || '%)' || e' scanned\n'
    || vacuumed || ' (' || vacuumed_pct || '%) vacuumed' as "Heap Vacuuming",
  index_vacuum_count || ' completed cycles,'
    || e'\n'
    || case
      when num_dead_tuples > 10^12 then round(num_dead_tuples::numeric / 10^12::numeric, 0)::text || 'T'
      when num_dead_tuples > 10^9 then round(num_dead_tuples::numeric / 10^9::numeric, 0)::text || 'B'
      when num_dead_tuples > 10^6 then round(num_dead_tuples::numeric / 10^6::numeric, 0)::text || 'M'
      when num_dead_tuples > 10^3 then round(num_dead_tuples::numeric / 10^3::numeric, 0)::text || 'k'
      else num_dead_tuples::text
    end
    || ' (' || dead_pct || e'%) dead tuples\nof max ~'
    || case
      when max_dead_tuples > 10^12 then round(max_dead_tuples::numeric / 10^12::numeric, 0)::text || 'T'
      when max_dead_tuples > 10^9 then round(max_dead_tuples::numeric / 10^9::numeric, 0)::text || 'B'
      when max_dead_tuples > 10^6 then round(max_dead_tuples::numeric / 10^6::numeric, 0)::text || 'M'
      when max_dead_tuples > 10^3 then round(max_dead_tuples::numeric / 10^3::numeric, 0)::text || 'k'
      else max_dead_tuples::text
    end
    || ' collected now' as "Index Vacuuming"
from data
order by duration desc;

--Vacuum: VACUUM progress and autovacuum queue

-- Based on: https://gitlab.com/snippets/1889668

with table_opts as (
  select
    pg_class.oid,
    relname,
    nspname,
    array_to_string(reloptions, '') as relopts
  from pg_class
  join pg_namespace ns on relnamespace = ns.oid
), vacuum_settings as (
  select
    oid,
    relname,
    nspname,
    case
      when relopts like '%autovacuum_vacuum_threshold%' then regexp_replace(relopts, '.*autovacuum_vacuum_threshold=([0-9.]+).*', E'\\1')::int8
      else current_setting('autovacuum_vacuum_threshold')::int8
    end as autovacuum_vacuum_threshold,
    case
      when relopts like '%autovacuum_vacuum_scale_factor%' then regexp_replace(relopts, '.*autovacuum_vacuum_scale_factor=([0-9.]+).*', E'\\1')::numeric
      else current_setting('autovacuum_vacuum_scale_factor')::numeric
    end as autovacuum_vacuum_scale_factor,
    case when relopts ~ 'autovacuum_enabled=(false|off)' then false else true end as autovacuum_enabled
  from table_opts
), p as (
  select *
  from pg_stat_progress_vacuum
)
select
  --vacuum_settings.oid,
  coalesce(
    coalesce(nullif(vacuum_settings.nspname, 'public') || '.', '') || vacuum_settings.relname, -- current DB
    format('[something in "%I"]', p.datname)
  ) as table,
  round((100 * psat.n_dead_tup::numeric / nullif(pg_class.reltuples, 0))::numeric, 2) as dead_tup_pct,
  pg_class.reltuples::numeric,
  psat.n_dead_tup,
  'vt: ' || vacuum_settings.autovacuum_vacuum_threshold
    || ', vsf: ' || vacuum_settings.autovacuum_vacuum_scale_factor
    || case when not autovacuum_enabled then ', DISABLED' else ', enabled' end as "effective_settings",
  case
    when last_autovacuum > coalesce(last_vacuum, '0001-01-01') then left(last_autovacuum::text, 19) || ' (auto)'
    when last_vacuum is not null then left(last_vacuum::text, 19) || ' (manual)'
    else null
  end as "last_vacuumed",
  coalesce(p.phase, '~~~ in queue ~~~') as status,
  p.pid as pid,
  case
    when a.query ~ '^autovacuum.*to prevent wraparound' then 'wraparound'
    when a.query ~ '^vacuum' then 'user'
    when a.pid is null then null
    else 'regular'
  end as mode,
  case when a.pid is null then null else coalesce(wait_event_type ||'.'|| wait_event, 'f') end as waiting,
  round(100.0 * p.heap_blks_scanned / nullif(p.heap_blks_total, 0), 1) AS scanned_pct,
  round(100.0 * p.heap_blks_vacuumed / nullif(p.heap_blks_total, 0), 1) AS vacuumed_pct,
  p.index_vacuum_count,
  case
    when psat.relid is not null and p.relid is not null then
      (select count(*) from pg_index where indrelid = psat.relid)
    else null
  end as index_count
from pg_stat_all_tables psat
join pg_class on psat.relid = pg_class.oid
join vacuum_settings on pg_class.oid = vacuum_settings.oid
full outer join p on p.relid = psat.relid and p.datname = current_database()
left join pg_stat_activity a using (pid)
where
  psat.relid is null
  or autovacuum_vacuum_threshold + (autovacuum_vacuum_scale_factor::numeric * pg_class.reltuples) < psat.n_dead_tup;

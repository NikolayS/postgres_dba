with recursive constants as (
  select 8 as chunk_size
), columns as (
  select
    table_schema,
    table_name,
    ordinal_position,
    column_name,
    udt_name,
    typalign,
    case typalign -- see https://www.postgresql.org/docs/current/static/catalog-pg-type.html
      when 'c' then 0
      when 's' then 2
      when 'i' then 4
      when 'd' then 8
      else null
    end as shift
  from information_schema.columns
  join pg_type on udt_name = typname
  --where table_name = 'bloattest'
  --order by ordinal_position
), analyze_alignment as (
  select
    table_schema,
    table_name,
    0 as analyzed,
    (select chunk_size from constants) as left_in_chunk,
    '{}'::text[] as padded_columns,
    '{}'::int[] as pads,
    (select max(ordinal_position) from columns c where c.table_name = tables.table_name and c.table_schema = tables.table_schema) as col_cnt
  from information_schema.tables
  where table_schema not in ('pg_catalog', 'information_schema')
  union all
  select
    table_schema,
    table_name,
    analyzed + 1,
    case when cur_left_in_chunk <= 0 then chunk_size else cur_left_in_chunk end,
    case when cur_left_in_chunk < 0 then padded_columns || array[prev_column_name] else padded_columns end,
    case when cur_left_in_chunk < 0 then pads || array[remains_in_chunk] else pads end,
    col_cnt
  from analyze_alignment a, constants, lateral (
    select
      left_in_chunk - (
        select coalesce(shift, 0) /*todo*/
        from columns c
        where ordinal_position = analyzed + 1 and c.table_name = a.table_name and c.table_schema = a.table_schema
      ) as cur_left_in_chunk,
      (
        select column_name::text
        from columns c
        where ordinal_position = analyzed and c.table_name = a.table_name and c.table_schema = a.table_schema
      ) as prev_column_name,
      (
        select (chunk_size - a.left_in_chunk)::int from constants
      ) as remains_in_chunk
  ) as ext
  where
    analyzed <= col_cnt and analyzed < 100
), result_pre as (
  select distinct on (table_schema, table_name)
    table_schema as schema_name,
    table_name,
    padded_columns,
    pads,
    (select sum(p) from unnest(pads) _(p)) as padding_sum,
    n_live_tup,
    n_dead_tup,
    c.oid as oid,
    pg_total_relation_size(c.oid) - pg_indexes_size(c.oid) - coalesce(pg_total_relation_size(reltoastrelid), 0) as table_bytes
  from analyze_alignment
  join pg_namespace n on n.nspname = table_schema
  join pg_class c on n.oid = c.relnamespace and c.relname = table_name
  join pg_stat_user_tables s on s.schemaname = table_schema and s.relname = table_name
  order by table_schema, table_name, analyzed desc
), result as (
  select
    *,
    padding_sum * (n_live_tup + n_dead_tup) as padding_total_est,
    case 
      when table_bytes > 0 then round(100 * padding_sum::numeric * (n_live_tup + n_dead_tup)::numeric / table_bytes, 2)
      else 0
    end as wasted_percent
  from result_pre
)
select
  coalesce(nullif(schema_name, 'public') || '.', '') || table_name as "Table",
  pg_size_pretty(table_bytes) "Table Size",
  padding_sum as "Bytes Wasted in a Row",
  case
    when padding_total_est > 0 then '~' || pg_size_pretty(padding_total_est) || ' (' || wasted_percent::text || '%)'
    else ''
  end as "Wasted"
from result
order by table_bytes desc
;

--Alignmet Padding Analysis: how many bytes can be saved if columns are ordered better?

-- TODO: not-yet-analyzed tables – show a warning (cannot get n_live_tup -> cannot get total bytes)
-- TODO: NULLs!!
with recursive constants as (
  select 8 as chunk_size
), columns as (
  select
    true as is_orig,
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
    end as shift,
    case typalign
      when 's' then 1
      when 'i' then 2
      when 'd' then 3
      else 4
    end as alt_order_group
  from information_schema.columns
  join pg_type on udt_name = typname
  where table_schema not in ('information_schema', 'pg_catalog')
), alt_columns as (
  select
    false as is_orig,
    table_schema,
    table_name,
    row_number() over (partition by table_schema, table_name order by alt_order_group) as ordinal_position,
    column_name,
    udt_name,
    typalign,
    shift,
    alt_order_group
  from columns
), combined_columns as (
  select * from columns union all select * from alt_columns
), analyze_alignment as (
  select
    is_orig,
    table_schema,
    table_name,
    0 as analyzed,
    (select chunk_size from constants) as left_in_chunk,
    '{}'::text[] as padded_columns,
    '{}'::int[] as pads,
    (select max(ordinal_position) from columns c where c.table_name = _.table_name and c.table_schema = _.table_schema) as col_cnt,
    array_agg(_.column_name::text) as cols,
    array_agg(_.udt_name::text) as types
  from 
    combined_columns _
  group by is_orig, table_schema, table_name
  union all
  select
    is_orig,
    table_schema,
    table_name,
    analyzed + 1,
    case when cur_left_in_chunk <= 0 then chunk_size else cur_left_in_chunk end,
    case when cur_left_in_chunk < 0 then padded_columns || array[prev_column_name] else padded_columns end,
    case when cur_left_in_chunk < 0 then pads || array[remains_in_chunk] else pads end,
    col_cnt,  
    cols,
    types
  from analyze_alignment a, constants, lateral (
    select
      left_in_chunk - coalesce(
        (
          select coalesce(shift, 0) /*todo*/
          from combined_columns c  -- <<<<!!!!!!!
          where ordinal_position = analyzed + 1 and c.is_orig = a.is_orig and c.table_name = a.table_name and c.table_schema = a.table_schema
        ),
        0
      ) as cur_left_in_chunk,
      (
        select column_name::text
        from combined_columns c
        where ordinal_position = analyzed and c.is_orig = a.is_orig and c.table_name = a.table_name and c.table_schema = a.table_schema
      ) as prev_column_name,
      (
        select (chunk_size - a.left_in_chunk)::int from constants
      ) as remains_in_chunk
  ) as ext
  where
    analyzed <= col_cnt and analyzed < 1000/*sanity*/
), result_pre as (
  select distinct on (is_orig, table_schema, table_name)
    is_orig ,
    table_schema as schema_name,
    table_name,
    padded_columns,
    pads,
    (select sum(p) from unnest(pads) _(p)) + (
      select left_in_chunk
      from analyze_alignment a2
      where a2.table_schema = a1.table_schema and a2.table_name = a1.table_name
      order by analyzed desc
      limit 1
    ) as padding_sum,
    n_live_tup,
    n_dead_tup,
    c.oid as oid,
    pg_total_relation_size(c.oid) - pg_indexes_size(c.oid) - coalesce(pg_total_relation_size(reltoastrelid), 0) as table_bytes,
    cols,
    types
  from analyze_alignment a1
  join pg_namespace n on n.nspname = table_schema
  join pg_class c on n.oid = c.relnamespace and c.relname = table_name
  join pg_stat_user_tables s on s.schemaname = table_schema and s.relname = table_name
  order by is_orig, table_schema, table_name, analyzed desc
), result_both as (
  select
    *,
    padding_sum * (n_live_tup + n_dead_tup) as padding_total_est
  from result_pre
), result as (
  select
    r1.schema_name,
    r1.table_name,
    r1.table_bytes,
    r1.n_live_tup,
    r1.n_dead_tup,
    r1.padding_total_est - coalesce(r2.padding_total_est, 0) as padding_total_est,
    r1.padding_sum - coalesce(r2.padding_sum, 0) as padding_sum,
    case
      when r1.table_bytes > 0 then
        round(100 * (r1.padding_sum - coalesce(r2.padding_sum, 0))::numeric * (r1.n_live_tup + r1.n_dead_tup)::numeric / r1.table_bytes, 2)
      else 0
    end as wasted_percent
  from result_both r1
  join result_both r2 on r1.is_orig and not r2.is_orig and r1.schema_name = r2.schema_name and r1.table_name = r2.table_name
)
select
  coalesce(nullif(schema_name, 'public') || '.', '') || table_name as "Table",
  pg_size_pretty(table_bytes) "Table Size",
  padding_sum as "Bytes Wasted in a Row",
  case
    when padding_total_est > 0 then '~' || pg_size_pretty(padding_total_est) || ' (' || wasted_percent::text || '%)'
    else ''
  end as "Wasted",
  padding_total_est,
  n_live_tup,
  n_dead_tup
\if :postgres_dba_wide
  ,
  *
\endif
from result r1
order by table_bytes desc
;



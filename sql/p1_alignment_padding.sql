--[EXP] Alignment padding: how many bytes can be saved if columns are reordered?

-- TODO: not-yet-analyzed tables – show a warning (cannot get n_live_tup -> cannot get total bytes)
-- TODO: NULLs
-- TODO: simplify, cleanup
-- TODO: chunk_size 4 or 8
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
    typlen,
    case typalign -- see https://www.postgresql.org/docs/current/static/catalog-pg-type.html
      when 'c' then
        case when typlen > 0 then typlen % chunk_size else 0 end
      when 's' then 2
      when 'i' then 4
      when 'd' then 8
      else null
    end as _shift,
    case typalign
      when 's' then 1
      when 'i' then 2
      when 'd' then 3
      when 'c' then
        case when typlen > 0 then typlen % chunk_size else 9 end
      else 9
    end as alt_order_group,
    character_maximum_length
  from information_schema.columns
  join constants on true
  join pg_type on udt_name = typname
  where table_schema not in ('information_schema', 'pg_catalog')
), alt_columns as (
  select
    false as is_orig,
    table_schema,
    table_name,
    row_number() over (partition by table_schema, table_name order by alt_order_group, column_name) as ordinal_position,
    column_name,
    udt_name,
    typalign,
    typlen,
    _shift,
    alt_order_group,
    character_maximum_length
  from columns
), combined_columns as (
  select *, coalesce(character_maximum_length, _shift) as shift
  from columns
  union all
  select *, coalesce(character_maximum_length, _shift) as shift
  from alt_columns
), analyze_alignment as (
  select
    is_orig,
    table_schema,
    table_name,
    0 as analyzed,
    (select chunk_size from constants) as left_in_chunk,
    '{}'::text[] collate "C" as padded_columns,
    '{}'::int[] as pads,
    (select max(ordinal_position) from columns c where c.table_name = _.table_name and c.table_schema = _.table_schema) as col_cnt,
    array_agg(_.column_name::text order by ordinal_position) as cols,
    array_agg(_.udt_name::text order by ordinal_position) as types,
    array_agg(shift order by ordinal_position) as shifts,
    null::int as curleft,
    null::text collate "C" as prev_column_name,
    false as has_varlena
  from
    combined_columns _
  group by is_orig, table_schema, table_name
  union all
  select
    is_orig,
    table_schema,
    table_name,
    analyzed + 1,
    cur_left_in_chunk,
    case when padding_occured > 0 then padded_columns || array[prev_column_name] else padded_columns end,
    case when padding_occured > 0 then pads || array[padding_occured] else pads end,
    col_cnt,
    cols,
    types,
    shifts,
    cur_left_in_chunk,
    ext.column_name as prev_column_name,
    a.has_varlena or (ext.typlen = -1) -- see https://www.postgresql.org/docs/current/static/catalog-pg-type.html
  from analyze_alignment a, constants, lateral (
    select
      shift,
      case when left_in_chunk < shift then left_in_chunk else 0 end as padding_occured,
      case when left_in_chunk < shift then chunk_size - shift % chunk_size else left_in_chunk - shift end as cur_left_in_chunk,
      column_name,
      typlen
    from combined_columns c, constants
    where
      ordinal_position = a.analyzed + 1
      and c.is_orig = a.is_orig
      and c.table_name = a.table_name
      and c.table_schema = a.table_schema
  ) as ext
  where
    analyzed < col_cnt and analyzed < 1000/*sanity*/
), result_pre as (
  select distinct on (is_orig, table_schema, table_name)
    is_orig ,
    table_schema as schema_name,
    table_name,
    padded_columns,
    case when curleft % chunk_size > 0 then pads || array[curleft] else pads end as pads,
    curleft,
    coalesce((select sum(p) from unnest(pads) _(p)), 0) + (chunk_size + a1.curleft) % chunk_size as padding_sum,
    n_live_tup,
    n_dead_tup,
    c.oid as oid,
    pg_total_relation_size(c.oid) - pg_indexes_size(c.oid) - coalesce(pg_total_relation_size(reltoastrelid), 0) as table_bytes,
    cols,
    types,
    shifts,
    analyzed,
    a1.has_varlena
  from analyze_alignment a1
  join pg_namespace n on n.nspname = table_schema
  join pg_class c on n.oid = c.relnamespace and c.relname = table_name
  join pg_stat_user_tables s on s.schemaname = table_schema and s.relname = table_name
  join constants on true
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
    r1.padding_sum as r1_padding_sum,
    r1.padding_total_est as r1_padding_total_est,
    r2.padding_sum as r2_padding_sum,
    r2.padding_total_est as r2_padding_total_est,
    r1.cols,
    r1.types,
    r1.shifts,
    r2.cols as alt_cols,
    r2.types as alt_types,
    r2.shifts as alt_shits,
    r1.pads,
    r1.curleft,
    r2.pads as alt_pads,
    r2.curleft as alt_curleft,
    r1.padded_columns,
    r1.analyzed,
    r1.has_varlena,
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
  case when has_varlena then 'Includes VARLENA' else null end as "Comment",
  case
    when padding_total_est > 0 then '~' || pg_size_pretty(padding_total_est) || ' (' || wasted_percent::text || '%)'
    else ''
  end as "Wasted *",
  case
    when padding_total_est > 0 then (
      with cols1(c) as (
        select array_to_string(array_agg(elem::text), ', ')
        from (select * from unnest(alt_cols) with ordinality as __(elem, i)) _
        group by (i - 1) / 3
        order by (i - 1) / 3
      )
      select array_to_string(array_agg(c), e'\n') from cols1
    )
    else null
  end as "Suggested Columns Reorder"
  --case when padding_total_est > 0 then array_to_string(alt_cols, ', ') else null end as "Suggested Columns Reorder"
from result r1
order by table_bytes desc
;



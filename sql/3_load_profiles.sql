--Load Profile

with data as (
  select
    s.relname as table_name,
    s.schemaname as schema_name,
    (select spcname from pg_tablespace where oid = reltablespace) as tblspace,
    *,
    case when n_tup_upd = 0 then null else n_tup_hot_upd::numeric / n_tup_upd end as upd_hot_ratio,
    seq_tup_read + coalesce(idx_tup_fetch, 0) - n_tup_del - n_tup_upd as tuples_selected,
    seq_tup_read + coalesce(idx_tup_fetch, 0) + n_tup_ins as processed_tup_total -- we don't add _del and _upd here (already counted via seq_ & idx_)
  from pg_stat_user_tables s
  join pg_class c on c.oid = relid
), data2 as (
  select
    0 as ord,
    '*** TOTAL ***' as table_name,
    null as schema_name,
    null as tblspace,
    sum(seq_tup_read) as seq_tup_read,
    sum(idx_tup_fetch) as idx_tup_fetch,
    sum(tuples_selected) as tuples_selected,
    sum(n_tup_ins) as n_tup_ins,
    sum(n_tup_del) as n_tup_del,
    sum(n_tup_upd) as n_tup_upd,
    sum(n_tup_hot_upd) as n_tup_hot_upd,
    avg(upd_hot_ratio) as upd_hot_ratio,
    sum(processed_tup_total) as processed_tup_total
  from data
  union all
  select
    1 as ord,
    '    tablespace: [' || coalesce(tblspace, 'pg_default') || ']' as table_name,
    null as schema_name,
    null, -- we don't need to pass real tblspace value for this aggregated record further
    sum(seq_tup_read) as seq_tup_read,
    sum(idx_tup_fetch) as idx_tup_fetch,
    sum(tuples_selected) as tuples_selected,
    sum(n_tup_ins) as n_tup_ins,
    sum(n_tup_del) as n_tup_del,
    sum(n_tup_upd) as n_tup_upd,
    sum(n_tup_hot_upd) as n_tup_hot_upd,
    avg(upd_hot_ratio) as upd_hot_ratio,
    sum(processed_tup_total) as processed_tup_total
  from data
  where (select count(distinct coalesce(tblspace, 'pg_default')) from data) > 1 -- don't show this part if there are no custom tablespaces
  group by tblspace
  union all
  select 3, null, null, null, null, null, null, null, null, null, null, null, null
  union all
  select 4, table_name, schema_name, tblspace, seq_tup_read, idx_tup_fetch, tuples_selected, n_tup_ins, n_tup_del, n_tup_upd, n_tup_hot_upd, upd_hot_ratio, processed_tup_total
  from data
)
select
  coalesce(nullif(schema_name, 'public') || '.', '') || table_name || coalesce(' [' || tblspace || ']', '') as "Table",
  (
    with ops as (
      select * from data where data.schema_name is not distinct from data2.schema_name and data.table_name = data2.table_name
    ), ops_ratios(opname, ratio) as (
      select
        'select',
        case when processed_tup_total > 0 then tuples_selected::numeric / processed_tup_total else 0 end
      from ops
      union all
      select
        'insert',
        case when processed_tup_total > 0 then n_tup_ins::numeric / processed_tup_total else 0 end
      from ops
      union all
      select
        'delete',
        case when processed_tup_total > 0 then n_tup_del::numeric / processed_tup_total else 0 end
      from ops
      union all
      select
        'update',
        case when processed_tup_total > 0 then n_tup_upd::numeric / processed_tup_total else 0 end
      from ops
    )
    select upper(opname) || ' ~' || round(100 * ratio, 2)::text as zz
    from ops_ratios
    order by ratio desc
    limit 1
  ) as "Load Type",
  processed_tup_total as "Total (S+I+D+U)",
  tuples_selected as "SELECTed",
  n_tup_ins as "INSERTed",
  n_tup_del as "DELETEd",
  n_tup_upd as "UPDATEd",
  round(100 * upd_hot_ratio, 2) as "HOT-updated, %"
from data2
order by ord, processed_tup_total desc;

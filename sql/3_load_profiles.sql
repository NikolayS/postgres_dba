--Load Profiles for Tables

with data as (
  select
    s.relname as table_name,
    s.schemaname as schema_name,
    (select spcname from pg_tablespace where oid = reltablespace) as tblspace,
    *,
    case when n_tup_upd = 0 then null else n_tup_hot_upd::numeric / n_tup_upd end as upd_hot_ratio,
    seq_scan + coalesce(idx_scan, 0) + n_tup_ins + n_tup_del + n_tup_upd as ops_total
  from pg_stat_user_tables s
  join pg_class c on c.oid = relid
), data2 as (
  select
    0 as ord,
    '*** TOTAL ***' as table_name,
    null as schema_name,
    null as tblspace,
    sum(seq_scan) as seq_scan,
    sum(idx_scan) as idx_scan,
    sum(n_tup_ins) as n_tup_ins,
    sum(n_tup_del) as n_tup_del,
    sum(n_tup_upd) as n_tup_upd,
    sum(n_tup_hot_upd) as n_tup_hot_upd,
    avg(upd_hot_ratio) as upd_hot_ratio,
    sum(ops_total) as ops_total
  from data
  union all
  select
    1 as ord,
    '    tablespace: [' || coalesce(tblspace, 'pg_default') || ']' as table_name,
    null as schema_name,
    null, -- we don't need to pass real tblspace value for this aggregated record further
    sum(seq_scan) as seq_scan,
    sum(idx_scan) as idx_scan,
    sum(n_tup_ins) as n_tup_ins,
    sum(n_tup_del) as n_tup_del,
    sum(n_tup_upd) as n_tup_upd,
    sum(n_tup_hot_upd) as n_tup_hot_upd,
    avg(upd_hot_ratio) as upd_hot_ratio,
    sum(ops_total) as ops_total
  from data
  where (select count(1) from pg_tablespace where spcname <> 'pg_global') > 1 -- don't show this part if there are no custom tablespaces
  group by tblspace
  union all
  select 3, null, null, null, null, null, null, null, null, null, null, null
  union all
  select 4, table_name, schema_name, tblspace, seq_scan, idx_scan, n_tup_ins, n_tup_del, n_tup_upd, n_tup_hot_upd, upd_hot_ratio, ops_total
  from data
)
select
  coalesce(nullif(schema_name, 'public') || '.', '') || table_name || coalesce(' [' || tblspace || ']', '') as "Table",
  /*(
    with op_ratios as (
      select
        (seq_scan + coalesce(idx_scan, 0))::numeric / ops_total as reads_ratio,
        n_tup_ins::numeric / ops_total as inserts_ratio,
        n_tup_del::numeric / ops_total as deletes_ratio,
        n_tup_upd::numeric / ops_total as updates_ratio
      from data where
    )
    select
  )*/
  ops_total as "Total (S+I+D+U)",
  seq_scan + coalesce(idx_scan, 0) as "SELECTs",
  n_tup_ins as "INSERTs",
  n_tup_del as "DELETEs",
  n_tup_upd as "UPDATEs",
  round(100 * upd_hot_ratio, 2) as "HOT Updates, %"
from data2
order by ord, ops_total desc;

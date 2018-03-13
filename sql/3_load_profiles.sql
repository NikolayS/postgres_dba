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
from data
order by ops_total desc;

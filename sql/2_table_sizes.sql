--Tables: table/index/TOAST size, number of rows

with data as (
  select
    c.oid,
    (select spcname from pg_tablespace where oid = reltablespace) as tblspace,
    nspname as schema_name,
    relname as table_name,
    c.reltuples as row_estimate,
    pg_total_relation_size(c.oid) as total_bytes,
    pg_indexes_size(c.oid) as index_bytes,
    pg_total_relation_size(reltoastrelid) as toast_bytes,
    pg_total_relation_size(c.oid) - pg_indexes_size(c.oid) - coalesce(pg_total_relation_size(reltoastrelid), 0) as table_bytes
  from pg_class c
  left join pg_namespace n on n.oid = c.relnamespace
  where relkind = 'r' and nspname <> 'pg_catalog'
), data2 as (
  select
    null::oid as oid,
    null as tblspace,
    null as schema_name,
    '*** TOTAL ***' as table_name,
    sum(row_estimate) as row_estimate,
    sum(total_bytes) as total_bytes,
    sum(index_bytes) as index_bytes,
    sum(toast_bytes) as toast_bytes,
    sum(table_bytes) as table_bytes
  from data
  union all
  select
    null::oid as oid,
    null,
    null as schema_name,
    '    tablespace: [' || coalesce(tblspace, 'pg_default') || ']' as table_name,
    sum(row_estimate) as row_estimate,
    sum(total_bytes) as total_bytes,
    sum(index_bytes) as index_bytes,
    sum(toast_bytes) as toast_bytes,
    sum(table_bytes) as table_bytes
  from data
  where (select count(distinct coalesce(tblspace, 'pg_default')) from data) > 1 -- don't show this part if there are no custom tablespaces
  group by tblspace
  union all
  select null::oid, null, null, null, null, null, null, null, null
  union all
  select * from data
)
select
  coalesce(nullif(schema_name, 'public') || '.', '') || table_name || coalesce(' [' || tblspace || ']', '') as "Table",
  '~' || case
    when row_estimate > 10^12 then round(row_estimate::numeric / 10^12::numeric, 0)::text || 'T'
    when row_estimate > 10^9 then round(row_estimate::numeric / 10^9::numeric, 0)::text || 'B'
    when row_estimate > 10^6 then round(row_estimate::numeric / 10^6::numeric, 0)::text || 'M'
    when row_estimate > 10^3 then round(row_estimate::numeric / 10^3::numeric, 0)::text || 'k'
    else row_estimate::text
  end as "Rows",
  pg_size_pretty(total_bytes) || ' (' || round(
    100 * total_bytes::numeric / nullif(sum(total_bytes) over (partition by (schema_name is null), left(table_name, 3) = '***'), 0),
    2
  )::text || '%)' as "Total Size",
  pg_size_pretty(table_bytes) || ' (' || round(
    100 * table_bytes::numeric / nullif(sum(table_bytes) over (partition by (schema_name is null), left(table_name, 3) = '***'), 0),
    2
  )::text || '%)' as "Table Size",
  pg_size_pretty(index_bytes) || ' (' || round(
    100 * index_bytes::numeric / nullif(sum(index_bytes) over (partition by (schema_name is null), left(table_name, 3) = '***'), 0),
    2
  )::text || '%)' as "Index(es) Size",
  pg_size_pretty(toast_bytes) || ' (' || round(
    100 * toast_bytes::numeric / nullif(sum(toast_bytes) over (partition by (schema_name is null), left(table_name, 3) = '***'), 0),
    2
  )::text || '%)' as "TOAST Size"
from data2
where schema_name is distinct from 'information_schema'
order by oid is null desc, total_bytes desc nulls last;

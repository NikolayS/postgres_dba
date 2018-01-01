--General Table Size Information

with data as (
  select
    c.oid,
    nspname as schema_name,
    relname as table_name,
    c.reltuples as row_estimate,
    pg_total_relation_size(c.oid) as total_bytes,
    pg_indexes_size(c.oid) as index_bytes,
    pg_total_relation_size(reltoastrelid) as toast_bytes,
    pg_total_relation_size(c.oid) - pg_indexes_size(c.oid) - coalesce(pg_total_relation_size(reltoastrelid), 0) as table_bytes
  from pg_class c
  left join pg_namespace n on n.oid = c.relnamespace
  where relkind = 'r'
)
select
  coalesce(nullif(schema_name, 'public') || '.', '') || table_name as table,
  '~' || case
    when row_estimate > 10^12 then round(row_estimate::numeric / 10^12::numeric, 0)::text || 'T'
    when row_estimate > 10^9 then round(row_estimate::numeric / 10^9::numeric, 0)::text || 'B'
    when row_estimate > 10^6 then round(row_estimate::numeric / 10^6::numeric, 0)::text || 'M'
    when row_estimate > 10^3 then round(row_estimate::numeric / 10^3::numeric, 0)::text || 'k'
    else row_estimate::text
  end as rows,
  pg_size_pretty(total_bytes) || ' (' || round(100 * total_bytes::numeric / sum(total_bytes) over (), 2)::text || '%)' as "total (% of all)",
  pg_size_pretty(table_bytes) || ' (' || round(100 * table_bytes::numeric / sum(table_bytes) over (), 2)::text || '%)' as "table (% of all tables)",
  pg_size_pretty(index_bytes) || ' (' || round(100 * index_bytes::numeric / sum(index_bytes) over (), 2)::text || '%)' as "index (% of all indexes)",
  pg_size_pretty(toast_bytes) || ' (' || round(100 * toast_bytes::numeric / sum(toast_bytes) over (), 2)::text || '%)' as "toast (% of all toast data)",
  row_estimate,
  total_bytes,
  table_bytes,
  index_bytes,
  toast_bytes,
  schema_name,
  table_name,
  oid
from data
where schema_name <> 'information_schema'
order by total_bytes desc nulls last;

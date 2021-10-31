--B-tree indexes bloat (requires pgstattuple; expensive)

--https://github.com/dataegret/pg-utils/tree/master/sql
--pgstattuple extension required
--WARNING: without index name/mask query will read all available indexes which could cause I/O spikes
with data as (
  select
    schemaname as schema_name,
    p.relname as table_name,
    (select spcname from pg_tablespace where oid = c_table.reltablespace) as table_tblspace,
    (select spcname from pg_tablespace where oid = c.reltablespace) as index_tblspace,
    indexrelname as index_name,
    (
      select (case when avg_leaf_density = 'NaN' then 0
        else greatest(ceil(index_size * (1 - avg_leaf_density / (coalesce((SELECT (regexp_matches(c.reloptions::text, E'.*fillfactor=(\\d+).*'))[1]),'90')::real)))::bigint, 0) end)
      from pgstatindex(
        case when p.indexrelid::regclass::text ~ '\.' then p.indexrelid::regclass::text else schemaname || '.' || p.indexrelid::regclass::text end
      )
    ) as free_space,
    pg_relation_size(p.indexrelid) as index_size,
    pg_relation_size(p.relid) as table_size,
    idx_scan
  from pg_stat_user_indexes p
  join pg_class c on p.indexrelid = c.oid
  join pg_class c_table on p.relid = c_table.oid
  where
    pg_get_indexdef(p.indexrelid) like '%USING btree%'
    --put your index name/mask here
    and indexrelname ~ ''
)
select
  coalesce(nullif(schema_name, 'public') || '.', '') || table_name || coalesce(' [' || table_tblspace || ']', '') as "Table",
  coalesce(nullif(schema_name, 'public') || '.', '') || index_name || coalesce(' [' || index_tblspace || ']', '') as "Index",
  pg_size_pretty(table_size) as "Table size",
  pg_size_pretty(index_size) as "Index size",
  idx_scan as "Index Scans",
  round((free_space*100/index_size)::numeric, 1) as "Wasted, %",
  pg_size_pretty(free_space) as "Wasted"
from data
order by free_space desc;


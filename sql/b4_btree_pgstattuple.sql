--B-tree Indexes Bloat, more precise (requires pgstattuple extension; expensive)

--https://github.com/dataegret/pg-utils/tree/master/sql
--pgstattuple extension required
--WARNING: without index name/mask query will read all available indexes which could cause I/O spikes
with indexes as (
    select * from pg_stat_user_indexes
)
select schemaname,
table_name,
pg_size_pretty(table_size) as table_size,
index_name,
pg_size_pretty(index_size) as index_size,
idx_scan as index_scans,
round((free_space*100/index_size)::numeric, 1) as waste_percent,
pg_size_pretty(free_space) as waste
from (
    select schemaname, p.relname as table_name, indexrelname as index_name,
    (select (case when avg_leaf_density = 'NaN' then 0 
        else greatest(ceil(index_size * (1 - avg_leaf_density / (coalesce((SELECT (regexp_matches(reloptions::text, E'.*fillfactor=(\\d+).*'))[1]),'90')::real)))::bigint, 0) end)
        from pgstatindex(schemaname || '.' || p.indexrelid::regclass::text)
    ) as free_space,
    pg_relation_size(p.indexrelid) as index_size,
    pg_relation_size(p.relid) as table_size,
    idx_scan
    from indexes p
    join pg_class c on p.indexrelid = c.oid
    where pg_get_indexdef(p.indexrelid) like '%USING btree%' and
    --put your index name/mask here
    indexrelname ~ ''
) t
order by free_space desc;


-- List of invalid indexes

-- Use it to see invalid indexes list

-- This query doesn't need any additional extensions to be installed
-- (except plpgsql), and doesn't create anything (like views or smth)
-- -- so feel free to use it in your clouds (Heroku, AWS RDS, etc)

-- (Keep in mind, that on replicas, the whole picture of index usage
-- is usually very different from master).

select 
    coalesce(nullif(pn.nspname, 'public') || '.', '') || pct.relname as "relation_name",
    pci.relname as index_name,
    pn.nspname as schema_name,
    pct.relname as table_name
from pg_index pidx
join pg_class as pci on pci.oid = pidx.indexrelid
join pg_class as pct on pct.oid = pidx.indrelid
left join pg_namespace pn on pn.oid = pct.relnamespace
where pidx.indisvalid = false;
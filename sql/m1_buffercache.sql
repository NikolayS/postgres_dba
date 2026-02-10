-- Buffer cache contents (requires pg_buffercache; expensive on large shared_buffers)

with buf as (
  select
    c.oid as relid,
    n.nspname as schema_name,
    c.relname,
    case c.relkind
      when 'r' then 'table'
      when 'i' then 'index'
      when 't' then 'TOAST table'
      when 'm' then 'materialized view'
      when 'S' then 'sequence'
      else c.relkind::text
    end as object_type,
    count(*) as buffers,
    count(*) filter (where b.isdirty) as dirty_buffers,
    round(
      100.0 * count(*) / (
        select count(*)
        from pg_buffercache
        where reldatabase = (select oid from pg_database where datname = current_database())
          and relfilenode is not null
      ),
      1
    ) as pct_of_cache,
    round(
      100.0 * count(*) / greatest(
        ceil(pg_relation_size(c.oid)::numeric / current_setting('block_size')::numeric),
        1
      ),
      1
    ) as pct_of_rel,
    pg_size_pretty(count(*) * current_setting('block_size')::int) as cached_size,
    pg_size_pretty(pg_relation_size(c.oid)) as rel_size
  from pg_buffercache as b
  join pg_class as c
    on c.oid = (
      select pg_filenode_relation(b.reltablespace, b.relfilenode)
    )
  join pg_namespace as n on c.relnamespace = n.oid
  where b.reldatabase = (select oid from pg_database where datname = current_database())
    and b.relfilenode is not null
    and b.relforknumber = 0
    -- include all schemas (system catalogs are often the biggest cache consumers)
  group by c.oid, n.nspname, c.relname, c.relkind
)
select
  coalesce(nullif(schema_name, 'public') || '.', '') || relname as "Object",
  object_type as "Type",
  rel_size as "Size",
  cached_size as "Cached",
  pct_of_rel || '%' as "% of Rel",
  pct_of_cache || '%' as "% of Cache",
  buffers as "Buffers",
  dirty_buffers as "Dirty"
from buf
order by buffers desc
limit 50;

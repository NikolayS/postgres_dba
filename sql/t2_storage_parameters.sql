--Storage parameters (reloptions)

with rel_with_options as (
  select
    n.nspname as schema,
    c.relname as object_name,
    case c.relkind
      when 'r' then 'table'
      when 'i' then 'index'
      when 'm' then 'materialized view'
      when 'p' then 'partitioned table'
      when 'I' then 'partitioned index'
    end as object_type,
    pg_size_pretty(pg_relation_size(c.oid)) as size,
    pg_relation_size(c.oid) as size_bytes,
    c.reloptions,
    unnest(c.reloptions) as option,
    c.relispartition,
    (select n2.nspname || '.' || c2.relname
     from pg_inherits i
     join pg_class c2 on i.inhparent = c2.oid
     join pg_namespace n2 on c2.relnamespace = n2.oid
     where i.inhrelid = c.oid
    ) as parent_table
  from pg_class c
  join pg_namespace n on c.relnamespace = n.oid
  where c.reloptions is not null
    and n.nspname not in ('pg_catalog', 'information_schema')
    and c.relname != 'pg_stats'
)
select
  schema,
  object_name,
  object_type,
  case
    when relispartition then 'partition of ' || parent_table
    else null
  end as partition_info,
  size,
  option,
  case
    when option ~ 'autovacuum_enabled=(false|off)' and size_bytes > 10485760 then 'WARNING: autovacuum disabled on table > 10 MiB'
    when option ~ 'autovacuum_enabled=(false|off)' then 'autovacuum disabled'
    when option ~ 'fillfactor=([1-4][0-9]|50)' then 'low fillfactor (< 50%)'
    when option ~ 'autovacuum_vacuum_scale_factor=0\.0*[1-9]' then 'aggressive autovacuum (low scale factor)'
    else null
  end as note
from rel_with_options
order by
  parent_table nulls first,
  size_bytes desc,
  object_type,
  schema,
  object_name;
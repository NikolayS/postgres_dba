--Foreign keys with missing or bad indexes

--Created by PostgreSQL Experts https://github.com/pgexperts/pgx_scripts/blob/master/indexes/fk_no_index.sql

-- check for FKs where there is no matching index
-- on the referencing side
-- or a bad index

with fk_actions ( code, action ) as (
  values ('a', 'error'),
         ('r', 'restrict'),
         ('c', 'cascade'),
         ('n', 'set null'),
         ('d', 'set default')
), fk_list as (
  select
    pg_constraint.oid as fkoid, conrelid, confrelid as parentid,
    conname,
    relname,
    nspname,
    fk_actions_update.action as update_action,
    fk_actions_delete.action as delete_action,
    conkey as key_cols
  from pg_constraint
  join pg_class on conrelid = pg_class.oid
  join pg_namespace on pg_class.relnamespace = pg_namespace.oid
  join fk_actions as fk_actions_update on confupdtype = fk_actions_update.code
  join fk_actions as fk_actions_delete on confdeltype = fk_actions_delete.code
  where contype = 'f'
), fk_attributes as (
  select fkoid, conrelid, attname, attnum
  from fk_list
  join pg_attribute on conrelid = attrelid and attnum = any(key_cols)
  order by fkoid, attnum
), fk_cols_list as (
  select fkoid, array_agg(attname) as cols_list
  from fk_attributes
  group by fkoid
), index_list as (
  select
    indexrelid as indexid,
    pg_class.relname as indexname,
    indrelid,
    indkey,
    indpred is not null as has_predicate,
    pg_get_indexdef(indexrelid) as indexdef
  from pg_index
  join pg_class on indexrelid = pg_class.oid
  where indisvalid
), fk_index_match as (
  select
    fk_list.*,
    indexid,
    indexname,
    indkey::int[] as indexatts,
    has_predicate,
    indexdef,
    array_length(key_cols, 1) as fk_colcount,
    array_length(indkey,1) as index_colcount,
    round(pg_relation_size(conrelid)/(1024^2)::numeric) as table_mb,
    cols_list
  from fk_list
  join fk_cols_list using (fkoid)
  left join index_list on
    conrelid = indrelid
    and (indkey::int2[])[0:(array_length(key_cols,1) -1)] operator(pg_catalog.@>) key_cols

), fk_perfect_match as (
  select fkoid
  from fk_index_match
  where
    (index_colcount - 1) <= fk_colcount
    and not has_predicate
    and indexdef like '%USING btree%'
), fk_index_check as (
  select 'no index' as issue, *, 1 as issue_sort
  from fk_index_match
  where indexid is null
  union all
  select 'questionable index' as issue, *, 2
  from fk_index_match
  where
    indexid is not null
    and fkoid not in (select fkoid from fk_perfect_match)
), parent_table_stats as (
  select
    fkoid,
    tabstats.relname as parent_name,
    (n_tup_ins + n_tup_upd + n_tup_del + n_tup_hot_upd) as parent_writes,
    round(pg_relation_size(parentid)/(1024^2)::numeric) as parent_mb
  from pg_stat_user_tables as tabstats
  join fk_list on relid = parentid
), fk_table_stats as (
  select
    fkoid,
    (n_tup_ins + n_tup_upd + n_tup_del + n_tup_hot_upd) as writes,
    seq_scan as table_scans
  from pg_stat_user_tables as tabstats
  join fk_list on relid = conrelid
)
select
  nspname as schema_name,
  relname as table_name,
  conname as fk_name,
  issue,
  table_mb,
  writes,
  table_scans,
  parent_name,
  parent_mb,
  parent_writes,
  cols_list,
  indexdef
from fk_index_check
join parent_table_stats using (fkoid)
join fk_table_stats using (fkoid)
where
  table_mb > 9
  and (
    writes > 1000
    or parent_writes > 1000
    or parent_mb > 10
  )
order by issue_sort, table_mb desc, table_name, fk_name;

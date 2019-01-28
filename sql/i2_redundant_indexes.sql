-- List of redundant indexes

-- Use it to see redundant indexes list

-- This query doesn't need any additional extensions to be installed
-- (except plpgsql), and doesn't create anything (like views or smth)
-- -- so feel free to use it in your clouds (Heroku, AWS RDS, etc)

-- (Keep in mind, that on replicas, the whole picture of index usage
-- is usually very different from master).

with index_data as (
  select
    *,
    indkey::text as columns,
    array_to_string(indclass, ', ') as opclasses
  from pg_index
), redundant as (
  select
    tnsp.nspname AS schema_name,
    trel.relname AS table_name,
    irel.relname AS index_name,
    am1.amname as access_method,
    format('redundant to index: %I', i1.indexrelid::regclass)::text as reason,
    pg_get_indexdef(i1.indexrelid) main_index_def,
    pg_size_pretty(pg_relation_size(i1.indexrelid)) main_index_size,
    pg_get_indexdef(i2.indexrelid) index_def,
    pg_size_pretty(pg_relation_size(i2.indexrelid)) index_size,
    s.idx_scan as index_usage
  from
    index_data as i1
    join index_data as i2 on (
        i1.indrelid = i2.indrelid /* same table */
        and i1.indexrelid <> i2.indexrelid /* NOT same index */
    )
    inner join pg_opclass op1 on i1.indclass[0] = op1.oid
    inner join pg_opclass op2 on i2.indclass[0] = op2.oid
    inner join pg_am am1 on op1.opcmethod = am1.oid
    inner join pg_am am2 on op2.opcmethod = am2.oid
    join pg_stat_user_indexes as s on s.indexrelid = i2.indexrelid
    join pg_class as trel on trel.oid = i2.indrelid
    join pg_namespace as tnsp on trel.relnamespace = tnsp.oid
    join pg_class as irel on irel.oid = i2.indexrelid
  where
    not i1.indisprimary -- index 1 is not primary
    and not ( -- skip if index1 is (primary or uniq) and is NOT (primary and uniq)
        (i1.indisprimary or i1.indisunique)
        and (not i2.indisprimary or not i2.indisunique)
    )
    and  am1.amname = am2.amname -- same access type
    and (
      i2.columns like (i1.columns || '%') -- index 2 includes all columns from index 1
      or i1.columns = i2.columns -- index1 and index 2 includes same columns
    )
    and (
      i2.opclasses like (i1.opclasses || '%')
      or i1.opclasses = i2.opclasses
    )
    -- index expressions is same
    and pg_get_expr(i1.indexprs, i1.indrelid) is not distinct from pg_get_expr(i2.indexprs, i2.indrelid)
    -- index predicates is same
    and pg_get_expr(i1.indpred, i1.indrelid) is not distinct from pg_get_expr(i2.indpred, i2.indrelid)
)
select * from redundant;

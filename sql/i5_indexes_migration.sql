--Cleanup unused and redundant indexes – DO & UNDO migration DDL

-- Use it to generate a database migration (e.g. RoR's db:migrate or Sqitch)
-- to drop unused and redundant indexes.

-- This query generates a set of `DROP INDEX` statements, that
-- can be used in your migration script. Also, it generates
-- `CREATE INDEX`, put them to revert/rollback migration script.

-- It is also a good idea to manually double check all indexes being dropped.
-- WARNING here: when you are dropping an index B which is redundant to some index A,
-- check that you don't drop the A itself at the same time (it can be in "unused").
-- So if B is "redundant" to A and A is "unused", the script will suggest
-- dropping both. If so, it is probably better to drop B and leave A.
-- -- in this case there is a chance that A will be used. If it will still be unused,
-- you will drop it during the next cleanup routine procedure.

-- This query doesn't need any additional extensions to be installed
-- (except plpgsql), and doesn't create anything (like views or smth)
-- -- so feel free to use it in your clouds (Heroku, AWS RDS, etc)

-- It also does't do anything except reading system catalogs and
-- printing NOTICEs, so you can easily run it on your
--  production *master* database.
-- (Keep in mind, that on replicas, the whole picture of index usage
-- is usually very different from master).

-- TODO: take into account type of index and opclass
-- TODO: schemas

with unused as (
  select
      format('unused (idx_scan: %s)', pg_stat_user_indexes.idx_scan)::text as reason,
      pg_stat_user_indexes.relname as table_name,
      pg_stat_user_indexes.schemaname || '.' || indexrelname::text as index_name,
      pg_stat_user_indexes.idx_scan,
      (coalesce(n_tup_ins, 0) + coalesce(n_tup_upd, 0) - coalesce(n_tup_hot_upd, 0) + coalesce(n_tup_del, 0)) as write_activity,
      pg_stat_user_tables.seq_scan,
      pg_stat_user_tables.n_live_tup,
      pg_get_indexdef(pg_index.indexrelid) as index_def,
      pg_size_pretty(pg_relation_size(pg_index.indexrelid::regclass)) as index_size,
      pg_index.indexrelid
  from pg_stat_user_indexes
  join pg_stat_user_tables
      on pg_stat_user_indexes.relid = pg_stat_user_tables.relid
  join pg_index
      ON pg_index.indexrelid = pg_stat_user_indexes.indexrelid
  where
      pg_stat_user_indexes.idx_scan = 0 /* < 10 or smth */
      and pg_index.indisunique is false
      and pg_stat_user_indexes.idx_scan::float/(coalesce(n_tup_ins,0)+coalesce(n_tup_upd,0)-coalesce(n_tup_hot_upd,0)+coalesce(n_tup_del,0)+1)::float<0.01
), index_data as (
  select
    *,
    indkey::text as columns,
    array_to_string(indclass, ', ') as opclasses
  from pg_index
), redundant as (
  select
    i2.indrelid::regclass::text as table_name,
    i2.indexrelid::regclass::text as index_name,
    am1.amname as access_method,
    format('redundant to index: %I', i1.indexrelid::regclass)::text as reason,
    pg_get_indexdef(i1.indexrelid) main_index_def,
    pg_get_indexdef(i2.indexrelid) index_def,
    pg_size_pretty(pg_relation_size(i2.indexrelid)) index_size,
    s.idx_scan as index_usage,
    i2.indexrelid
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
    -- index expressions are same
    and pg_get_expr(i1.indexprs, i1.indrelid) is not distinct from pg_get_expr(i2.indexprs, i2.indrelid)
    -- index predicates are same
    and pg_get_expr(i1.indpred, i1.indrelid) is not distinct from pg_get_expr(i2.indpred, i2.indrelid)
), together as (
  select reason, table_name, index_name, index_size, index_def, null as main_index_def, indexrelid
  from unused
  union all
  select reason, table_name, index_name, index_size, index_def, main_index_def, indexrelid
  from redundant
  where index_usage = 0
), droplines as (
  select format('DROP INDEX CONCURRENTLY %s; -- %s, %s, table %s', max(index_name), max(index_size), string_agg(reason, ', '), table_name) as line
  from together t1
  group by table_name, index_name
  order by table_name, index_name
), createlines as (
  select
    replace(
      format('%s; -- table %s', max(index_def), table_name),
      'CREATE INDEX',
      'CREATE INDEX CONCURRENTLY'
    )as line
  from together t2
  group by table_name, index_name
  order by table_name, index_name
)
select '-- DO migration: --' as run_in_separate_transactions
union all
select * from droplines
union all
select ''
union all
select '-- UNDO migration: --'
union all
select * from createlines;


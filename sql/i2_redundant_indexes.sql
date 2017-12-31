--Unused/Redundant Indexes Do & Undo Migration DDL

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
      pg_stat_user_indexes.relname as tablename,
      pg_stat_user_indexes.schemaname || '.' || indexrelname::text as indexname,
      pg_stat_user_indexes.idx_scan,
      (coalesce(n_tup_ins, 0) + coalesce(n_tup_upd, 0) - coalesce(n_tup_hot_upd, 0) + coalesce(n_tup_del, 0)) as write_activity,
      pg_stat_user_tables.seq_scan,
      pg_stat_user_tables.n_live_tup,
      pg_get_indexdef(pg_index.indexrelid) as indexdef,
      pg_size_pretty(pg_relation_size(pg_index.indexrelid::regclass)) as size,
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
      and (coalesce(n_tup_ins,0)+coalesce(n_tup_upd,0)-coalesce(n_tup_hot_upd,0)+coalesce(n_tup_del,0))>10000
), index_data as (
  select *, string_to_array(indkey::text,' ') as key_array,array_length(string_to_array(indkey::text,' '),1) as nkeys
  from pg_index
), redundant as (
  select
    format('redundant to index: %I', i1.indexrelid::regclass)::text as reason,
    i2.indrelid::regclass::text as tablename,
    i2.indexrelid::regclass::text as indexname,
    pg_get_indexdef(i1.indexrelid) main_indexdef,
    pg_get_indexdef(i2.indexrelid) indexdef,
    pg_size_pretty(pg_relation_size(i2.indexrelid)) size,
    i2.indexrelid
  from
    index_data as i1
    join index_data as i2 on i1.indrelid = i2.indrelid and i1.indexrelid <> i2.indexrelid
  where
    (regexp_replace(i1.indpred, 'location \d+', 'location', 'g') IS NOT DISTINCT FROM regexp_replace(i2.indpred, 'location \d+', 'location', 'g'))
    and (regexp_replace(i1.indexprs, 'location \d+', 'location', 'g') IS NOT DISTINCT FROM regexp_replace(i2.indexprs, 'location \d+', 'location', 'g')) 
    and ((i1.nkeys > i2.nkeys and not i2.indisunique) OR (i1.nkeys=i2.nkeys and ((i1.indisunique and i2.indisunique and (i1.indexrelid>i2.indexrelid)) or (not i1.indisunique and not i2.indisunique and (i1.indexrelid>i2.indexrelid)) or (i1.indisunique and not i2.indisunique))))
    and i1.key_array[1:i2.nkeys]=i2.key_array 
), together as (
  select reason, tablename, indexname, size, indexdef, null as main_indexdef, indexrelid
  from unused
  union all
  select reason, tablename, indexname, size, indexdef, main_indexdef, indexrelid
  from redundant
  order by tablename asc, indexname
), droplines as (
  select format('DROP INDEX %s; -- %s, %s, table %s', max(indexname), max(size), string_agg(reason, ', '), tablename) as line
  from together t1
  group by tablename, indexrelid
  order by tablename, indexrelid
), createlines as (
 select format('%s; -- table %s', max(indexdef), tablename) as line
  from together t2
  group by tablename, indexrelid
  order by tablename, indexrelid
)
select '-- Do migration: --' as out
union all
select * from droplines
union all
select ''
union all
select '-- Revert migration: --'
union all
select * from createlines;


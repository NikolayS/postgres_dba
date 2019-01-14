-- List of redundant indexes

-- Use it to see redundant indexes list

-- This query doesn't need any additional extensions to be installed
-- (except plpgsql), and doesn't create anything (like views or smth)
-- -- so feel free to use it in your clouds (Heroku, AWS RDS, etc)

-- (Keep in mind, that on replicas, the whole picture of index usage
-- is usually very different from master).

with index_data as (
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
)
select * from redundant;


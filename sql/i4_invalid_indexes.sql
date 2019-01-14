-- Lisf of invalid Indexes 

-- Use it to see invalid indexes list

-- This query doesn't need any additional extensions to be installed
-- (except plpgsql), and doesn't create anything (like views or smth)
-- -- so feel free to use it in your clouds (Heroku, AWS RDS, etc)

-- It also does't do anything except reading system catalogs and
-- printing NOTICEs, so you can easily run it on your
--  production *master* database.
-- (Keep in mind, that on replicas, the whole picture of index usage
-- is usually very different from master).

select 
  schemaname,
  relname,
  indexrelname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
from pg_index pidx
join pg_stat_user_indexes as idx_stat on idx_stat.indexrelid = pidx.indexrelid
where pidx.indisvalid = false;


--https://github.com/dataegret/pg-utils/tree/master/sql

SELECT
        pg_stat_user_indexes.schemaname||'.'||pg_stat_user_indexes.relname as tablename,
        indexrelname,
        pg_stat_user_indexes.idx_scan,
        (coalesce(n_tup_ins,0)+coalesce(n_tup_upd,0)-coalesce(n_tup_hot_upd,0)+coalesce(n_tup_del,0)) as write_activity,
        pg_stat_user_tables.seq_scan,
        pg_stat_user_tables.n_live_tup,
	pg_size_pretty(pg_relation_size(pg_index.indexrelid::regclass)) as size
from pg_stat_user_indexes
join pg_stat_user_tables
        on pg_stat_user_indexes.relid=pg_stat_user_tables.relid
join pg_index
        ON pg_index.indexrelid=pg_stat_user_indexes.indexrelid
where
        pg_index.indisunique is false
        and pg_stat_user_indexes.idx_scan::float/(coalesce(n_tup_ins,0)+coalesce(n_tup_upd,0)-coalesce(n_tup_hot_upd,0)+coalesce(n_tup_del,0)+1)::float<0.01
        and (coalesce(n_tup_ins,0)+coalesce(n_tup_upd,0)-coalesce(n_tup_hot_upd,0)+coalesce(n_tup_del,0))>10000
order by 4 desc,1,2;


--Unused and rarely used indexes

--PostgreSQL Experts https://github.com/pgexperts/pgx_scripts/blob/master/indexes/unused_indexes.sql

with table_scans as (
    select relid,
        tables.idx_scan + tables.seq_scan as all_scans,
        ( tables.n_tup_ins + tables.n_tup_upd + tables.n_tup_del ) as writes,
                pg_relation_size(relid) as table_size
        from pg_stat_user_tables as tables
),
all_writes as (
    select sum(writes) as total_writes
    from table_scans
),
indexes as (
    select idx_stat.relid, idx_stat.indexrelid,
        idx_stat.schemaname, idx_stat.relname as tablename,
        idx_stat.indexrelname as indexname,
        idx_stat.idx_scan,
        pg_relation_size(idx_stat.indexrelid) as index_bytes,
        indexdef ~* 'USING btree' as idx_is_btree
    from pg_stat_user_indexes as idx_stat
        join pg_index
            using (indexrelid)
        join pg_indexes as indexes
            on idx_stat.schemaname = indexes.schemaname
                and idx_stat.relname = indexes.tablename
                and idx_stat.indexrelname = indexes.indexname
    where pg_index.indisunique = false
),
index_ratios as (
select schemaname, tablename, indexname,
    idx_scan, all_scans,
    round(( case when all_scans = 0 then 0.0::NUMERIC
        else idx_scan::NUMERIC/all_scans * 100 end),2) as index_scan_pct,
    writes,
    round((case when writes = 0 then idx_scan::NUMERIC else idx_scan::NUMERIC/writes end),2)
        as scans_per_write,
    pg_size_pretty(index_bytes) as index_size,
    pg_size_pretty(table_size) as table_size,
    idx_is_btree, index_bytes
    from indexes
    join table_scans
    using (relid)
),
index_groups as (
select 'Never Used Indexes' as reason, *, 1 as grp
from index_ratios
where
    idx_scan = 0
    and idx_is_btree
union all
select 'Low Scans, High Writes' as reason, *, 2 as grp
from index_ratios
where
    scans_per_write <= 1
    and index_scan_pct < 10
    and idx_scan > 0
    and writes > 100
    and idx_is_btree
union all
select 'Seldom Used Large Indexes' as reason, *, 3 as grp
from index_ratios
where
    index_scan_pct < 5
    and scans_per_write > 1
    and idx_scan > 0
    and idx_is_btree
    and index_bytes > 100000000
union all
select 'High-Write Large Non-Btree' as reason, index_ratios.*, 4 as grp
from index_ratios, all_writes
where
    ( writes::NUMERIC / ( total_writes + 1 ) ) > 0.02
    and not idx_is_btree
    and index_bytes > 100000000
order by grp, index_bytes desc )
select
    reason,
    schemaname as schema_name,
    tablename as table_name,
    indexname as index_name,
    index_scan_pct,
    scans_per_write,
    index_size,
    table_size,
    idx_scan,
    all_scans
from index_groups
;

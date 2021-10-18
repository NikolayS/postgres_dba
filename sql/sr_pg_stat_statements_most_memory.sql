--Top 5 SQL statements which consume the most shared memory resources.

    select userid::regrole, datname, pg_size_pretty((shared_blks_hit+shared_blks_dirtied)*8) as memory_usage, query
    from pg_stat_statements pgss
    join pg_database pgd ON pgd.oid = pgss.dbid
    order by (shared_blks_hit+shared_blks_dirtied) desc limit 5;


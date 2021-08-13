--Top 5 SQL statements which consume the most I/O resources in total.

    select userid::regrole, datname, (blk_read_time+blk_write_time) as total_ios, query
    from pg_stat_statements pgss
    join pg_database pgd ON pgd.oid = pgss.dbid
    order by (blk_read_time+blk_write_time) desc limit 5;


--Top 5 SQL statements which consume the most time in total.

    select userid::regrole, datname, total_time, query
    from pg_stat_statements pgss
    join pg_database pgd ON pgd.oid = pgss.dbid
    order by total_time desc limit 5;


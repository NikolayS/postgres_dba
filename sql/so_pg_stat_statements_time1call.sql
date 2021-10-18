--Top 5 SQL statements which consume the most time in one call.

    select userid::regrole, datname, mean_time, query
    from pg_stat_statements pgss
    join pg_database pgd ON pgd.oid = pgss.dbid
    order by mean_time desc limit 5;


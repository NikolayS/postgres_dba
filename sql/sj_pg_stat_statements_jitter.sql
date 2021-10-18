--Top 5 SQL statements with the most severe response jitter.

    select userid::regrole, datname, stddev_time as jitter, query 
    from pg_stat_statements pgss
    join pg_database pgd ON pgd.oid = pgss.dbid
    order by stddev_time desc limit 5;


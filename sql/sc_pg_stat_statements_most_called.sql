--Top 5 SQL statements which consume the most time in total and have the most calls.

    select userid::regrole, datname, query, total_time, calls 
    from pg_stat_statements pgss
    join pg_database pgd ON pgd.oid = pgss.dbid 
    order by total_time desc,calls desc limit 5;


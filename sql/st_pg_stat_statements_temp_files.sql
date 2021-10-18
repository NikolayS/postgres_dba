--Top 5 SQL statements which consume the most temporary space.

    select userid::regrole, datname, temp_blks_written, pg_size_pretty(temp_blks_written*8) as temp_space_used,  query
    from pg_stat_statements pgss
    join pg_database pgd ON pgd.oid = pgss.dbid
    order by temp_blks_written desc limit 5;


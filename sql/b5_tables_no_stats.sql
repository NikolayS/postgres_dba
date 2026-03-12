--Tables and columns without stats (so bloat cannot be estimated)

--Created by PostgreSQL Experts https://github.com/pgexperts/pgx_scripts/blob/master/bloat/no_stats_table_check.sql

select table_schema, table_name,
    ( pg_class.relpages = 0 ) as is_empty,
    ( psut.relname is null or ( psut.last_analyze is null and psut.last_autoanalyze is null ) ) as never_analyzed,
    array_agg(column_name::TEXT) as no_stats_columns
from information_schema.columns
    join pg_class on columns.table_name = pg_class.relname
        and pg_class.relkind = 'r'
    join pg_namespace on pg_class.relnamespace = pg_namespace.oid
        and nspname = table_schema
    left outer join pg_stats
    on table_schema = pg_stats.schemaname
        and table_name = pg_stats.tablename
        and column_name = pg_stats.attname
    left outer join pg_stat_user_tables as psut
        on table_schema = psut.schemaname
        and table_name = psut.relname
where pg_stats.attname is null
    and table_schema not in ('pg_catalog', 'information_schema')
group by table_schema, table_name, relpages, psut.relname, last_analyze, last_autoanalyze;

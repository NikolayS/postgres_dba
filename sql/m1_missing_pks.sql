--Table(s) missing pk
select
 tbl.table_schema,
 tbl.table_name as tblname_pk_missing
from information_schema.tables tbl
where table_type = 'BASE TABLE'
  and table_schema not in ('pg_catalog', 'information_schema')
  and not exists (select 1
  from information_schema.key_column_usage kcu
  where kcu.table_name = tbl.table_name
  and kcu.table_schema = tbl.table_schema)
;

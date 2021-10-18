--Tables with neither pk nor any index 
 SELECT relid, schemaname, relname as tbl_wo_idx, n_live_tup
from pg_stat_user_tables
where relname NOT IN (select relname from pg_stat_user_indexes )
AND schemaname NOT IN ('information_schema','pg_catalog');


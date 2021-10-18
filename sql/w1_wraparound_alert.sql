--Wrap-around approaching: when age is above 85% of freeze_max_age


-- from gsmith

SELECT
  nspname as schema_name,
  CASE WHEN relkind='t' THEN toastname ELSE relname END AS relation_fxid_approach,
  CASE WHEN relkind='t' THEN 'Toast' ELSE 'Table' END AS kind,
  pg_size_pretty(pg_relation_size(oid)) as table_sz,
  pg_size_pretty(pg_total_relation_size(oid)) as total_sz,
  age(relfrozenxid),
  last_vacuum
FROM
(SELECT
  c.oid,
  c.relkind,
  N.nspname,
  C.relname,
  T.relname AS toastname,
  C.relfrozenxid,
  date_trunc('day',greatest(pg_stat_get_last_vacuum_time(C.oid),pg_stat_get_last_autovacuum_time(C.oid)))::date AS last_vacuum,
  setting::integer as freeze_max_age
 FROM pg_class C
  LEFT JOIN pg_namespace N ON (N.oid = C.relnamespace)
  LEFT OUTER JOIN pg_class T ON (C.oid=T.reltoastrelid),
  pg_settings
  WHERE C.relkind IN ('r', 't')
-- We want toast items to appear in the wraparound list
    AND N.nspname NOT IN ('pg_catalog', 'information_schema') AND
    name='autovacuum_freeze_max_age'
    AND pg_relation_size(c.oid)>0
) AS av
WHERE age(relfrozenxid) > (0.85 * freeze_max_age)
ORDER BY age(relfrozenxid) DESC, pg_total_relation_size(oid) DESC
;


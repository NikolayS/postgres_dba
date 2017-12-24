-- enhanced version of https://github.com/ioguix/pgsql-bloat-estimation/blob/master/table/table_bloat.sql

/* WARNING: executed with a non-superuser role, the query inspect only tables you are granted to read.
* This query is compatible with PostgreSQL 9.0 and more
*/

with data as (
  SELECT current_database(), schemaname, tblname, bs*tblpages AS real_size, 
    (tblpages-est_tblpages)*bs AS extra_size,
    CASE WHEN tblpages - est_tblpages > 0
      THEN 100 * (tblpages - est_tblpages)/tblpages::float
      ELSE 0
    END AS extra_ratio, fillfactor, (tblpages-est_tblpages_ff)*bs AS bloat_size,
    CASE WHEN tblpages - est_tblpages_ff > 0
      THEN 100 * (tblpages - est_tblpages_ff)/tblpages::float
      ELSE 0
    END AS bloat_ratio, is_na
    -- , (pst).free_percent + (pst).dead_tuple_percent AS real_frag
  FROM (
    SELECT ceil( reltuples / ( (bs-page_hdr)/tpl_size ) ) + ceil( toasttuples / 4 ) AS est_tblpages,
      ceil( reltuples / ( (bs-page_hdr)*fillfactor/(tpl_size*100) ) ) + ceil( toasttuples / 4 ) AS est_tblpages_ff,
      tblpages, fillfactor, bs, tblid, schemaname, tblname, heappages, toastpages, is_na
      -- , stattuple.pgstattuple(tblid) AS pst
    FROM (
    SELECT
        ( 4 + tpl_hdr_size + tpl_data_size + (2*ma)
            - CASE WHEN tpl_hdr_size%ma = 0 THEN ma ELSE tpl_hdr_size%ma END
          - CASE WHEN ceil(tpl_data_size)::int%ma = 0 THEN ma ELSE ceil(tpl_data_size)::int%ma END
        ) AS tpl_size, bs - page_hdr AS size_per_block, (heappages + toastpages) AS tblpages, heappages,
        toastpages, reltuples, toasttuples, bs, page_hdr, tblid, schemaname, tblname, fillfactor, is_na
      FROM (
        SELECT
          tbl.oid AS tblid, ns.nspname AS schemaname, tbl.relname AS tblname, tbl.reltuples,
          tbl.relpages AS heappages, coalesce(toast.relpages, 0) AS toastpages,
          coalesce(toast.reltuples, 0) AS toasttuples,
          coalesce(substring(
            array_to_string(tbl.reloptions, ' ')
            FROM '%fillfactor=#"__#"%' FOR '#')::smallint, 100) AS fillfactor,
          current_setting('block_size')::numeric AS bs,
          CASE WHEN version()~'mingw32' OR version()~'64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END AS ma,
          24 AS page_hdr,
          23 + CASE WHEN MAX(coalesce(null_frac,0)) > 0 THEN ( 7 + count(*) ) / 8 ELSE 0::int END
             + CASE WHEN tbl.relhasoids THEN 4 ELSE 0 END AS tpl_hdr_size,
         sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 1024) ) AS tpl_data_size,
          bool_or(att.atttypid = 'pg_catalog.name'::regtype) AS is_na
        FROM pg_attribute AS att
          JOIN pg_class AS tbl ON att.attrelid = tbl.oid
          JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
          JOIN pg_stats AS s ON s.schemaname=ns.nspname
            AND s.tablename = tbl.relname AND s.inherited=false AND s.attname=att.attname
          LEFT JOIN pg_class AS toast ON tbl.reltoastrelid = toast.oid
        WHERE att.attnum > 0 AND NOT att.attisdropped
          AND tbl.relkind = 'r'
        GROUP BY 1,2,3,4,5,6,7,8,9,10, tbl.relhasoids
        ORDER BY 2,3
      ) AS s
    ) AS s2
  ) AS s3
  -- WHERE NOT is_na
  --   AND tblpages*((pst).free_percent + (pst).dead_tuple_percent)::float4/100 >= 1
)
select current_database, schemaname, tblname,
   real_size, pg_size_pretty(real_size::numeric) as real_size_pretty,
   extra_size, pg_size_pretty(extra_size::numeric) as extra_size_pretty,
   extra_ratio as "extra_ratio, %",
   bloat_size, pg_size_pretty(bloat_size::numeric) as bloat_size_pretty,
   bloat_ratio as "bloat_ratio, %",
   fillfactor,
   is_na,
   real_size - bloat_size as live_data_size
from data
order by bloat_size desc
;


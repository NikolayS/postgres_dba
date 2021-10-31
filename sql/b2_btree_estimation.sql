--B-tree index bloat (estimated)

-- enhanced version of https://github.com/ioguix/pgsql-bloat-estimation/blob/master/btree/btree_bloat.sql

-- WARNING: executed with a non-superuser role, the query inspect only index on tables you are granted to read.
-- WARNING: rows with is_na = 't' are known to have bad statistics ("name" type is not supported).
-- This query is compatible with PostgreSQL 8.2+

with step1 as (
  select
    i.nspname as schema_name,
    i.tblname as table_name,
    i.idxname as index_name,
    i.reltuples,
    i.relpages,
    i.relam,
    a.attrelid AS table_oid,
    current_setting('block_size')::numeric AS bs,
    fillfactor,
    -- MAXALIGN: 4 on 32bits, 8 on 64bits (and mingw32 ?)
    case when version() ~ 'mingw32|64-bit|x86_64|ppc64|ia64|amd64' then 8 else 4 end as maxalign,
    /* per page header, fixed size: 20 for 7.X, 24 for others */
    24 AS pagehdr,
    /* per page btree opaque data */
    16 AS pageopqdata,
    /* per tuple header: add IndexAttributeBitMapData if some cols are null-able */
    case
      when max(coalesce(s.null_frac,0)) = 0 then 2 -- IndexTupleData size
      else 2 + (( 32 + 8 - 1 ) / 8) -- IndexTupleData size + IndexAttributeBitMapData size ( max num filed per index + 8 - 1 /8)
    end as index_tuple_hdr_bm,
    /* data len: we remove null values save space using it fractionnal part from stats */
    sum((1 - coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 1024)) as nulldatawidth,
    max(case when a.atttypid = 'pg_catalog.name'::regtype then 1 else 0 end) > 0 as is_na
  from pg_attribute as a
  join (
    select
      nspname, tbl.relname AS tblname, idx.relname AS idxname, idx.reltuples, idx.relpages, idx.relam,
      indrelid, indexrelid, indkey::smallint[] AS attnum,
      coalesce(substring(array_to_string(idx.reloptions, ' ') from 'fillfactor=([0-9]+)')::smallint, 90) as fillfactor
    from pg_index
    join pg_class idx on idx.oid = pg_index.indexrelid
    join pg_class tbl on tbl.oid = pg_index.indrelid
    join pg_namespace on pg_namespace.oid = idx.relnamespace
    where pg_index.indisvalid AND tbl.relkind = 'r' AND idx.relpages > 0
  ) as i on a.attrelid = i.indexrelid
  join pg_stats as s on
    s.schemaname = i.nspname
    and (
      (s.tablename = i.tblname and s.attname = pg_catalog.pg_get_indexdef(a.attrelid, a.attnum, true)) -- stats from tbl
      OR (s.tablename = i.idxname AND s.attname = a.attname) -- stats from functionnal cols
    )
  join pg_type as t on a.atttypid = t.oid
  where a.attnum > 0
  group by 1, 2, 3, 4, 5, 6, 7, 8, 9
), step2 as (
  select
    *,
    (
      index_tuple_hdr_bm + maxalign
      -- Add padding to the index tuple header to align on MAXALIGN
      - case when index_tuple_hdr_bm % maxalign = 0 THEN maxalign else index_tuple_hdr_bm % maxalign end
      + nulldatawidth + maxalign
      -- Add padding to the data to align on MAXALIGN
      - case
          when nulldatawidth = 0 then 0
          when nulldatawidth::integer % maxalign = 0 then maxalign
          else nulldatawidth::integer % maxalign
        end
    )::numeric as nulldatahdrwidth
    -- , index_tuple_hdr_bm, nulldatawidth -- (DEBUG INFO)
  from step1
), step3 as (
  select
    *,
    -- ItemIdData size + computed avg size of a tuple (nulldatahdrwidth)
    coalesce(1 + ceil(reltuples / floor((bs - pageopqdata - pagehdr) / (4 + nulldatahdrwidth)::float)), 0) as est_pages,
    coalesce(1 + ceil(reltuples / floor((bs - pageopqdata - pagehdr) * fillfactor / (100 * (4 + nulldatahdrwidth)::float))), 0) as est_pages_ff
    -- , stattuple.pgstatindex(quote_ident(nspname)||'.'||quote_ident(idxname)) AS pst, index_tuple_hdr_bm, maxalign, pagehdr, nulldatawidth, nulldatahdrwidth, reltuples -- (DEBUG INFO)
  from step2
  join pg_am am on step2.relam = am.oid
  where am.amname = 'btree'
), step4 as (
  SELECT
    *,
    bs*(relpages)::bigint AS real_size,
-------current_database(), nspname AS schemaname, tblname, idxname, bs*(relpages)::bigint AS real_size,
    bs*(relpages-est_pages)::bigint AS extra_size,
    100 * (relpages-est_pages)::float / relpages AS extra_ratio,
    bs*(relpages-est_pages_ff) AS bloat_size,
    100 * (relpages-est_pages_ff)::float / relpages AS bloat_ratio
    -- , 100-(sub.pst).avg_leaf_density, est_pages, index_tuple_hdr_bm, maxalign, pagehdr, nulldatawidth, nulldatahdrwidth, sub.reltuples, sub.relpages -- (DEBUG INFO)
  from step3
  -- WHERE NOT is_na
)
select
  case is_na when true then 'TRUE' else '' end as "Is N/A",
  format(
    $out$%s
  (%s)$out$,
    left(index_name, 50) || case when length(index_name) > 50 then '…' else '' end,
    coalesce(nullif(schema_name, 'public') || '.', '') || table_name
  ) as "Index (Table)",
  pg_size_pretty(real_size::numeric) as "Size",
  case
    when extra_size::numeric >= 0
      then '~' || pg_size_pretty(extra_size::numeric)::text || ' (' || round(extra_ratio::numeric, 2)::text || '%)'
    else null
  end  as "Extra",
  case
    when bloat_size::numeric >= 0
      then '~' || pg_size_pretty(bloat_size::numeric)::text || ' (' || round(bloat_ratio::numeric, 2)::text || '%)'
    else null
  end as "Bloat",
  case
    when (real_size - bloat_size)::numeric >=0
      then '~' || pg_size_pretty((real_size - bloat_size)::numeric)
      else null
   end as "Live",
  fillfactor
from step4
order by real_size desc nulls last
;

/*
Author of the original version:
  2015, Jehan-Guillaume (ioguix) de Rorthais
License of the original version:
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/


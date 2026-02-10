# postgres_dba 7.0

**34 reports** | Tested on **PostgreSQL 13–18** | Works with `pg_monitor` role

## New Reports

### Corruption checks (c1–c4) — powered by `amcheck`

Four levels of integrity checking, from quick production-safe to full paranoia:

| Report | Lock | What it checks | When to use |
|--------|------|----------------|-------------|
| **c1** | AccessShareLock | B-tree pages, GIN indexes (PG18+) | **Production** — fast, safe, non-blocking |
| **c2** | AccessShareLock | c1 + heap/TOAST integrity (PG14+) | **Production** — safe but reads all data |
| **c3** | ShareLock | B-tree parent-child ordering, sibling pointers, rootdescend, checkunique (PG14+) | **Clones** — detects glibc/collation corruption |
| **c4** | ShareLock | Everything in c3 + heapallindexed + verify_heapam with full TOAST | **Clones only** — proves every heap tuple is indexed, slow |

All four check system catalog indexes (`pg_catalog`, `pg_toast`).

Requires `CREATE EXTENSION amcheck`. Graceful handling when extension is missing or user lacks privileges. Version-conditional function signatures for PG11–18. GIN support via `gin_index_check()` on PG18+.

### m1 — Buffer cache contents
What's in `shared_buffers`: cached size vs total, % of cache per object, dirty buffer counts. Includes system catalogs. Requires `pg_buffercache`.

### s3 — Workload profile by query type
Groups `pg_stat_statements` by first SQL keyword (SELECT, INSERT, UPDATE, DELETE, etc.). Handles leading block comments (`/* ... */`) and line comments (`-- ...`).

### t2 — Objects with custom storage parameters
Tables, indexes, and materialized views with non-default `reloptions`. Flags: disabled autovacuum on large tables, low fillfactor, aggressive vacuum scale factors.

### Report 0 — WAL and replication slot info
Node information now includes WAL position, file count, total WAL size, and replication slot status.

## Report Renames

| Old | New | Reason |
|-----|-----|--------|
| b6 | **m1** | Buffer cache → **m** (memory) category |
| c1 | **p1** | Index creation progress → **p** (progress) category |
| p1 | **x1** | Alignment padding → **x** (experimental) category |

v1/v2 descriptions clarified: v1 is "running operations (detailed progress)", v2 is "autovacuum queue and pending tables".

## Bug Fixes

- **s1, s2**: Fixed `blk_read_time does not exist` on PG17+ (renamed to `shared_blk_read_time` in pg_stat_statements 1.11)
- **s3**: Fixed `function round(double precision, integer) does not exist` — added `::numeric` casts
- **i3**: Fixed `operator is not unique` error when `intarray` extension is installed
- **m1**: Include system catalogs in buffer cache report (was showing empty on small databases)
- **i2**: Removed dead code (`redundant_indexes_grouped` CTE)
- **s1**: Removed duplicate `sum(calls)` in pre-PG13 code path

## Terminology

`Master` → `Primary` across all reports and CI.

## Other Improvements

- Modernized README with badges, individual credits, optional extensions table
- Fixed Quick Start psqlrc escaping
- Fixed menu spacing for new reports
- `alt_shits` → `alt_shifts` (p1)
- Various typo fixes across b1, b2, b3, b4, l1, s2, v2

## CI

- All 34 reports tested on PG 13, 14, 15, 16, 17, 18
- Added `amcheck`, `intarray`, `pg_buffercache` extensions to test matrix
- Added i3 regression test with `intarray` installed
- Added `PAGER=cat` to prevent pager hangs

# postgres_dba 7.0

**33 reports** | Tested on **PostgreSQL 13–18** | Works with `pg_monitor` role

## New Reports

### Corruption checks (c1, c2, c3) — powered by `amcheck`

Three levels of integrity checking, all requiring `CREATE EXTENSION amcheck`:

| Report | Lock | What it checks | When to use |
|--------|------|----------------|-------------|
| **c1** | AccessShareLock | B-tree pages, GIN indexes (PG18+), heap+TOAST (PG14+) | **Production primary** — safe, non-blocking |
| **c2** | ShareLock ⚠️ | B-tree parent-child ordering, sibling pointers, rootdescend, checkunique (PG14+) | **Clones or standbys** — detects glibc/collation corruption |
| **c3** | ShareLock ⚠️⚠️ | Everything in c2 + heapallindexed + verify_heapam with full TOAST | **Clones only** — proves every heap tuple is indexed, slow on large DBs |

All three check system catalog indexes (`pg_catalog`, `pg_toast`) — because catalog corruption is the scariest kind.

Robustness:
- Graceful handling when `amcheck` extension is not installed
- No false corruption reports on insufficient privileges (reports skipped count)
- Version-conditional: uses appropriate function signatures for PG11–18
- GIN support via `gin_index_check()` on PostgreSQL 18+

### m1 — Buffer cache contents
What's in your `shared_buffers` right now. Shows cached size vs total size, % of cache used per object, and dirty buffer counts. Requires `pg_buffercache` extension.

### s3 — Workload profile by query type
Groups `pg_stat_statements` by first SQL keyword (SELECT, INSERT, UPDATE, DELETE, etc.) to show workload composition at a glance. Correctly handles queries with leading block comments (`/* ... */`) and line comments (`-- ...`).

### t2 — Objects with custom storage parameters
Lists all tables, indexes, and materialized views with non-default `reloptions`. Flags potentially problematic settings: disabled autovacuum on large tables, low fillfactor, aggressive vacuum scale factors. Shows partition relationships.

### Report 0 — WAL and replication slot info
The node information report now includes:
- **WAL**: current LSN, file count, total WAL size
- **Replication Slots**: name, type, active/inactive status, lag from current WAL position

## Report Renames

Categories reorganized for consistency:

| Old | New | Reason |
|-----|-----|--------|
| b6 | **m1** | Buffer cache → **m** (memory) category |
| c1 | **p1** | Index creation progress → **p** (progress) category |
| p1 | **x1** | Alignment padding (experimental) → **x** (experimental) category |

## Bug Fixes

- **i3**: Fixed `operator is not unique` error when `intarray` extension is installed (added explicit `::int2[]` cast)
- **s3**: Fixed `function round(double precision, integer) does not exist` — added `::numeric` casts
- **i2**: Removed unused `redundant_indexes_grouped` CTE (dead code)
- **s1**: Removed duplicate `sum(calls)` in the pre-PG13 code path

## Terminology

- Updated `Master` → `Primary` across all reports and CI (0_node, i2, i4, i5)

## Typo Fixes

- `inspect` → `inspects` (b1, b2)
- `filed` → `fields`, `fractionnal` → `fractional`, `functionnal` → `functional` (b2)
- `alt_shits` → `alt_shifts` (p1) 🙈
- `Vaccuum` → `Vacuum` (b1)
- `format` → `formatting` (s2)
- Comment formatting: added space after `--` throughout (b3, b4, l1, s2, v2)

## CI Improvements

- Added `PAGER=cat` to all `psql` invocations (prevents pager hangs)
- Added `intarray`, `pg_buffercache`, and `amcheck` extensions to test matrix
- Added foreign key test tables for i3 regression testing
- Added dedicated i3 regression test with `intarray` installed

## Compatibility

Tested on PostgreSQL 13, 14, 15, 16, 17, and 18 — all 33 reports pass with both superuser and `pg_monitor` roles.

# 🐘 postgres_dba

[![CI](https://github.com/NikolayS/postgres_dba/actions/workflows/test.yml/badge.svg)](https://github.com/NikolayS/postgres_dba/actions)
[![PostgreSQL 13–18](https://img.shields.io/badge/PostgreSQL-13--18-336791?logo=postgresql&logoColor=white)](https://www.postgresql.org/)
[![License: BSD-3](https://img.shields.io/badge/License-BSD--3-blue.svg)](LICENSE)

**34 diagnostic reports for PostgreSQL, right inside `psql`.** No agents, no daemons, no external dependencies — just SQL.

Bloat estimation, index health, lock trees, vacuum monitoring, query analysis, corruption checks, buffer cache inspection, and more. Type `:dba` and go.

![Demo](https://user-images.githubusercontent.com/1345402/74124060-dbe25c00-4b85-11ea-9538-8d3b67f09896.gif)

## Quick Start

```bash
git clone https://github.com/NikolayS/postgres_dba.git
cd postgres_dba
echo "\\set dba '\\\\i $(pwd)/start.psql'" >> ~/.psqlrc
```

Connect to any Postgres server via psql and type `:dba`.

> **Requires psql 10+.** The server can be any version. For best results, use the latest psql client.

## Reports

### General (0–3)
| ID | Report |
|----|--------|
| 0 | Node info: primary/replica, replication lag, database size, temp files, WAL, replication slots |
| 1 | Database sizes and stats |
| 2 | Table and index sizes, row counts |
| 3 | Load profile |

### Activity & Locks
| ID | Report |
|----|--------|
| a1 | Current connections grouped by database, user, state |
| l1 | Lock trees (lightweight) |
| l2 | Lock trees with wait times (PG14+ `pg_locks.waitstart`) |

### Bloat
| ID | Report |
|----|--------|
| b1 | Table bloat estimation |
| b2 | B-tree index bloat estimation |
| b3 | Table bloat via `pgstattuple` (expensive) |
| b4 | B-tree index bloat via `pgstattuple` (expensive) |
| b5 | Tables without stats (bloat can't be estimated) |

### Corruption Checks (`amcheck`)
| ID | Lock | Report |
|----|------|--------|
| c1 | AccessShareLock | Quick index check: btree + GIN (PG18+). Safe for production. |
| c2 | AccessShareLock | Indexes + heap/TOAST (PG14+). Safe but reads all data. |
| c3 | ⚠️ ShareLock | B-tree parent check — detects glibc/collation corruption. Use on clones. |
| c4 | ⚠️⚠️ ShareLock | Full: heapallindexed + parent + heap. Proves every tuple is indexed. |

### Memory
| ID | Report |
|----|--------|
| m1 | Buffer cache contents (`pg_buffercache`, expensive) |

### Indexes
| ID | Report |
|----|--------|
| i1 | Unused and rarely used indexes |
| i2 | Redundant indexes |
| i3 | Foreign keys with missing indexes |
| i4 | Invalid indexes |
| i5 | Index cleanup DDL generator (DO & UNDO) |

### Vacuum
| ID | Report |
|----|--------|
| v1 | Vacuum: current activity |
| v2 | Autovacuum progress and queue |

### Progress
| ID | Report |
|----|--------|
| p1 | `CREATE INDEX` / `REINDEX` progress |

### Statements (`pg_stat_statements`)
| ID | Report |
|----|--------|
| s1 | Slowest queries by total time |
| s2 | Full query performance report |
| s3 | Workload profile by query type |

### Tuning & Config
| ID | Report |
|----|--------|
| t1 | Postgres parameters tuning |
| t2 | Objects with custom storage parameters |
| e1 | Installed extensions |
| x1 | Alignment padding analysis (experimental) |
| r1 | Create user with random password |
| r2 | Alter user with random password |

## Optional Extensions

Some reports benefit from additional extensions:

| Extension | Reports | Install |
|-----------|---------|---------|
| `pg_stat_statements` | s1, s2, s3 | `shared_preload_libraries = 'pg_stat_statements'` |
| `amcheck` | c1, c2, c3, c4 | `CREATE EXTENSION amcheck;` |
| `pgstattuple` | b3, b4 | `CREATE EXTENSION pgstattuple;` |
| `pg_buffercache` | m1 | `CREATE EXTENSION pg_buffercache;` |

## Compatibility

Tested on **PostgreSQL 13 through 18** via CI on every commit. Older versions (9.6–12) may work but are not actively tested.

Works with the `pg_monitor` role — superuser is not required for most reports (corruption checks need superuser or explicit `GRANT EXECUTE`).

## Adding Custom Reports

Drop a `.sql` file in `sql/`. The filename format is `<id>_<name>.sql`. The first line must be a `--` comment with the description — it becomes the menu entry automatically.

```bash
# Regenerate the menu after adding/removing reports
bash ./init/generate.sh
```

## Recommended: pspg

[pspg](https://github.com/okbob/pspg) makes tabular output much easier to read:

```sql
\setenv PAGER pspg
\pset border 2
\pset linestyle unicode
```

## Credits

Built on diagnostic queries contributed by many people over the years:

- **Gilles Darold** ([ioguix](https://github.com/ioguix)) — bloat estimation queries
- **Alexey Lesovsky**, **Maxim Boguk**, **Ilya Kosmodemiansky**, **Andrey Ermakov** — pg-utils diagnostic suite
- **Josh Berkus**, **Greg Smith**, **Christophe Pettus**, **Quinn Weaver** — pgx_scripts collection

## License

[BSD 3-Clause](LICENSE)

## Contact

[Nikolay Samokhvalov](https://github.com/NikolayS) — nik@postgres.ai

[Open an issue](https://github.com/NikolayS/postgres_dba/issues) for questions, ideas, or bug reports.

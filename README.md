# postgres_dba

The missing set of useful tools for Postgres DBAs.

![Demo](https://user-images.githubusercontent.com/1345402/74124060-dbe25c00-4b85-11ea-9538-8d3b67f09896.gif)

## Installation

```bash
git clone https://github.com/NikolayS/postgres_dba.git
cd postgres_dba
printf "%s %s %s %s\n" \\echo 🧐 🐘 'postgres_dba installed. Use ":dba" to see menu' >> ~/.psqlrc
printf "%s %s %s %s\n" \\set dba \'\\\\i $(pwd)/start.psql\' >> ~/.psqlrc
```

Then connect to any Postgres server via psql and type `:dba` to open the interactive menu.

**Requires psql 10+.** The Postgres server itself can be older for most reports. For best results, use psql from the latest PostgreSQL release.

## Reports

### General info
| ID | Report |
|----|--------|
| 0 | Node information: primary/replica, lag, database size, temp files |
| 1 | Database sizes and stats |
| 2 | Table and index sizes, row counts |
| 3 | Load profile |

### Activity and locks
| ID | Report |
|----|--------|
| a1 | Current activity: connections grouped by database, user, state |
| l1 | Lock trees (lightweight) |
| l2 | Lock trees, detailed (on PG14+ shows wait time from `pg_locks.waitstart`) |

### Bloat
| ID | Report |
|----|--------|
| b1 | Table bloat estimation |
| b2 | B-tree index bloat estimation |
| b3 | Table bloat via `pgstattuple` (expensive) |
| b4 | B-tree index bloat via `pgstattuple` (expensive) |
| b5 | Tables and columns without stats (bloat cannot be estimated) |

### Corruption checks
| ID | Report |
|----|--------|
| c1 | Quick index check: btree + GIN (PG18+). Fast, safe for production (AccessShareLock) |
| c2 | Indexes + heap/TOAST (PG14+). Safe for production but reads all data (AccessShareLock) |
| c3 | B-tree parent check — detects glibc/collation corruption (⚠️ ShareLock — use on clones) |
| c4 | Full: heapallindexed + parent + heap — proves every tuple is indexed (⚠️⚠️ slow + ShareLock — use on clones) |

### Memory
| ID | Report |
|----|--------|
| m1 | Buffer cache contents (requires `pg_buffercache`, expensive) |

### Indexes
| ID | Report |
|----|--------|
| i1 | Unused and rarely used indexes |
| i2 | Redundant indexes |
| i3 | Foreign keys with missing indexes |
| i4 | Invalid indexes |
| i5 | Index cleanup migration DDL (DO & UNDO) |

### Vacuum and maintenance
| ID | Report |
|----|--------|
| v1 | Vacuum: current activity |
| v2 | Autovacuum progress and queue |

### Progress
| ID | Report |
|----|--------|
| p1 | Index creation/reindex progress |

### Statements
| ID | Report |
|----|--------|
| s1 | Slowest queries by total time (requires `pg_stat_statements`) |
| s2 | Slowest queries report (requires `pg_stat_statements`) |
| s3 | Workload profile by query type (requires `pg_stat_statements`) |

### Configuration and other
| ID | Report |
|----|--------|
| t1 | Postgres parameters tuning |
| t2 | Objects with custom storage parameters |
| e1 | Installed extensions |
| x1 | Alignment padding analysis (experimental) |
| r1 | Create user with random password (interactive) |
| r2 | Alter user with random password (interactive) |

## PostgreSQL compatibility

Tested with **PostgreSQL 13 through 18**. Older versions (9.6-12) may work but are not actively tested. Some reports require features from newer versions (noted in the report headers).

## Adding custom reports

Add a `.sql` file to the `sql/` directory. The filename format is `<id>_<name>.sql` (e.g., `f1_my_query.sql`). The first line must be an SQL comment (`--`) with the report description — it appears in the menu automatically.

Then regenerate the menu:

```bash
bash ./init/generate.sh
```

## Recommended: pspg pager

[pspg](https://github.com/okbob/pspg) makes tabular psql output much easier to read. After installing, add to `~/.psqlrc`:

```
\setenv PAGER pspg
\pset border 2
\pset linestyle unicode
```

## Credits

Based on queries by many contributors, including:
- [ioguix](https://github.com/ioguix/pgsql-bloat-estimation) (bloat estimation)
- [Data Egret](https://github.com/dataegret/pg-utils) (Lesovsky, Ermakov, Boguk, Kosmodemiansky et al.)
- [PostgreSQL Experts](https://github.com/pgexperts/pgx_scripts) (Berkus, Weaver et al.)

## Contact

Questions or ideas: nik@postgres.ai (Nikolay Samokhvalov), or [open an issue](https://github.com/NikolayS/postgres_dba/issues).

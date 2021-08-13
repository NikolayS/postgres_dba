--Complete report of a to z omitting b3, b4, p1, v1, v2 and pg_stat_statements steps
\H
\o full_report.html
\C 'NODE INFO'
\ir ./0_node.sql
\C 'DATABASES INFO'
\ir ./1_databases.sql
\C 'TABLES INFO'
\ir ./2_table_sizes.sql
\C 'PROFILES INFO'
\ir ./3_load_profiles.sql
\C 'ACTIVITY'
\ir ./a1_activity.sql
\C 'TABLE BLOAT'
\ir ./b1_table_estimation.sql
\C 'INDEX BLOAT'
\ir ./b2_btree_estimation.sql
\C 'TABLES WITH NO STATS'
\ir ./b5_tables_no_stats.sql
\C 'DUPLICATE FOREIGN KEYS'
\ir ./d1_duplicate_fks.sql
\C 'DUPLICATE INDEXES'
\ir ./d2_duplicate_idxs.sql
\C 'EXTENSIONS'
\ir ./e1_extensions.sql
\C 'EMPTY TABLES'
\ir ./e2_empty_tables.sql
\C 'RARE OR UNUSED INDEXES'
\ir ./i1_rare_indexes.sql
\C 'REDUNDANT INDEXES'
\ir ./i2_redundant_indexes.sql
\C 'UNINDEXED FKs'
\ir ./i3_non_indexed_fks.sql
\C 'INVALID INDEXES'
\ir ./i4_invalid_indexes.sql
\C 'INDEXES MIGRATION'
\ir ./i5_indexes_migration.sql
\C 'LOCKS'
\ir ./l1_lock_trees.sql
\C 'MISSING PRIMARY KEYS'
\ir ./m1_missing_pks.sql
\C 'TABLES WITH NO INDEX OR PK'
\ir ./n1_noidx_nopk.sql
-- \i s1_pg_stat_statements_top_total.sql
-- \i s2_pg_stat_statements_report.sql
-- \i t1_tuning.sql
\C 'TABLES WITH A SINGLE COLUMN'
\ir ./t2_single_columns.sql
\C 'UNLOGGED TABLES - not safe for transactions'
\ir ./u1_unlogged_tables.sql
\C 'USELESS UNIQUE OR FOREIGN KEY CONSTRAINTS'
\ir ./u2_useless_unique_fk.sql
\C 'USELESS COLUMNS'
\ir ./u3_useless_columns.sql
\C 'UNUSED TABLES'
\ir ./u4_unused_tables.sql
\C 'WRAPAROUND ALERT (more than 85% freeze_max_age)'
\ir ./w1_wraparound_alert.sql


--Unlogged tables (not crash safe, not replicated, no PITR)
SELECT
    relname as unlogged_object,
    CASE
            WHEN relkind = 'r' THEN 'table'
                WHEN relkind = 'i' THEN 'index'
                WHEN relkind = 't' THEN 'toast table'
    END relation_kind,
pg_size_pretty(relpages::bigint*8*1024) as relation_size
FROM pg_class
WHERE relpersistence = 'u';


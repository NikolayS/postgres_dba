--Duplicate indexes
SELECT c.relname as tbl_w_dup_idx,
                pg_size_pretty(SUM(pg_relation_size(idx))::BIGINT) AS SIZE,
       (array_agg(idx))[1] AS idx1, (array_agg(idx))[2] AS idx2,
       (array_agg(idx))[3] AS idx3, (array_agg(idx))[4] AS idx4
FROM (
    SELECT
                        indrelid,
                        indexrelid::regclass AS idx,
                        (indrelid::text ||E'\n'|| indclass::text ||E'\n'|| indkey::text ||E'\n'||
                                         COALESCE(indexprs::text,'')||E'\n' || COALESCE(indpred::text,'')) AS KEY
    FROM pg_index) sub
JOIN pg_class c ON sub.indrelid=c.oid
GROUP BY KEY, c.relname HAVING COUNT(*)>1
ORDER BY SUM(pg_relation_size(idx)) DESC;


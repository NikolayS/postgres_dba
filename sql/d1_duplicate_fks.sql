--Duplicate foreign keys
SELECT
    array_agg(pc.conname) as duplicated_constraints,
    pclsc.relname as child_table,
    pac.attname as child_column,
    pclsp.relname as parent_table,
    pap.attname as parent_column,
    nspname as schema_name
FROM
    (
    SELECT
     connamespace,conname, unnest(conkey) as "conkey", unnest(confkey)
      as "confkey" , conrelid, confrelid, contype
     FROM
        pg_constraint
    ) pc
    JOIN pg_namespace pn ON pc.connamespace = pn.oid
    JOIN pg_class pclsc ON pc.conrelid = pclsc.oid
    JOIN pg_class pclsp ON pc.confrelid = pclsp.oid
    JOIN pg_attribute pac ON pc.conkey = pac.attnum and pac.attrelid = pclsc.oid
    JOIN pg_attribute pap ON pc.confkey = pap.attnum and pap.attrelid = pclsp.oid
GROUP BY child_table, child_column, parent_table, parent_column, schema_name HAVING COUNT(*)>1
ORDER BY child_table, child_column ;



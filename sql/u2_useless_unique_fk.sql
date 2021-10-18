--Useless unique constraints on FK or PK
SELECT
       pgc1.conrelid, pgcl.relname, pgc1.conname, pgc1.contype
  FROM pg_constraint pgc1
FULL JOIN
         pg_constraint pgc2
      ON pgc1.conrelid = pgc2.conrelid
JOIN
         pg_class pgcl
      ON pgcl.oid=pgc1.conrelid

WHERE pgc1.conkey = pgc2.conkey
  AND pgc1.contype ='u'

GROUP BY pgc1.conrelid, pgcl.relname, pgc1.conname, pgc1.contype
HAVING count(pgc1.conname) >1;


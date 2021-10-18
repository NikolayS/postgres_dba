--Tables with a single column (might need a more detailed column if PK, if nonPK relation why bother?)
SELECT 
	table_catalog,
	table_schema,
	table_name as table_single_column, 
	count(column_name)
FROM information_schema.columns
WHERE table_schema NOT IN ('information_schema', 'maintenance_schema')
GROUP BY table_catalog,table_schema,table_name
HAVING COUNT (column_name)= 1 ;


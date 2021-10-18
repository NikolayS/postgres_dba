--Empty tables
SELECT 
	schemaname, 
	relname as empty_table
FROM 
	pg_stat_user_tables
WHERE 
	n_live_tup = 0;


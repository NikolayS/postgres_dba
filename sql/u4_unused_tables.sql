--Unused tables

SELECT schemaname, relname as unused_table
FROM pg_stat_user_tables
WHERE (idx_tup_fetch + seq_tup_read)= 0; -- tables where no tuple is read either from seqscan or idx


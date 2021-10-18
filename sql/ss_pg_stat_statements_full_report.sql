--Top5 Report with si, sm, so, sc, st, sj, sr (requires pg_stat_statements + track_io_timing=on)
\H
\o full_report_pg_stat_statements.html
\C 'MOST CALLED QUERIES'
\ir ./sc_pg_stat_statements_most_called.sql
\C 'MOST IOs QUERIES'
\ir ./si_pg_stat_statements_io.sql
\C 'MOST JITTER QUERIES'
\ir ./sj_pg_stat_statements_jitter.sql
\C 'MOST TIME IN TOTAL QUERIES'
\ir ./sm_pg_stat_statements_time_total.sql
\C 'MOST TIME IN 1 CALL QUERIES'
\ir ./so_pg_stat_statements_time1call.sql
\C 'MOST SHARED BUFFERS QUERIES'
\ir ./sr_pg_stat_statements_most_memory.sql
\C 'MOST TEMP FILES QUERIES'
\ir ./st_pg_stat_statements_temp_files.sql


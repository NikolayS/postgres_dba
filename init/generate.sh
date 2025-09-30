#!/bin/bash
# Generate start.psql based on the contents of "sql" directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

WARMUP="warmup.psql"
OUT="start.psql"

> "$WARMUP"
> "$OUT"

cd "$DIR/.."
cat > "$WARMUP" <<- VersCheck
-- check if "\if" is supported (psql 10+)
\if false
  \echo cannot work, you need psql version 10+ (Postgres server can be older)
  select 1/0;
\endif

select current_setting('server_version_num')::integer >= 170000 as postgres_dba_pgvers_17plus \gset

select current_setting('server_version_num')::integer >= 130000 as postgres_dba_pgvers_13plus \gset

select current_setting('server_version_num')::integer >= 100000 as postgres_dba_pgvers_10plus \gset
\if :postgres_dba_pgvers_10plus
  \set postgres_dba_last_wal_receive_lsn pg_last_wal_receive_lsn
  \set postgres_dba_last_wal_replay_lsn pg_last_wal_replay_lsn
  \set postgres_dba_is_wal_replay_paused pg_is_wal_replay_paused
\else
  \set postgres_dba_last_wal_receive_lsn pg_last_xlog_receive_location
  \set postgres_dba_last_wal_replay_lsn pg_last_xlog_replay_location
  \set postgres_dba_is_wal_replay_paused pg_is_xlog_replay_paused
\endif

-- TODO: improve work with custom GUCs for Postgres 9.5 and older
select current_setting('server_version_num')::integer >= 90600 as postgres_dba_pgvers_96plus \gset
\if :postgres_dba_pgvers_96plus
  select coalesce(current_setting('postgres_dba.wide', true), 'off') = 'on' as postgres_dba_wide \gset
\else
  set client_min_messages to 'fatal';
  select :postgres_dba_wide as postgres_dba_wide \gset
  reset client_min_messages;
\endif
VersCheck

echo "\\ir $WARMUP" >> "$OUT"

echo "\\echo '\\033[1;35mMenu:\\033[0m'" >> "$OUT"
for f in ./sql/*.sql
do
  prefix=$(echo $f | sed -e 's/_.*$//g' -e 's/^.*\///g')
  desc=$(head -n1 $f | sed -e 's/^--//g')
  printf "%s '%4s – %s'\n" "\\echo" "$prefix" "$desc" >> "$OUT"
done
printf "%s '%4s – %s'\n" "\\echo" "q" "Quit" >> "$OUT"
echo "\\echo" >> "$OUT"
echo "\\echo Type your choice and press <Enter>:" >> "$OUT"
echo "\\prompt d_step_unq" >> "$OUT"
echo "\\set d_stp '\\'' :d_step_unq '\\''" >> "$OUT"
echo "select" >> "$OUT"

for f in ./sql/*.sql
do
  prefix=$(echo $f | sed -e 's/_.*$//g' -e 's/^.*\///g')
  echo ":d_stp::text = '$prefix' as d_step_is_$prefix," >> "$OUT"
done
echo ":d_stp::text = 'q' as d_step_is_q \\gset" >> "$OUT"

echo "\\if :d_step_is_q" >> "$OUT"
echo "  \\echo 'Bye!'" >> "$OUT"
echo "  \\echo" >> "$OUT"
for f in ./sql/*.sql
do
  prefix=$(echo $f | sed -e 's/_.*$//g' -e 's/^.*\///g')
  echo "\\elif :d_step_is_$prefix" >> "$OUT"
  echo "  \\ir $f" >> "$OUT"
  echo "  \\prompt 'Press <Enter> to continue…' d_dummy" >> "$OUT"
  echo "  \\ir ./$OUT" >> "$OUT"
done
echo "\\else" >> "$OUT"
echo "  \\echo" >> "$OUT"
echo "  \\echo '\\033[1;31mError:\\033[0m Unknown option! Try again.'" >> "$OUT"
echo "  \\echo" >> "$OUT"
echo "  \\ir ./$OUT" >> "$OUT"
echo "\\endif" >> "$OUT"

echo "Done."
cd ->/dev/null
exit 0

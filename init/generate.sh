#!/bin/bash
# Generate start.psql based on the contents of "sql" directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OUT="start.psql"

cd "$DIR/.."
echo "-- This file is auto-generated! Do not edit it. See ./init/generate.sh instead." > "$OUT"
echo "\\echo '\\033[1;35mMenu:\\033[0m'" >> "$OUT"
for f in ./sql/*.sql
do
  prefix=$(echo $f | sed -e 's/_.*$//g' -e 's/^.*\///g')
  desc=$(head -n1 $f | sed -e 's/^--//g')
  printf "%s '%4s – %s'\n" "\\echo" "$prefix" "$desc" >> "$OUT"
done
echo "\\set QUIET 1" >> "$OUT"
echo "\\if :postgres_dba_wide" >> "$OUT"
  echo "\\unset QUIET" >> "$OUT"
  printf "  %s '%4s – %s'\n" "\\echo" "x" "Turn Wide Mode OFF (currently ON): show less details, less columns" >> "$OUT"
echo "\\else" >> "$OUT"
  printf "  %s '%4s – %s'\n" "\\echo" "x" "Turn Wide Mode ON (currently OFF): show more details, more columns" >> "$OUT"
echo "\\endif" >> "$OUT"
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
echo ":d_stp::text = 'x' as d_step_is_x," >> "$OUT"
echo ":d_stp::text = 'q' as d_step_is_q \\gset" >> "$OUT"

echo "\\if :d_step_is_q" >> "$OUT"
echo "  \\echo 'Bye!'" >> "$OUT"
echo "  \\echo" >> "$OUT"
echo "\\elif :d_step_is_x" >> "$OUT"
  echo "\\set QUIET 1" >> "$OUT"
  echo "\\if :postgres_dba_wide" >> "$OUT"
    echo "\\unset QUIET" >> "$OUT"
    echo "  \\set postgres_dba_wide false" >> "$OUT"
    echo "  \\echo 'Wide mode turned OFF!'" >> "$OUT"
    echo "  \\echo" >> "$OUT"
  echo "\\else" >> "$OUT"
    echo "  \\set postgres_dba_wide true" >> "$OUT"
    echo "  \\echo 'Wide mode turned ON!'" >> "$OUT"
    echo "  \\echo" >> "$OUT"
  echo "\\endif" >> "$OUT"
  echo "  \\ir ./$OUT" >> "$OUT"
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

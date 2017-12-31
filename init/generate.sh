#!/bin/bash
# Generate start.psql based on the contents of "sql" directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

OUT="start.psql"

cd "$DIR/.."
echo "\\echo Menu:" > "$OUT"
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
  echo "  \\i $f" >> "$OUT"
  echo "  \\prompt 'Press <Enter> to continue…' d_dummy" >> "$OUT"
  echo "  \\i ./$OUT" >> "$OUT"
done
echo "\\else" >> "$OUT"
echo "  \\echo 'ERROR: Unkown option!'" >> "$OUT"
echo "  \\i ./$OUT" >> "$OUT"
echo "\\endif" >> "$OUT"

echo "Done."
cd ->/dev/null
exit 0

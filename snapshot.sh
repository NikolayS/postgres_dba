#!/usr/bin/env bash
#
# postgres_dba snapshot — dump all safe reports as plain text.
# Perfect for feeding to LLMs, saving to files, or piping to tools.
#
# Usage:
#   ./snapshot.sh                              # uses default psql connection
#   ./snapshot.sh -h localhost -U postgres -d mydb
#   ./snapshot.sh "postgresql://user@host/db"
#   ./snapshot.sh -d mydb | pbcopy             # copy to clipboard (macOS)
#   ./snapshot.sh -d mydb > snapshot.txt       # save to file
#
# Skips:
#   - Interactive reports (r1, r2 — require user input)
#   - Expensive/slow reports (b3, b4, c2, c3, c4, m1 — heavy I/O)
#   - Progress reports (p1 — only useful during operations)
#
# To include expensive reports, use --full.

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FULL=false
PSQL_ARGS=()

for arg in "$@"; do
  if [[ "$arg" == "--full" ]]; then
    FULL=true
  else
    PSQL_ARGS+=("$arg")
  fi
done

# Reports to skip in normal mode
SKIP_NORMAL="b3 b4 c2 c3 c4 m1 p1 r1 r2"

# Reports to skip even in full mode (interactive only)
SKIP_ALWAYS="r1 r2"

if $FULL; then
  SKIP="$SKIP_ALWAYS"
else
  SKIP="$SKIP_NORMAL"
fi

# Ensure non-interactive mode for t1
PSQLRC_TMP=$(mktemp)
trap "rm -f $PSQLRC_TMP" EXIT
cat > "$PSQLRC_TMP" <<'EOF'
\set postgres_dba_wide true
\set postgres_dba_interactive_mode false
\pset pager off
\pset footer off
EOF

echo "-- postgres_dba snapshot"
echo "-- Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
echo "-- Connection: $(psql "${PSQL_ARGS[@]}" --no-psqlrc -tAc "select format('%s@%s:%s/%s (PostgreSQL %s)', current_user, inet_server_addr(), inet_server_port(), current_database(), version())" 2>/dev/null || echo 'unknown')"
echo "--"
echo ""

for f in "$DIR"/sql/*.sql; do
  prefix=$(basename "$f" | sed 's/_.*$//')

  # Check skip list
  skip=false
  for s in $SKIP; do
    if [[ "$prefix" == "$s" ]]; then
      skip=true
      break
    fi
  done
  $skip && continue

  desc=$(head -n1 "$f" | sed 's/^--//')

  echo "================================================================"
  echo "== $prefix —$desc"
  echo "================================================================"
  echo ""

  PAGER=cat psql "${PSQL_ARGS[@]}" \
    --no-psqlrc \
    -f "$DIR/warmup.psql" \
    -f "$PSQLRC_TMP" \
    -f "$f" \
    2>&1 \
    | sed 's/^psql:[^ ]* //' \
    | sed 's/^NOTICE:  //' \
    | sed 's/^WARNING:  /⚠️  /' \
    | grep -v '^Pager ' \
    | grep -v '^Null display' \
    | grep -v '^Footer is off' \
    | grep -v '^DO$' \
    | grep -v '^SET$' \
    | grep -v '^$' \
    | head -500 || true

  echo ""
  echo ""
done

echo "-- End of snapshot"

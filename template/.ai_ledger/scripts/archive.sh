#!/usr/bin/env bash
# Moves ledger entries from previous months into .ai_ledger/archive/YYYY-MM.md,
# keeping evolution_log.md small enough for an AI to read in full.
# Usage (from anywhere in the repo; on Windows use Git Bash): bash .ai_ledger/scripts/archive.sh
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/../.." && pwd))
LOG="$ROOT/.ai_ledger/evolution_log.md"
ARCHIVE_DIR="$ROOT/.ai_ledger/archive"
CURRENT_MONTH=$(date +%Y-%m)

[ -f "$LOG" ] || { echo "Ledger not found: $LOG" >&2; exit 1; }
mkdir -p "$ARCHIVE_DIR"
TMP=$(mktemp)

# Text before the first entry (the file header) has no month and always stays.
MOVED=$(awk -v cur="$CURRENT_MONTH" -v dir="$ARCHIVE_DIR" -v keep="$TMP" '
  /^## \[[0-9][0-9][0-9][0-9]-[0-9][0-9]/ {
    month = substr($0, 5, 7)
    if (month < cur) moved++
  }
  {
    if (month == "" || month >= cur) { print > keep; next }
    f = dir "/" month ".md"
    if (!(f in seen)) {
      seen[f] = 1
      if ((getline line < f) < 0) print "# Architecture Ledger Archive: " month "\n" >> f
      else close(f)
    }
    print >> f
  }
  END { print moved + 0 }
' "$LOG")

cat "$TMP" > "$LOG"   # write back in place to keep the file's permissions
rm -f "$TMP"
echo "Archived $MOVED entr$([ "$MOVED" = 1 ] && echo y || echo ies) into $ARCHIVE_DIR"

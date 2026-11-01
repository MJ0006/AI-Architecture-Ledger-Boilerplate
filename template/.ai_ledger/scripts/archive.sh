#!/usr/bin/env bash
# Moves entries from previous months out of the logs, keeping them small enough for an AI to read in full:
#   evolution_log.md -> .ai_ledger/archive/YYYY-MM.md
#   analysis_log.md  -> .ai_ledger/archive/analysis/YYYY-MM.md
# (Separate folders: the commit hook counts code entries in archive/*.md only.)
# Usage (from anywhere in the repo; on Windows use Git Bash): bash .ai_ledger/scripts/archive.sh
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "$0")/../.." && pwd))
CURRENT_MONTH=$(date +%Y-%m)

# archive <log file> <archive folder> <title>
archive() {
  local log="$1" dir="$2" title="$3" tmp moved
  [ -f "$log" ] || return 0
  mkdir -p "$dir"
  tmp=$(mktemp)
  # Text before the first entry (the file header) has no month and always stays.
  moved=$(awk -v cur="$CURRENT_MONTH" -v dir="$dir" -v keep="$tmp" -v title="$title" '
    /^## \[[0-9][0-9][0-9][0-9]-[0-9][0-9]/ {
      month = substr($0, 5, 7)
      if (month < cur) moved++
    }
    {
      if (month == "" || month >= cur) { print > keep; next }
      f = dir "/" month ".md"
      if (!(f in seen)) {
        seen[f] = 1
        if ((getline line < f) < 0) print "# " title ": " month "\n" >> f
        else close(f)
      }
      print >> f
    }
    END { print moved + 0 }
  ' "$log")
  cat "$tmp" > "$log"   # write back in place to keep the file's permissions
  rm -f "$tmp"
  echo "Archived $moved entr$([ "$moved" = 1 ] && echo y || echo ies) from $(basename "$log") into $dir"
}

[ -f "$ROOT/.ai_ledger/evolution_log.md" ] || { echo "Ledger not found: $ROOT/.ai_ledger/evolution_log.md" >&2; exit 1; }
archive "$ROOT/.ai_ledger/evolution_log.md" "$ROOT/.ai_ledger/archive"          "AI Ledger Archive"
archive "$ROOT/.ai_ledger/analysis_log.md"  "$ROOT/.ai_ledger/archive/analysis" "Analysis Log Archive"

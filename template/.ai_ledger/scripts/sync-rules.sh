#!/usr/bin/env bash
# Copies .ai_ledger/agent_directives.md into the instruction file each AI tool reads
# automatically, as a marked block. Run it after editing agent_directives.md:
#   bash .ai_ledger/scripts/sync-rules.sh
# In local mode, files that are pushed with your code and hold your own content
# (e.g. a CLAUDE.md you already had) are left without the rules, so nothing leaks.
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT"
MODE=$(git config --get ailedger.mode || echo shared)
START="<!-- ai-ledger:start (generated from .ai_ledger/agent_directives.md; edit that file, then run .ai_ledger/scripts/sync-rules.sh) -->"
END="<!-- ai-ledger:end -->"

BLOCK=$(mktemp); trap 'rm -f "$BLOCK"' EXIT
{ echo "$START"; cat .ai_ledger/agent_directives.md; echo "$END"; } > "$BLOCK"

is_tracked() { git ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }
broken_markers() {  # start marker without end marker (or the reverse): never touch such a file
  [ -f "$1" ] && [ "$(grep -c '<!-- ai-ledger:start' "$1")" != "$(grep -c '<!-- ai-ledger:end -->' "$1")" ]
}
has_user_content() {  # any non-blank line outside the ledger block?
  [ -f "$1" ] && awk '/<!-- ai-ledger:start/{s=1;next} /<!-- ai-ledger:end -->/{s=0;next} !s && NF{f=1} END{exit !f}' "$1"
}
rewrite() {  # rewrite <file> <awk program> [awk args...]; keeps file permissions
  local f="$1" prog="$2"; shift 2
  awk "$@" "$prog" "$f" > "$f.tmp" && cat "$f.tmp" > "$f" && rm -f "$f.tmp"
}

# upsert <file> [frontmatter]: files with frontmatter belong to the ledger; others may be the user's.
upsert() {
  local f="$1" fm="${2:-}" action=""
  if broken_markers "$f"; then
    echo "  ! skipped $f: its ai-ledger:start / ai-ledger:end markers don't match. Fix them by hand, then re-run."
    return 0
  fi
  if [ "$MODE" = local ] && [ -z "$fm" ] && is_tracked "$f" && has_user_content "$f"; then
    if grep -qF "<!-- ai-ledger:start" "$f"; then
      rewrite "$f" '/<!-- ai-ledger:start/{s=1;next} /<!-- ai-ledger:end -->/{s=0;next} !s{l[++n]=$0}
                    END{while(n>0 && l[n] ~ /^[[:space:]]*$/) n--; for(i=1;i<=n;i++) print l[i]}'
      echo "  removed  ledger rules from $f (local mode: this file is pushed with your code)"
    else
      echo "  skipped  $f (local mode: this file is pushed with your code)"
    fi
    return 0
  fi
  mkdir -p "$(dirname "$f")"
  if [ ! -f "$f" ]; then
    if [ -n "$fm" ]; then printf '%b\n' "$fm" > "$f"; else : > "$f"; fi
    action="created "
  fi
  if grep -qF "<!-- ai-ledger:start" "$f"; then
    rewrite "$f" '/<!-- ai-ledger:start/{while((getline l < b) > 0) print l; close(b); s=1; next}
                  /<!-- ai-ledger:end -->/{s=0; next} !s' -v b="$BLOCK"
    action="${action:-updated }"
  else
    if [ -s "$f" ]; then printf '\n' >> "$f"; fi
    cat "$BLOCK" >> "$f"
    action="${action:-appended}"
  fi
  echo "  $action $f"
  if [ "$MODE" = local ] && [ -z "$fm" ] && ! is_tracked "$f" && has_user_content "$f"; then
    echo "    note: $f holds your own content, so it isn't hidden from git. Don't commit it, or the rules get published."
  fi
}

upsert "AGENTS.md"                         # Codex, OpenCode, Cursor, Copilot agent, Windsurf, Zed, Jules...
upsert "CLAUDE.md"                         # Claude Code
upsert "GEMINI.md"                         # Gemini CLI / Gemini Code Assist
upsert ".github/copilot-instructions.md"   # GitHub Copilot (VS Code, JetBrains, Visual Studio)
upsert ".cursor/rules/ai-ledger.mdc"  "---\ndescription: AI Architecture Ledger rules\nalwaysApply: true\n---\n"
upsert ".windsurf/rules/ai-ledger.md" "---\ntrigger: always_on\n---\n"

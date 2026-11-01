#!/usr/bin/env bash
# Chooses where the ledger files live.
#   local  : kept on this computer only. Never committed, never pushed.
#   shared : committed and pushed with your code. Allowed ONLY for a confirmed private repo.
#   auto   : shared if 'origin' is a private GitHub/GitLab repo, otherwise local. (default)
# Usage: bash .ai_ledger/scripts/set-mode.sh [auto|local|shared]
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT"
S=.ai_ledger/scripts
LEDGER=.ai_ledger/evolution_log.md
TOOL_FILES=(AGENTS.md CLAUDE.md GEMINI.md .github/copilot-instructions.md)

VIS=$(bash "$S/visibility.sh")
case "${1:-auto}" in
  auto)   if [ "$VIS" = private ]; then MODE=shared; else MODE=local; fi ;;
  local)  MODE=local ;;
  shared) [ "$VIS" = private ] || { echo "Refusing shared mode: 'origin' is not a confirmed private GitHub/GitLab repository (result: $VIS)." >&2; exit 1; }
          MODE=shared ;;
  *)      echo "Usage: bash $S/set-mode.sh [auto|local|shared]" >&2; exit 1 ;;
esac
git config ailedger.mode "$MODE"
bash "$S/sync-rules.sh"

has_user_content() {  # non-blank lines outside the ledger block, or unmatched markers (treat as the user's)
  [ -f "$1" ] || return 1
  [ "$(grep -c '<!-- ai-ledger:start' "$1")" = "$(grep -c '<!-- ai-ledger:end -->' "$1")" ] || return 0
  awk '/<!-- ai-ledger:start/{s=1;next} /<!-- ai-ledger:end -->/{s=0;next} !s && NF{f=1} END{exit !f}' "$1"
}
# stage_clean <file> <awk filter>: stage the COMMITTED version with the ledger parts filtered out,
# so the user's own unstaged edits in that file are never staged by this script.
stage_clean() {
  local f="$1" filter="$2" mode sha
  git cat-file -e "HEAD:$f" 2>/dev/null || return 1
  git show "HEAD:$f" | grep -qF -e '<!-- ai-ledger:start' -e '# AI Architecture Ledger:' || return 1
  [ "$(git show "HEAD:$f" | grep -c '<!-- ai-ledger:start')" = "$(git show "HEAD:$f" | grep -c '<!-- ai-ledger:end -->')" ] || return 1
  if [ -z "$(git show "HEAD:$f" | awk "$filter" | tr -d '[:space:]')" ]; then
    git rm --cached -q -- "$f"
  else
    mode=$(git ls-files -s -- "$f" | awk '{print $1; exit}'); mode=${mode:-100644}
    sha=$(git show "HEAD:$f" | awk "$filter" | git hash-object -w --stdin)
    git update-index --cacheinfo "$mode,$sha,$f"
  fi
}
STRIP_BLOCK='/<!-- ai-ledger:start/{s=1;next} /<!-- ai-ledger:end -->/{s=0;next} !s{l[++n]=$0} END{while(n>0 && l[n] ~ /^[[:space:]]*$/) n--; for(i=1;i<=n;i++) print l[i]}'
STRIP_GA='index($0, "# AI Architecture Ledger:") == 1 || $0 == ".githooks/* text eol=lf" || $0 == ".ai_ledger/scripts/*.sh text eol=lf" {next} {l[++n]=$0} END{while(n>0 && l[n] ~ /^[[:space:]]*$/) n--; for(i=1;i<=n;i++) print l[i]}'
count_entries() { cat "$LEDGER" .ai_ledger/archive/*.md 2>/dev/null | grep -cE '^## \[[0-9]{4}-' || true; }

# Remove our block from the local, never-pushed ignore list (.git/info/exclude).
EXCLUDE=$(git rev-parse --git-path info/exclude)
mkdir -p "$(dirname "$EXCLUDE")"; touch "$EXCLUDE"
awk '/^# ai-ledger:start/{s=1;next} /^# ai-ledger:end/{s=0;next} !s' "$EXCLUDE" > "$EXCLUDE.tmp"
cat "$EXCLUDE.tmp" > "$EXCLUDE"; rm -f "$EXCLUDE.tmp"

if [ "$MODE" = local ]; then
  # Everything that belongs to the ledger (never the user's own files).
  PATHS=(.ai_ledger .cursor/rules/ai-ledger.mdc .windsurf/rules/ai-ledger.md)
  for h in pre-commit pre-push post-commit; do
    if grep -qs "AI Architecture Ledger" ".githooks/$h"; then PATHS+=(".githooks/$h"); fi
  done
  for f in "${TOOL_FILES[@]}"; do
    if [ -f "$f" ] && ! has_user_content "$f"; then PATHS+=("$f"); fi
  done
  { echo "# ai-ledger:start (local-only AI ledger files; managed by .ai_ledger/scripts/set-mode.sh)"
    for p in "${PATHS[@]}"; do echo "/$p"; done
    echo "# ai-ledger:end"; } >> "$EXCLUDE"

  # Remove the ledger's lines from the shared .gitattributes (left by shared mode).
  if grep -qsF "# AI Architecture Ledger:" .gitattributes; then
    awk "$STRIP_GA" .gitattributes > .gitattributes.tmp
    if grep -q '[^[:space:]]' .gitattributes.tmp; then cat .gitattributes.tmp > .gitattributes; else rm -f .gitattributes; fi
    rm -f .gitattributes.tmp
  fi

  # Stop tracking files that were committed earlier (they stay on disk).
  UNTRACKED=$(git rm -r --cached --ignore-unmatch -q -- "${PATHS[@]}" 2>/dev/null; git diff --cached --name-only -- "${PATHS[@]}")
  # Stage ONLY the removal of ledger parts from shared files (the user's own edits stay unstaged).
  CHANGED=""
  for f in "${TOOL_FILES[@]}"; do
    if has_user_content "$f" && stage_clean "$f" "$STRIP_BLOCK"; then CHANGED="$CHANGED $f"; fi
  done
  if stage_clean .gitattributes "$STRIP_GA"; then CHANGED="$CHANGED .gitattributes"; fi

  # Baseline for the local-mode pre-commit check: entries that already exist.
  count_entries > "$(git rev-parse --git-path ai-ledger-count)"
  # Backup inside .git/ (never pushed, untouched by `git clean -x`). post-commit refreshes it.
  BACKUP=$(git rev-parse --git-path ai-ledger-backup)
  rm -rf "$BACKUP" && cp -R .ai_ledger "$BACKUP"

  echo ""
  echo "Mode: LOCAL. Ledger files stay on this computer. They are never committed or pushed."
  [ "$VIS" = private ] || echo "      (reason: 'origin' is $VIS. Only a confirmed private GitHub/GitLab repo can use shared mode.)"
  if [ -n "$UNTRACKED$CHANGED" ]; then
    FILES=$(printf '%s\n' $UNTRACKED $CHANGED | grep -v '^\.ai_ledger/' | sed 's/.*/`&`/' | paste -sd, - | sed 's/,/, /g')
    cat >> "$LEDGER" <<EOF

## [$(date '+%Y-%m-%d %H:%M')] AI ledger switched to local-only mode
- **Area:** \`/\` (repository root)
- **Files:** \`.ai_ledger/\`${FILES:+, $FILES}

### Request
> Keep the AI ledger files on this computer only.

### Assumptions
None.

### Changes
- Stopped tracking the ledger files in git (they stay on disk) and listed them in \`.git/info/exclude\`.
- Removed the ledger rules block from instruction files that are pushed with the code.

### Request vs Result
Matches the request. Copies pushed in earlier commits are still in the repository history.

### Justification
\`.git/info/exclude\` is a per-computer ignore list that is never committed, so the ledger stays private without adding anything to shared files.

### Alternatives
- \`.gitignore\` (shared with everyone and reveals the file names)
- A separate private repository for the ledger

### Concepts
- **\`git rm --cached\`:** stops tracking a file in git but keeps it on disk.
- **\`.git/info/exclude\`:** works like \`.gitignore\`, but only on this computer and is never pushed.

### How to Verify
Run \`git ls-files .ai_ledger\`. It prints nothing. Run \`git status\`. No ledger files are listed.
EOF
    echo ""
    echo "Ledger files were removed from the repository (they are still on disk). Commit that now:"
    echo "    git commit -m \"Make AI ledger local-only\""
    echo "WARNING: older commits still contain the ledger. If anyone else can see this repository,"
    echo "change any keys or passwords written in it, and clean the history with git filter-repo."
  fi
else
  rm -f "$(git rev-parse --git-path ai-ledger-count)"
  GA=.gitattributes   # hook scripts must keep LF line endings on Windows checkouts
  if ! grep -qsF ".githooks/* text eol=lf" "$GA"; then
    if [ -s "$GA" ]; then printf '\n' >> "$GA"; fi
    printf '%s\n' "# AI Architecture Ledger: hook scripts must keep LF line endings" \
      ".githooks/* text eol=lf" ".ai_ledger/scripts/*.sh text eol=lf" >> "$GA"
  fi
  cat <<'EOF'

Mode: SHARED. This repository is PRIVATE, so ledger files are committed and pushed with your code.
================================================================================
WARNING: If you ever make this repository PUBLIC, everything in the ledger becomes
public too, including anything typed into AI requests (API keys, passwords,
internal details). The pre-push hook re-checks on every push and blocks it if the
repository has become public. Before making it public, run:
    bash .ai_ledger/scripts/set-mode.sh local
================================================================================
Next: commit the ledger files, e.g.  git add -A && git commit -m "Add AI Architecture Ledger"
Teammates: after cloning, run  git config core.hooksPath .githooks
EOF
fi

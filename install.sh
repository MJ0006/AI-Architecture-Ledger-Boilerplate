#!/usr/bin/env bash
# AI Architecture Ledger installer (macOS / Linux / Git Bash on Windows).
#
# Usage:
#   ./install.sh [--local | --shared] [path/to/your/project]   # from a clone of this repo
#   curl -fsSL https://raw.githubusercontent.com/MJ0006/AI-Architecture-Ledger/main/install.sh | bash
#
# Mode (default: auto): ledger files are pushed with your code ONLY if 'origin' is a
# confirmed private GitHub/GitLab repo; otherwise they stay on this computer.
# Safe to re-run: existing files are never overwritten.
set -euo pipefail

REPO_URL="${AI_LEDGER_REPO:-https://github.com/MJ0006/AI-Architecture-Ledger.git}"
MODE=auto
TARGET_ARG=.
for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    --local)   MODE=local ;;
    --shared)  MODE=shared ;;
    *)         TARGET_ARG="$arg" ;;
  esac
done

say()  { printf '  %s\n' "$*"; }
warn() { printf '  ! %s\n' "$*"; }

# 1. Locate the template folder (next to this script, or download it).
SCRIPT_DIR=""
[ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ] && SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/template" ]; then
  TEMPLATE="$SCRIPT_DIR/template"
else
  TMP_CLONE=$(mktemp -d)
  trap 'rm -rf "$TMP_CLONE"' EXIT
  git clone --quiet --depth 1 "$REPO_URL" "$TMP_CLONE"
  TEMPLATE="$TMP_CLONE/template"
fi

# 2. Resolve the target to its git repository root, so installing from any subfolder works.
if ! TARGET=$(git -C "$TARGET_ARG" rev-parse --show-toplevel 2>/dev/null); then
  echo "Error: '$TARGET_ARG' is not inside a git repository. Run 'git init' there first." >&2
  exit 1
fi
echo "Installing AI Architecture Ledger into: $TARGET"

# 3. Copy template files without overwriting anything.
DATE=$(date '+%Y-%m-%d %H:%M')
(cd "$TEMPLATE" && find . -type f | sed 's|^\./||') | while IFS= read -r rel; do
  dest="$TARGET/$rel"
  if [ -e "$dest" ]; then
    say "kept     $rel (already exists)"
    if [ "${rel#.githooks/}" != "$rel" ] && ! grep -q "AI Architecture Ledger" "$dest"; then
      warn "Your existing $rel is not the ledger hook. Merge in the checks from"
      warn "template/$rel in the AI Architecture Ledger repo."
    fi
    continue
  fi
  mkdir -p "$(dirname "$dest")"
  if [ "$rel" = ".ai_ledger/evolution_log.md" ]; then
    sed "s/{{DATE}}/$DATE/" "$TEMPLATE/$rel" > "$dest"
  else
    cp "$TEMPLATE/$rel" "$dest"
  fi
  say "created  $rel"
done
chmod +x "$TARGET"/.ai_ledger/scripts/*.sh 2>/dev/null || true
for h in pre-commit pre-push post-commit; do
  if grep -qs "AI Architecture Ledger" "$TARGET/.githooks/$h"; then chmod +x "$TARGET/.githooks/$h"; fi
done

# 4. Activate the hooks without breaking any hook setup that already exists.
CURRENT_HOOKS=$(git -C "$TARGET" config --get core.hooksPath || true)
OLD_HOOKS_DIR="$(git -C "$TARGET" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo "$TARGET/.git")/hooks"
HOOK_LINES='    pre-commit:   [ ! -x .githooks/pre-commit ] || .githooks/pre-commit || exit 1
    pre-push:     [ ! -x .githooks/pre-push ] || .githooks/pre-push "$@" || exit 1
    post-commit:  [ ! -x .githooks/post-commit ] || .githooks/post-commit'
if [ "$CURRENT_HOOKS" = ".githooks" ]; then
  say "ok       git core.hooksPath already set to .githooks"
elif [ -n "$CURRENT_HOOKS" ]; then
  warn "git core.hooksPath is already '$CURRENT_HOOKS' (e.g. Husky). Left unchanged."
  warn "Add these lines to the matching hooks in $CURRENT_HOOKS/ to enable the ledger:"
  echo "$HOOK_LINES"
elif [ -e "$OLD_HOOKS_DIR/pre-commit" ] || [ -e "$OLD_HOOKS_DIR/pre-push" ] || [ -e "$OLD_HOOKS_DIR/post-commit" ]; then
  warn "Existing hooks found in $OLD_HOOKS_DIR. core.hooksPath left unchanged."
  warn "Add these lines to the matching hooks there to enable the ledger:"
  echo "$HOOK_LINES"
else
  git -C "$TARGET" config core.hooksPath .githooks
  say "set      git core.hooksPath = .githooks"
fi

# 5. Choose where the ledger lives (local or shared) and write the AI tool rule files.
(cd "$TARGET" && bash .ai_ledger/scripts/set-mode.sh "$MODE")
echo ""
echo "Done. Work with any AI tool as usual; it logs every change to .ai_ledger/evolution_log.md."
echo "Read the \"Request vs Result\" section of each entry to see whether the AI did what you asked."

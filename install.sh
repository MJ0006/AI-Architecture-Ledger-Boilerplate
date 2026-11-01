#!/usr/bin/env bash
# AI Architecture Ledger installer (macOS / Linux / Git Bash on Windows).
#
# Usage:
#   ./install.sh [--local | --shared] [--update] [path/to/your/project]   # from a clone of this repo
#   curl -fsSL https://raw.githubusercontent.com/MJ0006/AI-Architecture-Ledger/main/install.sh | bash
#
# Mode (default: auto): ledger files are pushed with your code ONLY if 'origin' is a
# confirmed private GitHub/GitLab repo; otherwise they stay on this computer.
# Safe to re-run: existing files are never overwritten, except with --update, which refreshes the
# boilerplate's own files (hooks, scripts, rules) and never touches your ledger entries.
set -euo pipefail

REPO_URL="https://github.com/MJ0006/AI-Architecture-Ledger.git"
MODE=auto
UPDATE=0
TARGET_ARG=.
for arg in "$@"; do
  case "$arg" in
    -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
    --update)  UPDATE=1 ;;
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

# An update keeps the current mode unless --local / --shared was given.
if [ "$UPDATE" = 1 ] && [ "$MODE" = auto ]; then
  MODE=$(git -C "$TARGET" config --get ailedger.mode || echo auto)
fi

# Shared mode needs a confirmed private repo: check before changing anything.
if [ "$MODE" = shared ]; then
  VIS=$(cd "$TARGET" && bash "$TEMPLATE/.ai_ledger/scripts/visibility.sh")
  if [ "$VIS" != private ]; then
    echo "Error: --shared needs 'origin' to be a confirmed private GitHub/GitLab repository (result: $VIS)." >&2
    echo "Nothing was changed. Run without --shared to keep the ledger on this computer." >&2
    exit 1
  fi
fi

# 3. Copy template files without overwriting anything.
DATE=$(date '+%Y-%m-%d %H:%M')
(cd "$TEMPLATE" && find . -type f | sed 's|^\./||') | while IFS= read -r rel; do
  dest="$TARGET/$rel"
  if [ -e "$dest" ]; then
    # --update: refresh the boilerplate's own files. The ledger itself is never replaced.
    if [ "$UPDATE" = 1 ] && [ "$rel" != ".ai_ledger/evolution_log.md" ] && ! cmp -s "$TEMPLATE/$rel" "$dest" \
       && { [ "${rel#.githooks/}" = "$rel" ] || grep -q "AI Architecture Ledger" "$dest"; }; then
      if [ "$rel" = ".ai_ledger/agent_directives.md" ]; then
        cp "$dest" "$dest.old"
        warn "Your previous rules were saved as $rel.old. Re-apply any changes you had made."
      fi
      cp "$TEMPLATE/$rel" "$dest"
      say "updated  $rel"
      continue
    fi
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

# 4. Activate the hooks, unless another hook setup (Husky, .git/hooks) already exists.
#    check-setup.sh (run at the end) prints the lines to add in that case.
HOOKS_DIR=$(cd "$TARGET" && git rev-parse --git-path hooks)
EXISTING=$(cd "$TARGET" && for h in pre-commit pre-push post-commit; do [ -e "$HOOKS_DIR/$h" ] && echo "$h"; done || true)
if [ -z "$(git -C "$TARGET" config --get core.hooksPath)" ] && [ -z "$EXISTING" ]; then
  git -C "$TARGET" config core.hooksPath .githooks
  say "set      git core.hooksPath = .githooks"
fi

# 5. Choose where the ledger lives (local or shared) and write the AI tool rule files.
(cd "$TARGET" && bash .ai_ledger/scripts/set-mode.sh "$MODE")
echo ""
(cd "$TARGET" && bash .ai_ledger/scripts/check-setup.sh) || true
echo ""
echo "Done. Work with any AI tool as usual; it logs every change to .ai_ledger/evolution_log.md."
echo "Read the \"Request vs Result\" section of each entry to see whether the AI did what you asked."

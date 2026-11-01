#!/usr/bin/env bash
# AI Architecture Ledger installer (macOS / Linux / Git Bash on Windows).
#
# Usage:
#   ./install.sh [path/to/your/project]      # from a clone of this repo
#   curl -fsSL https://raw.githubusercontent.com/MJ0006/AI-Architecture-Ledger/main/install.sh | bash
#
# Safe to re-run: existing files are never overwritten. Only the marked
# "ai-ledger" blocks inside AI tool instruction files are refreshed.
set -euo pipefail

REPO_URL="${AI_LEDGER_REPO:-https://github.com/MJ0006/AI-Architecture-Ledger.git}"
START_MARK="<!-- ai-ledger:start (generated from .ai_ledger/agent_directives.md; edit that file, then re-run the installer) -->"
END_MARK="<!-- ai-ledger:end -->"

case "${1:-}" in -h|--help) sed -n '2,9p' "$0"; exit 0 ;; esac

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
TARGET_ARG="${1:-.}"
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
    if [ "$rel" = ".githooks/pre-commit" ] && ! grep -q "AI Architecture Ledger" "$dest"; then
      warn "Your existing .githooks/pre-commit is not the ledger hook. Merge in the checks from"
      warn "template/.githooks/pre-commit in the AI Architecture Ledger repo."
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
chmod +x "$TARGET/.githooks/pre-commit" "$TARGET/.ai_ledger/scripts/archive.sh" 2>/dev/null || true

# 4. Write the rules into every AI tool's auto-loaded instruction file.
BLOCK=$(mktemp)
{ echo "$START_MARK"; cat "$TARGET/.ai_ledger/agent_directives.md"; echo "$END_MARK"; } > "$BLOCK"

# upsert_block <file> [frontmatter]: create the file if missing, then insert or refresh the marked block.
upsert_block() {
  local file="$TARGET/$1" frontmatter="${2:-}" action
  mkdir -p "$(dirname "$file")"
  if [ ! -f "$file" ]; then
    [ -n "$frontmatter" ] && printf '%b\n' "$frontmatter" > "$file" || : > "$file"
    action="created "
  fi
  if grep -qF "<!-- ai-ledger:start" "$file"; then
    awk -v block="$BLOCK" '
      /<!-- ai-ledger:start/ { while ((getline l < block) > 0) print l; close(block); skip = 1; next }
      /<!-- ai-ledger:end -->/ { skip = 0; next }
      !skip { print }
    ' "$file" > "$file.tmp" && cat "$file.tmp" > "$file" && rm -f "$file.tmp"
    action="${action:-updated }"
  else
    [ -s "$file" ] && printf '\n' >> "$file"
    cat "$BLOCK" >> "$file"
    action="${action:-appended}"
  fi
  say "$action $1"
}

upsert_block "AGENTS.md"                         # Codex, OpenCode, Cursor, Copilot agent, Windsurf, Zed, Jules, Aider...
upsert_block "CLAUDE.md"                         # Claude Code
upsert_block "GEMINI.md"                         # Gemini CLI / Gemini Code Assist
upsert_block ".github/copilot-instructions.md"   # GitHub Copilot (VS Code, JetBrains, Visual Studio)
upsert_block ".cursor/rules/ai-ledger.mdc"   "---\ndescription: AI Architecture Ledger rules\nalwaysApply: true\n---\n"
upsert_block ".windsurf/rules/ai-ledger.md"  "---\ntrigger: always_on\n---\n"
rm -f "$BLOCK"

# 5. Keep hook scripts on LF line endings (CRLF breaks bash on Windows checkouts).
GA="$TARGET/.gitattributes"
if ! grep -qF ".githooks/* text eol=lf" "$GA" 2>/dev/null; then
  [ -s "$GA" ] && printf '\n' >> "$GA"
  printf '%s\n' "# AI Architecture Ledger: hook scripts must keep LF line endings" \
    ".githooks/* text eol=lf" ".ai_ledger/scripts/*.sh text eol=lf" >> "$GA"
  say "updated  .gitattributes"
fi

# 6. Activate the hook without breaking any hook setup that already exists.
CURRENT_HOOKS=$(git -C "$TARGET" config --get core.hooksPath || true)
OLD_HOOK="$(git -C "$TARGET" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || echo "$TARGET/.git")/hooks/pre-commit"
if [ "$CURRENT_HOOKS" = ".githooks" ]; then
  say "ok       git core.hooksPath already set to .githooks"
elif [ -n "$CURRENT_HOOKS" ]; then
  warn "git core.hooksPath is already '$CURRENT_HOOKS' (e.g. Husky). Left unchanged."
  warn "Add this line to $CURRENT_HOOKS/pre-commit to enable the ledger check:"
  warn "    .githooks/pre-commit || exit 1"
elif [ -f "$OLD_HOOK" ]; then
  warn "An existing hook was found at $OLD_HOOK. core.hooksPath left unchanged."
  warn "Add this line to that hook to enable the ledger check:  .githooks/pre-commit || exit 1"
else
  git -C "$TARGET" config core.hooksPath .githooks
  say "set      git core.hooksPath = .githooks"
fi

cat <<EOF

Done. Next steps:
  1. Commit the new files:  git add -A && git commit -m "Add AI Architecture Ledger"
  2. Work with any AI tool as usual. It will log every change to .ai_ledger/evolution_log.md.
  3. Read the "Request vs Result" section of each entry to see whether the AI did what you asked.
  Teammates: after cloning, run  git config core.hooksPath .githooks  (or re-run this installer).
EOF

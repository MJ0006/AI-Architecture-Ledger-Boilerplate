#!/usr/bin/env bash
# Checks that the ledger hooks are active on this computer.
# Prints "OK" (exit 0) or what is wrong and how to fix it (exit 1).
# Works with core.hooksPath=.githooks, Husky-style hook folders, and .git/hooks.
# Usage: bash .ai_ledger/scripts/check-setup.sh
cd "$(git rev-parse --show-toplevel)" || exit 1

ACTIVE=$(git rev-parse --git-path hooks)   # the folder Git really runs hooks from
PROBLEMS=""
for h in pre-commit pre-push post-commit; do
  if [ ! -x ".githooks/$h" ]; then
    PROBLEMS="$PROBLEMS\n  - .githooks/$h is missing or not executable"
  elif [ ! -x "$ACTIVE/$h" ]; then
    PROBLEMS="$PROBLEMS\n  - Git does not run a $h hook"
  elif ! grep -qs -e "AI Architecture Ledger" -e ".githooks/$h" "$ACTIVE/$h"; then
    PROBLEMS="$PROBLEMS\n  - $ACTIVE/$h does not call .githooks/$h"
  fi
done

if [ -z "$PROBLEMS" ]; then
  echo "OK: AI ledger hooks are active."
  exit 0
fi

printf 'The AI ledger checks are OFF on this computer:%b\n\nFix:\n' "$PROBLEMS"
if [ -n "$(git config --get core.hooksPath)" ] || ls "$ACTIVE"/pre-commit "$ACTIVE"/pre-push "$ACTIVE"/post-commit >/dev/null 2>&1; then
  echo "  Add these lines to the matching hook files in $ACTIVE/:"
  echo '    pre-commit:   [ ! -x .githooks/pre-commit ] || .githooks/pre-commit || exit 1'
  echo '    pre-push:     [ ! -x .githooks/pre-push ] || .githooks/pre-push "$@" || exit 1'
  echo '    post-commit:  [ ! -x .githooks/post-commit ] || .githooks/post-commit'
else
  echo "  git config core.hooksPath .githooks"
fi
echo "  (If .githooks/ files are missing, re-run the AI Architecture Ledger installer.)"
exit 1

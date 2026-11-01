#!/usr/bin/env bash
# Prints "public", "private" or "unknown" for a git remote (default: origin).
# Asks the GitHub / GitLab API without logging in. Other hosts, no remote,
# or no internet => "unknown", which the ledger treats as NOT private.
# Usage: bash .ai_ledger/scripts/visibility.sh [remote-url]

URL="${1:-$(git remote get-url origin 2>/dev/null)}"
[ -n "$URL" ] || { echo unknown; exit 0; }

# Normalize https://[user@]host/owner/repo(.git), ssh://git@host/owner/repo, git@host:owner/repo
p="${URL%/}"; p="${p%.git}"
case "$p" in
  *://*) p="${p#*://}"; p="${p#*@}" ;;
  *@*:*) p="${p#*@}"; p="${p/://}" ;;
  *)     echo unknown; exit 0 ;;
esac
host="${p%%/*}"; host="${host%%:*}"; path="${p#*/}"

case "$host" in
  github.com) api="https://api.github.com/repos/$path" ;;
  gitlab.com) api="https://gitlab.com/api/v4/projects/$(printf '%s' "$path" | sed 's|/|%2F|g')" ;;
  *)          echo unknown; exit 0 ;;
esac

command -v curl >/dev/null 2>&1 || { echo unknown; exit 0; }
RESPONSE=$(curl -s --max-time 10 -w '\n%{http_code}' "$api" 2>/dev/null)
CODE=$(printf '%s' "$RESPONSE" | tail -n 1)
BODY=$(printf '%s' "$RESPONSE" | sed '$d')

case "$CODE" in
  404) echo private ;;   # anonymous visitors can't see private repos
  200)
    if printf '%s' "$BODY" | grep -qE '"private": *false|"visibility": *"public"'; then echo public
    elif printf '%s' "$BODY" | grep -qE '"private": *true|"visibility": *"(private|internal)"'; then echo private
    else echo unknown; fi ;;
  *) echo unknown ;;     # offline, rate-limited, etc.
esac

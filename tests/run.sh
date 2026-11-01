#!/usr/bin/env bash
# End-to-end tests for the AI Architecture Ledger boilerplate.
# Each test installs into a throwaway git repo and checks real git behaviour.
# GitHub/GitLab answers are simulated with a stub `curl` (FAKE_VIS=public|private|offline);
# the real API check runs separately in CI.
# Usage: bash tests/run.sh      (exit code 0 = all passed)
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
STUB=$(mktemp -d); cat > $STUB/curl <<'EOF'
#!/usr/bin/env bash
case "${FAKE_VIS:-offline}" in public) printf '{"private": false}\n200' ;; private) printf '{"message":"Not Found"}\n404' ;; *) exit 7 ;; esac
EOF
chmod +x $STUB/curl; export PATH="$STUB:$PATH"; INST="$REPO_ROOT/install.sh"
PASS=0; FAILN=0
ok()   { if eval "$2" >/dev/null 2>&1; then echo "  PASS  $1"; PASS=$((PASS+1)); else echo "  FAIL  $1"; FAILN=$((FAILN+1)); fi; }
newrepo() { local d=$(mktemp -d)/$1; mkdir -p $d && cd $d && git init -q -b main && git config user.email t@t && git config user.name t; }
entry() { printf '\n## [2026-11-01 10:%02d] %s\n- **Files:** `app.py`\n### Request\n> r\n### Assumptions\nNone.\n### Changes\n- c\n### Request vs Result\nMatches the request.\n### Justification\nj\n### Alternatives\n- a\n### Concepts\nN/A\n### How to Verify\nv\n' "$((RANDOM%60))" "$1" >> .ai_ledger/evolution_log.md; }
subst() { sed "$1" "$2" > "$2.tmp" && mv "$2.tmp" "$2"; }   # in-place edit that works on GNU and BSD sed
pp() { echo "refs/heads/main $(git rev-parse HEAD) refs/heads/main ${1:-0000000000000000000000000000000000000000}" | .githooks/pre-push origin "${2:-https://github.com/me/app}"; }

echo "T1 local install"; newrepo t1; echo a>app.py; git add -A; git commit --no-verify -qm base
$INST >/dev/null
ok "nothing ledger-related in git status" '[ -z "$(git status --porcelain)" ]'
ok "check-setup OK" 'bash .ai_ledger/scripts/check-setup.sh | grep -q OK'
ok "backup created" '[ -f .git/ai-ledger-backup/evolution_log.md ]'

echo "T2 local commit flow"; echo b>>app.py; git add app.py
ok "blocked without entry" '! git commit -qm x'
entry one; ok "passes with unstaged entry" 'git commit -qm x'
ok "summary printed" 'echo c>>app.py; git add app.py; entry two; git commit -qm y 2>&1 | grep -q "AI Ledger: latest entry"'
echo d>>app.py; git add app.py; ok "blocked again without new entry" '! git commit -qm z'
git reset -q app.py; git checkout -q app.py

echo "T2b Assumptions heading enforced"
echo e>>app.py; git add app.py; printf '\n## [2026-11-01 11:00] NoAssump\n### Request\n> r\n### Changes\n- c\n### Request vs Result\nMatches.\n### Justification\nj\n### Alternatives\n- a\n### Concepts\nN/A\n### How to Verify\nv\n' >> .ai_ledger/evolution_log.md
ok "entry without Assumptions is blocked, and says so" 'git commit -qm x 2>&1 | grep -q "missing: .### Assumptions."'
entry withassump; ok "passes once a complete entry is added" 'git commit -qm x'

echo "T3 git clean -fdx recovery"; git clean -fdxq
ok "ledger wiped by git clean" '[ ! -e .ai_ledger ]'
mkdir -p .ai_ledger && cp -R .git/ai-ledger-backup/. .ai_ledger/
ok "entries restored from backup" 'grep -q "] two" .ai_ledger/evolution_log.md'
$INST >/dev/null
ok "re-install restores hooks; check-setup OK" 'bash .ai_ledger/scripts/check-setup.sh | grep -q OK'
ok "restored entries kept by re-install" 'grep -q "] two" .ai_ledger/evolution_log.md'

echo "T4 check-setup with .git/hooks"; newrepo t4; printf '#!/bin/sh\nexit 0\n' > .git/hooks/pre-commit; chmod +x .git/hooks/pre-commit
$INST >/dev/null
ok "reports OFF when not wired" '! bash .ai_ledger/scripts/check-setup.sh'
printf '[ ! -x .githooks/pre-commit ] || .githooks/pre-commit || exit 1\n' >> .git/hooks/pre-commit
printf '#!/bin/sh\n[ ! -x .githooks/pre-push ] || .githooks/pre-push "$@" || exit 1\n' > .git/hooks/pre-push
printf '#!/bin/sh\n[ ! -x .githooks/post-commit ] || .githooks/post-commit\n' > .git/hooks/post-commit; chmod +x .git/hooks/*
ok "reports OK once wired (no false alarm)" 'bash .ai_ledger/scripts/check-setup.sh | grep -q OK'

echo "T5 shared mode + pre-push"; newrepo t5; git remote add origin https://github.com/me/app
echo a>app.py; git add -A; git commit --no-verify -qm base
FAKE_VIS=private $INST >/dev/null; git add -A
ok "shared install commit passes" 'git commit -qm ledger'
ok "ledger is tracked" 'git ls-files --error-unmatch .ai_ledger/evolution_log.md'
ok "push allowed when private" 'FAKE_VIS=private pp'
ok "push blocked when public"  '! FAKE_VIS=public pp'
ok "push blocked when offline" '! FAKE_VIS=offline pp'

echo "T6 leak via older unpushed commits"; newrepo t6; R=$(mktemp -d)/r.git; git init -q --bare $R
git remote add origin https://github.com/me/app
echo a>app.py; git add -A; git commit --no-verify -qm base
FAKE_VIS=private $INST >/dev/null; git add -A; git commit -qm ledger >/dev/null
git push -q --no-verify $R main 2>/dev/null; git fetch -q $R main:refs/remotes/origin/main
echo b>>app.py; git add app.py; entry secret; git add .ai_ledger/evolution_log.md; git commit -qm "unpushed, has ledger" >/dev/null
FAKE_VIS=public bash .ai_ledger/scripts/set-mode.sh local >/dev/null; git commit -qm "local-only" >/dev/null
ok "tip has no ledger" '[ -z "$(git ls-tree HEAD .ai_ledger)" ]'
ok "push BLOCKED (older commit has ledger)" '! pp $(git rev-parse origin/main) | grep -q "older unpushed"; pp $(git rev-parse origin/main) | grep -q "older unpushed"'
git reset -q --soft origin/main; git commit -q --no-verify -m "squashed" >/dev/null
ok "after squash: push allowed" 'pp $(git rev-parse origin/main)'
newrepo t6b; R2=$(mktemp -d)/r.git; git init -q --bare $R2; git remote add origin https://github.com/me/app
echo a>app.py; git add -A; git commit --no-verify -qm base
FAKE_VIS=private $INST >/dev/null; git add -A; git commit -qm ledger >/dev/null
git push -q --no-verify $R2 main 2>/dev/null; git fetch -q $R2 main:refs/remotes/origin/main
FAKE_VIS=public bash .ai_ledger/scripts/set-mode.sh local >/dev/null; git commit -qm "local-only" >/dev/null 2>&1
ok "just switched (remote has ledger, 1 deleting commit): push allowed" 'pp $(git rev-parse origin/main)'

echo "T7 set-mode local keeps user's unrelated edits unstaged"; newrepo t7; git remote add origin https://github.com/me/app
printf '# Team rules\nUse tabs.\n' > CLAUDE.md; echo a>app.py; git add -A; git commit --no-verify -qm base
FAKE_VIS=private $INST >/dev/null; git add -A; git commit -qm ledger >/dev/null
echo "WIP: my unfinished note" >> CLAUDE.md
FAKE_VIS=public bash .ai_ledger/scripts/set-mode.sh local >/dev/null
ok "staged CLAUDE.md = original rules only" '[ "$(git show :CLAUDE.md)" = "$(printf "# Team rules\nUse tabs.")" ]'
ok "WIP edit still on disk, unstaged" 'grep -q WIP CLAUDE.md && git diff --name-only | grep -qx CLAUDE.md'
ok "switch commit passes" 'git commit -qm local'
ok "committed CLAUDE.md has no rules" '! git show HEAD:CLAUDE.md | grep -q ai-ledger'

echo "T8 broken markers are never touched"; newrepo t8
printf '# Mine\n<!-- ai-ledger:start old\nkeep this line\nand this\n' > CLAUDE.md; BEFORE=$(mktemp); cp CLAUDE.md $BEFORE
$INST >/dev/null
ok "CLAUDE.md unchanged" 'cmp -s CLAUDE.md $BEFORE'
ok "CLAUDE.md not hidden from git" '! grep -qx /CLAUDE.md .git/info/exclude'

echo "T9 --shared on a public repo changes nothing"; newrepo t9; git remote add origin https://github.com/me/app
ok "installer fails" '! FAKE_VIS=public $INST --shared'
ok "no files created" '[ ! -e .ai_ledger ] && [ -z "$(git config core.hooksPath)" ]'

echo "T10 re-run, Husky, archive"; newrepo t10; $INST >/dev/null; $INST >/dev/null
ok "exclude block not duplicated" '[ "$(grep -c ai-ledger:start .git/info/exclude)" = 1 ]'
ok "rules block not duplicated" '[ "$(grep -c ai-ledger:start AGENTS.md)" = 1 ]'
subst 's/^## \[2026-11-01/## [2026-09-15/' .ai_ledger/evolution_log.md
ok "archive moves old month" 'bash .ai_ledger/scripts/archive.sh | grep -q "Archived 1 entry" && [ -f .ai_ledger/archive/2026-09.md ]'
newrepo t10b; git config core.hooksPath .husky
ok "husky: hooksPath untouched, lines printed" '$INST | grep -q "pre-push:" && [ "$(git config core.hooksPath)" = .husky ]'

echo "T11 amend is blocked (documented)"; cd $(mktemp -d) && git init -q && git config user.email t@t && git config user.name t && $INST >/dev/null
echo a>f; git add f; entry e; git commit -qm one >/dev/null; echo b>g; git add g
ok "amend without entry is blocked" '! git commit -q --amend --no-edit'

echo "T12 --update refreshes boilerplate files, keeps the ledger and mode"; newrepo t12; git remote add origin https://github.com/me/app
echo a>app.py; git add -A; git commit --no-verify -qm base
FAKE_VIS=private $INST >/dev/null; git add -A; git commit -qm ledger >/dev/null 2>&1
echo "# my custom rule" >> .ai_ledger/agent_directives.md
printf '#!/usr/bin/env bash\n# AI Architecture Ledger (old version)\nexit 0\n' > .githooks/pre-commit
entry keepme
ok "update succeeds" 'FAKE_VIS=private $INST --update'
ok "hook replaced with current version" 'cmp -s .githooks/pre-commit "$REPO_ROOT/template/.githooks/pre-commit"'
ok "old rules saved with the custom line" 'grep -q "my custom rule" .ai_ledger/agent_directives.md.old'
ok "rules replaced with current version" 'cmp -s .ai_ledger/agent_directives.md "$REPO_ROOT/template/.ai_ledger/agent_directives.md"'
ok "ledger entries kept" 'grep -q "] keepme" .ai_ledger/evolution_log.md'
ok "mode stays shared" '[ "$(git config ailedger.mode)" = shared ]'
ok "AI tool files carry the new rules" 'grep -q "### Assumptions" CLAUDE.md'

echo "T13 analysis log and handoff"; newrepo t13; echo a>app.py; git add -A; git commit --no-verify -qm base
$INST >/dev/null
ok "analysis_log.md and handoff.md installed" '[ -f .ai_ledger/analysis_log.md ] && [ -f .ai_ledger/handoff.md ]'
ok "AI rules include the handoff triggers" 'grep -q "close the chat" CLAUDE.md && grep -q "analysis_log.md" AGENTS.md'
ok "installer tells the user to start a new conversation" '$INST | grep -q "Start a NEW conversation"'
printf '\n## [2026-09-10 10:00] Old UI audit\n### Request\n> audit\n### Findings\nok\n' >> .ai_ledger/analysis_log.md
ok "archive moves old analysis entries to archive/analysis/" 'bash .ai_ledger/scripts/archive.sh | grep -q "1 entry from analysis_log.md" && [ -f .ai_ledger/archive/analysis/2026-09.md ]'
echo b>>app.py; git add app.py
ok "archived analysis entries don't count as code entries (commit still blocked)" '! git commit -qm x'
git reset -q app.py; git checkout -q app.py
echo "my audit notes" >> .ai_ledger/analysis_log.md; echo "my handoff" > .ai_ledger/handoff.md
ok "--update keeps the user's analysis log and handoff" '$INST --update >/dev/null && grep -q "my audit notes" .ai_ledger/analysis_log.md && grep -q "my handoff" .ai_ledger/handoff.md'

echo; echo "RESULT: $PASS passed, $FAILN failed"
[ "$FAILN" -eq 0 ]

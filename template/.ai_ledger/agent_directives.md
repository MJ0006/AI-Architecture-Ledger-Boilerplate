# AI Architecture Ledger: Mandatory Workspace Rules

This repository keeps a self-documenting **Architecture Ledger**. These rules apply to
every AI agent and every folder in this repository, including subfolders, packages, and
modules, even if the user never mentions the ledger.

- Ledger file: `.ai_ledger/evolution_log.md` at the **repository root**
  (find the root with `git rev-parse --show-toplevel` or by walking up to the folder that contains `.ai_ledger/`).
- Older entries: `.ai_ledger/archive/YYYY-MM.md` (read only when you need older history).

## 1. Before you change anything

1. Read the most recent entries in `.ai_ledger/evolution_log.md` for project context.
2. If the log contains entries from a previous month, run `bash .ai_ledger/scripts/archive.sh` first.
3. If the request is ambiguous or could be read more than one way, **ask the user before writing code**.
   List the interpretations. Do not guess silently.

## 2. While you work

- Do what was asked: no more, no less.
- If you must deviate (something is impossible, unsafe, or a better path exists), say so in chat
  and record it in the **Request vs Result** section.

## 3. After every change (before saying "done" or committing)

Append **one** entry per task to the **end** of `.ai_ledger/evolution_log.md`, using the exact
format below. The pre-commit hook rejects commits whose new entry is missing any of these headings.

```markdown
## [YYYY-MM-DD HH:MM] <Component / Feature Name>
- **Area:** `<folder or module touched, e.g. packages/api>`
- **Files:** `<path/one>`, `<path/two>`

### Request
> <The user's request, quoted word-for-word.>

### Changes
<What you actually did, file by file, in 1–5 bullets.>

### Request vs Result
<"Matches the request." OR list each difference: what was asked, what was done, and why.
Also list anything requested but NOT done.>

### Justification
<Why the chosen method was built exactly this way: an explicit technical breakdown.>

### Alternatives
<Other structural or algorithmic methods that are viable for this exact logic, one per bullet.>

### Concepts
<Plain-English explanation of each pattern, library, or technique used, written for a beginner. One or two lines each.>

### How to Verify
<Concrete steps or commands the user can run to confirm it works.>
```

## 4. Writing rules

- **Request:** quote the user's words exactly. Do not paraphrase.
- **Request vs Result:** be honest. This section shows the user where their intent and your output
  diverged. Never hide a deviation.
- **Alternatives:** list the viable alternatives only. Do NOT spend tokens explaining why they were rejected.
- **Concepts / How to Verify:** write for someone learning. Avoid unexplained jargon.
- Keep entries concise, technical, and tied to real file paths.
- For trivial changes (typo, formatting), keep every heading but write `N/A` under Alternatives and Concepts.
- The ledger is **append-only**. Never edit or delete earlier entries. Only the archive script moves them.
- If the pre-commit hook blocks a commit, fix the ledger entry. **Never** bypass it with `--no-verify`.
- At the end of your reply, give the user a one-line Request vs Result summary.

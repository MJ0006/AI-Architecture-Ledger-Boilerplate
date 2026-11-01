# AI Ledger: Mandatory Workspace Rules

This repository keeps a self-documenting **AI Ledger**. These rules apply to
every AI agent and every folder in this repository, including subfolders, packages, and
modules, even if the user never mentions the ledger.

All ledger files are in `.ai_ledger/` at the **repository root** (find the root with
`git rev-parse --show-toplevel` or by walking up to the folder that contains `.ai_ledger/`):

- `evolution_log.md`: one entry per **code change** (section 3).
- `analysis_log.md`: one entry per **substantial non-code task** (section 4).
- `handoff.md`: where the work stands, rewritten on request (section 5).
- `archive/`: older months (read only when you need older history).

## 1. Before every task

1. Check that the ledger hooks are on: run `bash .ai_ledger/scripts/check-setup.sh`. If it does not
   print `OK`, show its message to the user, then continue with the task. (Skip this if you cannot run commands.)
2. At the start of a conversation, read `.ai_ledger/handoff.md` first: it says where the last one left off.
   Then read the most recent entries in `evolution_log.md` and `analysis_log.md` for project context.
3. If either log contains entries from a previous month, run `bash .ai_ledger/scripts/archive.sh` first.
4. **Think before coding.**
   - State your assumptions. If anything is uncertain, ask instead of guessing.
   - If the request can be read more than one way, list the interpretations and ask. Don't pick one silently.
   - If a simpler or better approach exists, say so.
   - If you are confused, name what is unclear and stop until the user answers.
5. **Define success.** Turn the request into verifiable goals (e.g. "write a test that reproduces the
   bug, then make it pass"). Then work and re-check on your own until they pass.

## 2. While you work

- **Simplicity first.** Write the minimum code that solves the problem. Don't add unrequested features,
  configuration options, future-proofing abstractions, or error handling for impossible cases.
  If it can be done in far fewer lines, rewrite it.
- **Surgical changes.** Touch only the files and lines the task needs. No drive-by refactoring,
  reformatting, or "improving" code, comments, or formatting that wasn't broken. Remove variables,
  functions, or imports that *your* change made unused. Don't delete pre-existing dead code unless asked.
- If you must deviate (something is impossible, unsafe, or a better path exists), say so in chat
  and record it in the **Request vs Result** section.

## 3. After every code change (before saying "done" or committing)

Append **one** entry per task to the **end** of `.ai_ledger/evolution_log.md`, using the exact
format below. The pre-commit hook rejects commits whose new entry is missing any of these headings.

```markdown
## [YYYY-MM-DD HH:MM] <Component / Feature Name>
- **Area:** `<folder or module touched, e.g. packages/api>`
- **Files:** `<path/one>`, `<path/two>`

### Request
> <The user's request, quoted word-for-word.>

### Assumptions
<What you assumed, and what you asked the user to clarify. "None" if nothing was uncertain.>

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
<The success criteria you set, and the steps or commands (tests preferred) the user can run to confirm them.>
```

## 4. After substantial non-code work

Audits (e.g. UI/UX, security, performance), code reviews, investigations, project status checks, and plans
change no code but are still worth recording. Append **one** entry to the **end** of
`.ai_ledger/analysis_log.md`. Skip quick questions (e.g. "what does this function do?").

```markdown
## [YYYY-MM-DD HH:MM] <Topic, e.g. UI/UX audit of the checkout page>
- **Area:** `<folder or module looked at>`

### Request
> <The user's request, quoted word-for-word.>

### Assumptions
<What you assumed, and what you asked the user to clarify. "None" if nothing was uncertain.>

### Findings
<What you found, most important first, with file paths. Plain English.>

### Request vs Result
<"Matches the request." OR what was asked but not covered, and why.>

### Recommended next steps
<Concrete actions, most important first. "None" if nothing is needed.>
```

## 5. Handoff (when the user says "handoff", "close the chat", or "completed")

**Rewrite** `.ai_ledger/handoff.md` (replace the whole file, at most about 60 lines) so the next conversation,
in any AI tool, can continue without the chat history. Then tell the user it is saved.

```markdown
# Handoff ([YYYY-MM-DD HH:MM])

## Goal
<What the user is trying to achieve overall.>

## What the user asked (in order)
- <Each request, briefly quoted.>

## Decisions made (and why)
- <Choices the user made or approved.>

## Done
- <Finished work, with ledger entry dates.>

## Open questions
- <Anything waiting on the user. "None" if nothing.>

## Next steps
1. <What to do next.>

## User preferences
- <How the user likes to work, e.g. "ask before big changes".>
```

## 6. Writing rules

- **Request:** quote the user's words exactly. Do not paraphrase.
- **Never write secrets** (API keys, passwords, tokens, connection strings, personal data) into any
  ledger file, even when quoting the request. Replace them with `[REDACTED]`.
- **Request vs Result:** be honest. This section shows the user where their intent and your output
  diverged. Never hide a deviation.
- **Alternatives:** list the viable alternatives only. Do NOT spend tokens explaining why they were rejected.
- **Concepts / How to Verify:** write for someone learning. Avoid unexplained jargon.
- Keep entries concise, technical, and tied to real file paths.
- For trivial changes (typo, formatting), keep every heading. Write `None` under Assumptions and `N/A`
  under Alternatives and Concepts.
- `evolution_log.md` and `analysis_log.md` are **append-only**. Never edit or delete earlier entries. Only the
  archive script moves them. `handoff.md` is the one file you rewrite.
- If a ledger hook blocks a commit or push, fix the cause. **Never** bypass it with `--no-verify`.
- If git ignores the ledger files (local mode), never `git add -f` them. They must stay on this computer.
- At the end of your reply, give the user a one-line Request vs Result summary.

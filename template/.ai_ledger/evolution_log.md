# Evolution Log

Append-only record of every change made in this repository: what was asked, what was done,
why it was done that way, and how to check it. Rules: `.ai_ledger/agent_directives.md`.
Older months: `.ai_ledger/archive/`.

**How to read an entry:** start with **Request vs Result** to see whether the AI did what you
asked. Then read **Concepts** to learn the techniques it used, and **How to Verify** to check it yourself.

---

## [{{DATE}}] AI Ledger installed
- **Area:** `/` (repository root)
- **Files:** `.ai_ledger/`, `.githooks/pre-commit`, `.githooks/pre-push`, `.githooks/post-commit`, `.gitattributes`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, `.cursor/rules/ai-ledger.mdc`, `.windsurf/rules/ai-ledger.md`

### Request
> Install the AI Ledger.

### Assumptions
None.

### Changes
- Added `.ai_ledger/` with the rules, this log, an analysis log, a handoff note, a review prompt, and an archive script.
- Added `.githooks/` hooks: `pre-commit` blocks code commits that have no complete ledger entry,
  and `pre-push` keeps ledger files out of public repositories.
- Added (or appended to) the instruction files each AI tool reads automatically.

### Request vs Result
Matches the request.

### Justification
One master rules file (`agent_directives.md`) is copied into each tool's auto-loaded instruction
file, so every agent follows the same rules without manual copy-paste. A versioned hooks folder
(`core.hooksPath`) enforces the rules at commit time for every tool and every human.

### Alternatives
- Manual copy-paste of the rules into each AI tool's settings.
- Hook managers such as Husky, Lefthook, or the `pre-commit` framework.
- CI-only enforcement (a pull request check instead of a local hook).

### Concepts
- **Git hook:** a script Git runs automatically at certain moments. `pre-commit` runs before a commit is created, and a non-zero exit cancels the commit.
- **`core.hooksPath`:** a Git setting that tells Git to load hooks from a folder inside the repo, so the hooks can be committed and shared.
- **Agent instruction files:** files like `AGENTS.md` or `CLAUDE.md` that AI coding tools read automatically at the start of every session.

### How to Verify
- Run `git config core.hooksPath`. It should print `.githooks`.
- Change any code file and run `git commit`. The commit should be blocked until you add a ledger entry.

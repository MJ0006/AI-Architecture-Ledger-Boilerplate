# AI Architecture Ledger

A drop-in boilerplate that makes **any AI coding tool** document every change it makes:
**what you asked**, **what it actually did**, **why**, **what else it could have done**, and
**how to check it**. A Git hook enforces the rule, so no tool or person can skip it.

## Why this exists

"I asked the AI for X, but it did Y" is common, and it usually goes unnoticed until later.
The ledger fixes that by making the AI write down, for every task:

- **Your request, word for word,** next to **what it changed**.
- An honest **Request vs Result** section that says where it deviated and why.
- **Concepts** explained in plain English, so you learn the techniques it used instead of
  pasting code you don't understand.
- **How to Verify** steps, so you can confirm the result yourself.

Over time, the log becomes the project's architecture history and a record of how your
requests turn into code.

---

## Install

You need **Git**. Nothing else (no Node, no Python).

**macOS / Linux**
```bash
git clone https://github.com/MJ0006/AI-Architecture-Ledger.git
./AI-Architecture-Ledger/install.sh path/to/your/project
```

**Windows (PowerShell)**
```powershell
git clone https://github.com/MJ0006/AI-Architecture-Ledger.git
.\AI-Architecture-Ledger\install.ps1 path\to\your\project
```

**One-liners** (run inside your project folder)
```bash
curl -fsSL https://raw.githubusercontent.com/MJ0006/AI-Architecture-Ledger/main/install.sh | bash
```
```powershell
irm https://raw.githubusercontent.com/MJ0006/AI-Architecture-Ledger/main/install.ps1 | iex
```

Then commit the new files: `git add -A && git commit -m "Add AI Architecture Ledger"`.

### What the installer does

- Installs at your **repository root**, even if you run it from a subfolder.
- **Never overwrites** your files. Existing files are kept, and for `CLAUDE.md`, `AGENTS.md`, and the
  other tool files it **appends** a marked block (`<!-- ai-ledger:start -->` … `<!-- ai-ledger:end -->`).
- Is **safe to re-run.** Re-running refreshes only those marked blocks.
- Sets `git config core.hooksPath .githooks`, unless you already use Husky or another hook
  setup. In that case it changes nothing and prints the one line to add to your existing hook.
- Adds `.gitattributes` rules so the hook scripts keep LF line endings on Windows.

## What gets added to your project

```
your-project/
├── .ai_ledger/
│   ├── agent_directives.md   ← master rules (single source of truth; edit here)
│   ├── evolution_log.md      ← the ledger: append-only, one entry per task
│   ├── review_prompt.md      ← prompt for the pre-sprint review loop
│   ├── scripts/archive.sh    ← moves last month's entries to archive/
│   └── archive/YYYY-MM.md    ← created by the archive script
├── .githooks/pre-commit      ← blocks commits without a complete ledger entry
├── AGENTS.md                         ┐
├── CLAUDE.md                         │
├── GEMINI.md                         │ rules copied from agent_directives.md
├── .github/copilot-instructions.md   │ (each AI tool reads its own file automatically)
├── .cursor/rules/ai-ledger.mdc       │
└── .windsurf/rules/ai-ledger.md      ┘
```

### Supported AI tools

| File | Read automatically by |
|---|---|
| `AGENTS.md` | OpenAI Codex, OpenCode, Cursor, GitHub Copilot agent, Windsurf, Zed, Jules, and other tools that follow the AGENTS.md convention |
| `CLAUDE.md` | Claude Code (CLI, VS Code, JetBrains, desktop, web) |
| `GEMINI.md` | Gemini CLI, Gemini Code Assist |
| `.github/copilot-instructions.md` | GitHub Copilot in VS Code, JetBrains, Visual Studio |
| `.cursor/rules/ai-ledger.mdc` | Cursor (`alwaysApply: true`) |
| `.windsurf/rules/ai-ledger.md` | Windsurf (`trigger: always_on`) |

**Any other tool or chat AI:** paste `.ai_ledger/agent_directives.md` into its system or custom
instructions. The Git hook enforces the rules regardless of which tool wrote the code.

---

## How it works day to day

1. You ask your AI tool for something, in any folder of the project.
2. The AI reads the recent ledger entries for context. If your request is unclear, it asks
   before coding.
3. It makes the change, then appends an entry to `.ai_ledger/evolution_log.md`.
4. When you (or the AI) run `git commit`, the hook checks that code changes come with a **new,
   complete** entry. If they don't, the commit is blocked with a message that tells you (or the AI) exactly what's missing.

### Entry format

```markdown
## [2026-11-01 14:05] Login rate limiter
- **Area:** `packages/api`
- **Files:** `packages/api/middleware/rateLimit.ts`, `packages/api/server.ts`

### Request
> Add rate limiting to the login endpoint

### Changes
- Added a sliding-window limiter middleware (5 attempts / 15 min per IP).
- Registered it on `POST /login` only.

### Request vs Result
Differs: also added a `Retry-After` header (not requested) so clients know when to retry.

### Justification
In-memory sliding window: no new infrastructure, accurate at window edges, fine for one instance.

### Alternatives
- Fixed-window counter
- Token bucket
- Redis-backed limiter (`rate-limiter-flexible`)
- Reverse-proxy limiting (nginx `limit_req`)

### Concepts
- **Middleware:** a function that runs before your route handler and can stop the request.
- **Sliding window:** counts requests in the last N minutes, measured from *now*, not from the top of the hour.

### How to Verify
Run `curl -X POST localhost:3000/login` 6 times. The 6th call returns `429 Too Many Requests`.
```

The hook requires the `## [YYYY-MM-DD ...]` header and all seven `###` headings. It also **warns**
(without blocking) about staged files the entry never mentions.

---

## Learning from the ledger

- **Read Request vs Result first.** It is the quickest way to see whether the AI did what you asked.
- **When it says "Differs",** ask yourself whether the request was clear. Most mismatches come from
  missing details (which file, which behavior, what to leave alone). Write the next request with those details.
- **Read Concepts** to build vocabulary. Next time you can ask for "a sliding-window limiter as
  middleware" instead of "make login safer".
- **Read Alternatives** to see that there was a choice, so you can ask for a different approach.
- **Run How to Verify yourself.** Don't trust "done" until you have checked it.

## Monorepos and subfolders

There is one ledger at the repository root. The rules tell the AI to find it from any subfolder, and every entry records the
**Area** (folder or module) it touched. The hook always runs from the repository root, so it covers the
whole repository.

## Monthly archive

`evolution_log.md` holds the current month only, so it stays small enough for an AI to read in full.
At the start of a new month, the AI is instructed to run the archive script, or you can run it yourself:

```bash
bash .ai_ledger/scripts/archive.sh      # Windows: run in Git Bash
```

The script moves entries from earlier months into `.ai_ledger/archive/YYYY-MM.md`. Commits that touch only ledger files are never blocked.

## The self-improving loop

Before a new sprint or feature, tell your AI:
**"Follow `.ai_ledger/review_prompt.md`"**. It reads the ledger and reports:

- Request vs Result mismatches, with tips on writing better requests
- Recurring hurdles and technical debt
- Concepts worth studying
- Suggested rule updates for `agent_directives.md`. It only proposes them; you decide.

---

## Teammates and fresh clones

`core.hooksPath` is a local Git setting and isn't cloned. After cloning, each person runs:

```bash
git config core.hooksPath .githooks
```

Re-running the installer also does this.

## Customizing

- **Change the rules:** edit `.ai_ledger/agent_directives.md`, then re-run the installer to update every
  AI tool's file.
- **Rename or add headings:** update them in `agent_directives.md` **and** in `REQUIRED_HEADINGS` at
  the top of `.githooks/pre-commit`. The two lists must match.

## Troubleshooting

| Problem | Fix |
|---|---|
| Hook doesn't run | Run `git config core.hooksPath`. It should print `.githooks`. On macOS/Linux, also run `chmod +x .githooks/pre-commit`. |
| `bash\r: No such file or directory` | The hook has Windows line endings. Run `rm .githooks/pre-commit && git checkout -- .githooks/pre-commit`. The `.gitattributes` rules restore LF line endings. |
| Already using Husky or Lefthook | Add `.githooks/pre-commit \|\| exit 1` to your existing pre-commit hook. |
| Need to commit in an emergency | `git commit --no-verify` skips the hook. The rules forbid AI agents from using it. |
| Merge commits | Skipped automatically. Resolving conflicts doesn't need a new entry. |

## Uninstall

```bash
git config --unset core.hooksPath
rm -rf .ai_ledger .githooks/pre-commit .cursor/rules/ai-ledger.mdc .windsurf/rules/ai-ledger.md
```

Then remove the `ai-ledger:start` … `ai-ledger:end` block from `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, and
`.github/copilot-instructions.md`, and the three ledger lines from `.gitattributes`.

## This repository

```
install.sh     installer (macOS / Linux / Git Bash)
install.ps1    Windows wrapper (runs install.sh with Git for Windows' bash)
template/      the files copied into your project
```

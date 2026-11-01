# AI Architecture Ledger

A drop-in boilerplate that makes **any AI coding tool** document every change it makes:
**what you asked**, **what it actually did**, **why**, **what else it could have done**, and
**how to check it**. A Git hook enforces the rule, so no tool or person can skip it.
The ledger stays on your computer unless your repository is **confirmed private** (see [Privacy](#privacy-what-gets-uploaded)).

## Why this exists

"I asked the AI for X, but it did Y" is common, and it usually goes unnoticed until later.
The ledger fixes that by making the AI write down, for every task:

- **Your request, word for word,** next to **what it changed**.
- The **Assumptions** it made, so you see where it guessed instead of asking.
- An honest **Request vs Result** section that says where it deviated and why.
- **Concepts** explained in plain English, so you learn the techniques it used instead of
  pasting code you don't understand.
- **How to Verify** steps, so you can confirm the result yourself.

Over time, the log becomes the project's architecture history and a record of how your
requests turn into code.

---

## Install

You need **Git**. Nothing else (no Node, no Python).

Works with **existing projects** and **new ones**. For a new project, create its folder and run
`git init` inside it first. If you forget, the installer stops and tells you, without changing anything.

**macOS / Linux**
```bash
git clone https://github.com/MJ0006/AI-Architecture-Ledger-Boilerplate.git
./AI-Architecture-Ledger-Boilerplate/install.sh path/to/your/project
```

**Windows (PowerShell)**
```powershell
git clone https://github.com/MJ0006/AI-Architecture-Ledger-Boilerplate.git
.\AI-Architecture-Ledger-Boilerplate\install.ps1 path\to\your\project
```

**One-liners** (run inside your project folder)
```bash
curl -fsSL https://raw.githubusercontent.com/MJ0006/AI-Architecture-Ledger-Boilerplate/main/install.sh | bash
```
```powershell
irm https://raw.githubusercontent.com/MJ0006/AI-Architecture-Ledger-Boilerplate/main/install.ps1 | iex
```

> **After installing, start a new conversation in your AI tool (or reload it).** AI tools read their
> rules when a conversation starts, so a chat that was already open won't know about the ledger.

Add `--local` to force local-only mode, or `--shared` to require a private repository (for example
`./install.sh --local path/to/project`). With the one-liner, use `| bash -s -- --local`.

### What the installer does

- Installs at your **repository root**, even if you run it from a subfolder.
- **Never overwrites** your files. Existing files are kept, and for `CLAUDE.md`, `AGENTS.md`, and the
  other tool files it **appends** a marked block (`<!-- ai-ledger:start -->` … `<!-- ai-ledger:end -->`).
- Is **safe to re-run.** (To refresh an existing install with a newer version, see [Updating](#updating).)
- Sets `git config core.hooksPath .githooks`, unless you already use Husky or another hook
  setup. In that case it changes nothing and prints the lines to add to your existing hooks.
- **Chooses the privacy mode** (below) and tells you which one it picked and why.

## Privacy: what gets uploaded

The ledger quotes your requests **word for word**. If you ever type an API key, password, or internal
detail into an AI request, it could end up in the ledger, so the ledger is treated as private.

| Mode | When | What happens on `git push` |
|---|---|---|
| **local** (default) | The repo is public, has no remote, is offline, or isn't on GitHub/GitLab | Nothing ledger-related is uploaded. All ledger files (`.ai_ledger/`, the hooks, and `AGENTS.md`/`CLAUDE.md`/etc. created by the installer) are listed in `.git/info/exclude`, a per-computer ignore list that is never pushed. |
| **shared** | `origin` is **confirmed private** on GitHub or GitLab | The ledger is committed and pushed so your team shares it. The installer prints a **warning**: if you ever make the repo public, the ledger (and any secrets in it) becomes public too. |

**Protections:**
- The installer asks GitHub/GitLab whether `origin` is private (no login needed). Any doubt means **local**.
- In shared mode, the `pre-push` hook re-checks on **every push** and **blocks** it if the repository has
  become public (or can't be confirmed private), with the steps to fix it.
- In local mode, the `pre-push` hook blocks any push whose commits contain `.ai_ledger/` files.
- In local mode, a tool file you already had and commit (e.g. your own `CLAUDE.md`) is **not** given the
  rules, because that would publish them. The other tool files still carry them.
- The rules forbid the AI from writing secrets into the ledger. It must write `[REDACTED]` instead.

**Switch modes at any time:**

```bash
bash .ai_ledger/scripts/set-mode.sh local    # keep on this computer (removes ledger files from the repo)
bash .ai_ledger/scripts/set-mode.sh shared   # share with the team: refused unless the repo is private
```

> **Before making a repository public,** run `set-mode.sh local` and commit. Copies pushed earlier are
> still in the git history: change any keys or passwords they contain, and remove them from history
> with [git filter-repo](https://github.com/newren/git-filter-repo).

## What gets added to your project

```
your-project/
├── .ai_ledger/
│   ├── agent_directives.md   ← master rules (single source of truth; edit here)
│   ├── evolution_log.md      ← the ledger: append-only, one entry per code change
│   ├── analysis_log.md       ← audits, reviews, status checks, plans (no code changed)
│   ├── handoff.md            ← where the work stands; rewritten when you say "handoff"
│   ├── review_prompt.md      ← prompt for the pre-sprint review loop
│   ├── last_review           ← time of the last review (drives the reminder)
│   ├── scripts/
│   │   ├── set-mode.sh       ← switch between local and shared mode
│   │   ├── sync-rules.sh     ← copy agent_directives.md into every AI tool's file
│   │   ├── visibility.sh     ← asks GitHub/GitLab whether the repo is private
│   │   ├── check-setup.sh    ← checks the hooks are active on this computer
│   │   └── archive.sh        ← moves last month's entries to archive/
│   └── archive/              ← older months: YYYY-MM.md and analysis/YYYY-MM.md
├── .githooks/
│   ├── pre-commit            ← blocks commits without a complete ledger entry
│   ├── pre-push              ← keeps the ledger out of public repositories
│   └── post-commit           ← shows the latest Request vs Result and the review reminder
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
| `AGENTS.md` | OpenAI Codex, OpenCode, Cursor, GitHub Copilot agent, Google Antigravity (IDE and CLI), Windsurf, Zed, Jules, and other tools that follow the AGENTS.md convention |
| `CLAUDE.md` | Claude Code (CLI, VS Code, JetBrains, desktop, web) |
| `GEMINI.md` | Gemini CLI, Gemini Code Assist, Google Antigravity |
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
   In local mode, the entry is written but never staged, and the hook checks the file on disk.
5. After the commit, the terminal shows the newest entry's **Request vs Result**, so you see what the AI
   did without opening the ledger:

   ```
   ---------------- AI Ledger: latest entry ----------------
   [2026-11-01 14:05] Login rate limiter
   Request vs Result:
     Differs: also added a Retry-After header (not requested).
   Full entry: .ai_ledger/evolution_log.md
   ----------------------------------------------------------
   ```

**You don't have to remember the ledger.** Your AI tool loads the rules automatically, the hooks block
commits that are missing entries, the post-commit summary shows you each result, and the AI warns you if the
hooks are switched off on your computer.

### Entry format

```markdown
## [2026-11-01 14:05] Login rate limiter
- **Area:** `packages/api`
- **Files:** `packages/api/middleware/rateLimit.ts`, `packages/api/server.ts`

### Request
> Add rate limiting to the login endpoint

### Assumptions
- One server instance, so in-memory counting is enough (asked the user: confirmed).

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
Success = the 6th login attempt within 15 minutes is rejected. Run `curl -X POST localhost:3000/login`
6 times. The 6th call returns `429 Too Many Requests`.
```

The hook requires the `## [YYYY-MM-DD ...]` header and all eight `###` headings. It also **warns**
(without blocking) about staged files the entry never mentions.

---

## Audits, reviews, and handoffs

Not every request changes code. Two more files cover the rest:

- **`analysis_log.md`**: when you ask for an audit (UI/UX, security, performance), a code review, an
  investigation, a status check, or a plan, the AI records it here: Request, Assumptions, **Findings**,
  Request vs Result, and **Recommended next steps**. Quick questions are not recorded.
- **`handoff.md`**: when you say **"handoff"**, **"close the chat"**, or **"completed"**, the AI rewrites
  this file with your goal, what you asked, decisions made, what's done, open questions, and next steps.
  Every new conversation reads it first, so you can switch chats, AI tools, or computers without losing
  the thread. (Just closing the window doesn't trigger it: the AI only acts when you send a message.)

The commit hook can only enforce code entries. These two rely on the AI following its rules, so if one
is missing, ask the AI to add it.

## Learning from the ledger

- **Read Request vs Result first.** It is the quickest way to see whether the AI did what you asked.
- **When it says "Differs",** ask yourself whether the request was clear. Most mismatches come from
  missing details (which file, which behavior, what to leave alone). Write the next request with those details.
- **Read Assumptions** to see where the AI had to guess. A guess you didn't expect means your request was missing that detail.
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

The script moves entries from earlier months into `.ai_ledger/archive/YYYY-MM.md` (code changes) and
`.ai_ledger/archive/analysis/YYYY-MM.md` (analysis entries). Commits that touch only ledger files are never blocked.

## The self-improving loop

Before a new sprint or feature, tell your AI:
**"Follow `.ai_ledger/review_prompt.md`"**. It reads the ledger and reports:

- Request vs Result mismatches, with tips on writing better requests
- Recurring hurdles and technical debt
- Concepts worth studying
- Suggested rule updates for `agent_directives.md`. It only proposes them; you decide.

You don't need to remember to do this. After a commit, if your last review was **14 or more days ago**, the terminal
reminds you. Finishing the review resets the timer (the prompt runs `date +%s > .ai_ledger/last_review`).

---

## Teammates and fresh clones

- **Shared mode:** the ledger is in the repo. `core.hooksPath` is a local Git setting and isn't
  cloned, so after cloning, each person runs `git config core.hooksPath .githooks`.
- **Local mode:** nothing is in the repo, so each person runs the installer and keeps their own ledger.

If someone forgets, the AI notices: before each task it runs `bash .ai_ledger/scripts/check-setup.sh`
and tells the user how to switch the checks on.

## Customizing

- **Change the rules:** edit `.ai_ledger/agent_directives.md`, then run
  `bash .ai_ledger/scripts/sync-rules.sh` to update every AI tool's file.
- **Rename or add headings:** update them in `agent_directives.md` **and** in `REQUIRED_HEADINGS` at
  the top of `.githooks/pre-commit`. The two lists must match.
  If you rename **Request vs Result**, also update it in `.githooks/post-commit` (used for the summary).

## Troubleshooting

| Problem | Fix |
|---|---|
| The AI doesn't write entries right after installing | Start a new conversation (or reload the AI tool). Rules are read when a conversation starts. |
| An audit or review wasn't recorded | Only the code ledger is enforced by the hook. Ask the AI to add the entry to `analysis_log.md`. |
| Hooks don't run | Run `bash .ai_ledger/scripts/check-setup.sh`. It says exactly what's wrong. On macOS/Linux, `chmod +x .githooks/*` fixes permissions. |
| `bash\r: No such file or directory` | The ledger hooks have Windows line endings. Delete them with `rm .githooks/pre-commit .githooks/pre-push .githooks/post-commit`, then run `git checkout -- .githooks` (shared mode) or re-run the installer (local mode). |
| `git commit --amend` is blocked | Amending changes code, so it needs an entry too. Add a short entry (e.g. "Add missing file to previous commit"), or use `--no-verify` if the change is already logged. |
| Local mode: ledger gone after `git clean -fdx` | `git clean -x` deletes ignored files, including the local ledger. Restore the copy kept in `.git/` (updated after every commit): `mkdir -p .ai_ledger && cp -R .git/ai-ledger-backup/. .ai_ledger/`, then re-run the installer to restore the hooks and tool files. |
| Push blocked: "older unpushed commits still contain .ai_ledger/" | You switched to local mode with unpushed commits that still contain the ledger. Follow the printed steps: they combine those commits into one that never contained it. |
| Already using Husky or Lefthook | Add the lines the installer printed to your existing `pre-commit`, `pre-push`, and `post-commit` hooks. |
| Push blocked: "repository is PUBLIC" | Run `bash .ai_ledger/scripts/set-mode.sh local`, commit, then push. |
| Push blocked: "could not confirm private" | You're offline or rate-limited by the GitHub API (60 checks per hour). Try again in a minute. Pushing to a second remote that isn't on GitHub/GitLab is also blocked in shared mode. |
| Local mode: "no new ledger entry since the last commit" | Add an entry to `evolution_log.md`. Don't `git add` it. |
| Need to commit or push in an emergency | `--no-verify` skips the hooks. The rules forbid AI agents from using it. |
| Merge commits | Skipped automatically. Resolving conflicts doesn't need a new entry. |

## Updating

When this boilerplate gets fixes, get the latest version, then update your project:

```bash
git -C AI-Architecture-Ledger-Boilerplate pull
./AI-Architecture-Ledger-Boilerplate/install.sh --update path/to/your/project
```

Or, inside your project: `curl -fsSL https://raw.githubusercontent.com/MJ0006/AI-Architecture-Ledger-Boilerplate/main/install.sh | bash -s -- --update`

It refreshes the hooks, scripts, and rules, keeps your current mode, and **never touches your ledger
entries**. If the rules changed, your previous rules file is saved as `.ai_ledger/agent_directives.md.old`.
Re-apply any changes you had made, then delete that file.

## Uninstall

```bash
git config --unset core.hooksPath
git config --unset ailedger.mode
rm -rf .ai_ledger .githooks/pre-commit .githooks/pre-push .githooks/post-commit \
       .cursor/rules/ai-ledger.mdc .windsurf/rules/ai-ledger.md \
       .git/ai-ledger-backup .git/ai-ledger-count
```

Then remove the `ai-ledger:start` … `ai-ledger:end` block from `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`,
`.github/copilot-instructions.md`, and `.git/info/exclude`, and the three ledger lines from `.gitattributes` (shared mode only).

## This repository

```
install.sh     installer (macOS / Linux / Git Bash)
install.ps1    Windows wrapper (runs install.sh with Git for Windows' bash)
template/      the files copied into your project
tests/run.sh   end-to-end tests: bash tests/run.sh
.github/       CI: runs the tests on Linux, macOS, and Windows, plus the real GitHub/GitLab check
LICENSE        MIT
```

## License

[MIT](LICENSE): free to use, copy, and modify, including commercially.

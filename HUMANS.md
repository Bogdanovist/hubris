# Hubris — Developer Guide

## What is Hubris?

Hubris is a sprint-based agent engineering platform that manages development of external repositories through iterative milestone sprints. It orchestrates Agent Teams for parallel execution, supports autonomous and interactive modes, and evolves requirements through sprint cycles rather than upfront specification.

The user is the tech lead — always in the loop, notified when needed, free to focus elsewhere when agents are productive.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Scripts | Bash (set -euo pipefail) |
| Agent execution | Claude CLI (claude) |
| Agent coordination | Claude Code Agent Teams (TeamCreate, Task, SendMessage) |
| Notifications | macOS osascript |
| State format | YAML + Markdown |
| Version control | Git branches + GitHub PRs |

## Directory Layout

```
hubris/
├── CLAUDE.md                  # Agent system conventions
├── HUMANS.md                  # This file
├── Makefile                   # Common tasks
│
├── docs/
│   ├── DESIGN_RATIONALE.md    # Why decisions were made
│   └── REPO_CONVENTION.md     # Shared repo structure convention (for colleagues)
│
├── scripts/                   # Core orchestration
│   ├── init.sh                # Initialize project + repo
│   ├── intent.sh              # Create/refine intent document
│   ├── sprint.sh              # Execute autonomous sprint (background)
│   ├── session.sh             # Execute interactive session (foreground)
│   ├── status.sh              # Show project/sprint status
│   ├── review.sh              # Review sprint + conversational feedback
│   ├── feedback.sh            # Quick or interactive feedback
│   ├── reconcile_skills.sh    # Compare skill coverage (agent-driven)
│   ├── retro.sh               # Auto-retrospective across sprint journals
│   ├── pause.sh               # Pause project
│   ├── stop.sh                # Stop project
│   ├── complete.sh            # Archive completed project
│   ├── repo_init.sh           # Register + profile a repo
│   └── lib/
│       ├── common.sh          # Shared shell utilities
│       ├── state.sh           # State read/write helpers
│       ├── git.sh             # Git operations (branch, PR, merge)
│       ├── notify.sh          # macOS notification helpers
│       └── guardrails.sh      # ADR creation helpers
│
├── prompts/                   # Agent prompt templates
│   ├── team_lead.md           # Sprint coordinator
│   ├── implementer.md         # Task implementer
│   ├── intent_creator.md      # Intent document creation
│   ├── repo_init.md           # Repo profiling interview
│   ├── reconcile_skills.md    # Skills reconciliation agent
│   ├── retro.md               # Auto-retrospective agent
│   └── refs/
│       ├── guardrails.md      # How to work with ADRs + protected tests
│       └── adaptation.md      # How to adjust sprint parameters
│
├── skill-bank/                # Accumulated skill templates (NOT used by agents)
│
├── repos/                     # Repo registry
│   ├── _template/
│   │   ├── config.yaml
│   │   └── knowledge.md
│   └── {repo-name}/
│       ├── config.yaml
│       ├── knowledge.md
│       └── skills/
│
├── projects/                  # Project state
│   ├── {project-name}/
│   │   ├── intent.md
│   │   ├── backlog.md
│   │   ├── state.yaml
│   │   ├── guardrails.md
│   │   └── sprints/
│   │       └── {NNN}/
│   │           ├── plan.md
│   │           ├── journal.md
│   │           ├── review.md
│   │           └── outcome.yaml
│   └── _completed/
│
├── improvements/              # System self-improvement
│   ├── backlog.md
│   ├── retro_log.md
│   └── adaptation.yaml
│
├── workspace/                 # Cloned working repos (gitignored)
│
└── tests/
```

## Prerequisites

- macOS (for notifications via osascript)
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) authenticated
- Git + GitHub CLI (`gh`) installed
- SSH key loaded (`ssh-add`)

## Workflow

### 1. Register a repo

```bash
cd hubris
./scripts/repo_init.sh my-app git@github.com:org/my-app.git
```

This clones the repo into `workspace/`, runs an interactive agent interview to discover architecture and conventions, and produces `repos/my-app/config.yaml` + `repos/my-app/knowledge.md`.

The agent also sets up the repo convention structure if not already present:
- `.ai/skills/` — AI development conventions
- `docs/decisions/` — ADRs
- `docs/architecture.md` — System overview
- `tests/acceptance/` — Protected acceptance tests

### 2. Create a project

```bash
./scripts/init.sh add-auth my-app
```

This creates the project directory at `projects/add-auth/` with initial state.

### 3. Write the intent document

```bash
./scripts/intent.sh add-auth
```

Interactive session where an agent interviews you to create a lightweight intent document: problem, approach, key outcomes. Share this with colleagues for alignment before building.

### 4. Run a sprint

```bash
# Autonomous (background — you can work on other things)
./scripts/sprint.sh add-auth

# Autonomous (foreground — see output in real-time)
FOREGROUND=1 ./scripts/sprint.sh add-auth

# Interactive (foreground — real-time collaboration)
./scripts/session.sh add-auth
./scripts/session.sh add-auth --preview "npm run dev"
```

Autonomous sprints run in the background. The team lead plans the sprint, spawns implementers for parallel tasks, coordinates dependent work, and notifies you on completion or blockers.

Interactive sessions run in the foreground for rapid iteration — UI design, debugging, prototyping. Optionally start a preview mechanism (dev server, test watcher) for immediate visual feedback.

### 5. Review and give feedback

```bash
# Check status
./scripts/status.sh add-auth

# Review the sprint PR and journal
./scripts/review.sh add-auth

# Quick feedback
./scripts/feedback.sh add-auth "error messages need work"

# Conversational feedback (agent interviews you)
./scripts/feedback.sh add-auth --interactive
```

### 6. Iterate

Start the next sprint — it incorporates your feedback and updated backlog:

```bash
./scripts/sprint.sh add-auth
```

### 7. Complete the project

```bash
./scripts/complete.sh add-auth
```

Archives the project to `projects/_completed/`.

### Maintenance

```bash
# Audit a repo's skill coverage (agent-driven semantic comparison)
./scripts/reconcile_skills.sh my-app

# Same, but interactively offer to copy recommended skills
./scripts/reconcile_skills.sh my-app --interactive

# Auto-retrospective: review recent sprint journals across all projects
# Identifies patterns (recurring blockers, feedback themes) and proposes improvements
./scripts/retro.sh

# Review more journals (default is 5)
./scripts/retro.sh 10
```

`reconcile_skills.sh` is also called automatically during `repo_init.sh`. It uses an agent to compare skill content semantically — not by filename — so it catches overlaps like `dbt.md` vs `data_pipelines.md`.

`retro.sh` is suggested automatically every 5 sprints. Proposed improvements go to `improvements/backlog.md` for user review.

## Project Lifecycle

```
created ──→ active ──→ completed
              │
              ├── sprint 001 → PR → merged
              ├── sprint 002 → PR → merged
              └── sprint NNN → PR → merged
```

Each sprint:
1. Team lead reads project state (intent, backlog, journals, guardrails, repo knowledge)
2. Plans milestone: selects items, decides parallelism vs sequential
3. Spawns implementers for independent tasks (parallel via Agent Teams)
4. Coordinates dependent tasks sequentially
5. On blocker: notifies user, continues non-blocked work
6. On completion: creates PR, writes sprint journal, sends notification
7. User reviews PR, gives conversational feedback
8. Next sprint incorporates feedback + refined backlog

## Two Execution Modes

| Signal | Mode |
|--------|------|
| Well-spec'd implementation tasks | Autonomous sprint |
| Independent parallelisable tasks | Autonomous sprint |
| UI/design iteration | Interactive session |
| Debugging a specific failure | Interactive session |
| Prototyping with uncertain approach | Interactive session |
| Task failed in previous sprint | Interactive session |

## Notifications

macOS notifications via `osascript`. You'll see alerts for:
- Sprint complete (PR ready for review)
- Question (team needs input)
- Blocked (all remaining tasks blocked)
- Error (sprint failed)

## Git Model

```
main
 └── add-auth/sprint-001  (PR → main, merged after review)
      └── add-auth/sprint-002  (PR → main, from updated main)
```

- Each sprint branches from current `main`
- Tasks are commits within the sprint branch
- Automatic rebase onto latest `main` before PR creation
- **Strict repo exclusivity**: one active sprint per repo at a time

### Context PRs

When a sprint modifies convention files (skills, ADRs, architecture docs, acceptance tests, CLAUDE.md), the team lead automatically creates a **separate context PR** for team discussion alongside the normal code PR.

Context PR merges first (requires team consensus). Code PR follows (normal single approval). This ensures convention changes are always a deliberate team decision, never buried in a code review.

## Skills Model

Build agents ONLY read skills from the target repo (`.ai/skills/` in the working repo, mirrored in `repos/{name}/skills/`).

The skill bank (`skill-bank/`) contains templates accumulated across repos. It is NEVER directly loaded by agents during execution. Skills are reconciled at repo initialization (via `reconcile_skills.sh --interactive`) or on-demand — never at runtime. Reconciliation is agent-driven: the agent reads skill content and reasons about semantic coverage rather than comparing filenames.

## Guardrails

Three layers prevent agents from regressing intent:

1. **ADRs** (`docs/decisions/` in working repo) — capture *why* decisions were made
2. **Protected acceptance tests** (`tests/acceptance/` in working repo) — executable specs agents can't modify
3. **Project guardrails** (`projects/{name}/guardrails.md`) — project-specific constraints

## System Self-Improvement

Two feedback channels:
```bash
# Project feedback (goes to backlog)
./scripts/feedback.sh my-project "needs better error handling"

# System feedback (goes to improvements/backlog.md)
./scripts/feedback.sh --system "team lead should check dependencies earlier"
```

Hubris is registered as its own managed repo — system improvements are executed through the same sprint process. Auto-retrospectives periodically review sprint journals across projects to identify patterns and propose improvements.

## Relevant Documentation

- [CLAUDE.md](CLAUDE.md) — Agent system conventions (what agents read)
- [docs/DESIGN_RATIONALE.md](docs/DESIGN_RATIONALE.md) — Why every decision was made
- [docs/REPO_CONVENTION.md](docs/REPO_CONVENTION.md) — Shared repo structure (for colleague alignment)

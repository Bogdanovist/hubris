# Hubris

> *"The whole problem with the world is that fools and fanatics are always so certain of themselves, and wiser people so full of doubts."*
> — Bertrand Russell

An autonomous agent engineering platform.
They are certain. You should not be.

---

## What is Hubris?

Hubris is a sprint-based agent engineering platform that manages development of external repositories through iterative milestone sprints. It orchestrates Agent Teams for parallel execution, supports autonomous and interactive modes, and evolves requirements through sprint cycles rather than upfront specification.

In classical Greek tragedy, hubris is the fatal flaw of mortals who believe they can wield the power of the gods. We named it that because we gave LLMs commit access and a can-do attitude. The parallels write themselves.

You are the tech lead — always in the loop, notified when needed, free to focus elsewhere when agents are being productive, and summoned back when they're confidently demolishing your codebase.

## Tech Stack

| Layer | Technology | Why |
|-------|-----------|-----|
| Scripts | Bash (`set -euo pipefail`) | Because even gods need guardrails |
| Agent execution | Claude CLI (`claude`) | The interns |
| Agent coordination | Claude Code Agent Teams | Unsupervised interns |
| Notifications | macOS `osascript` | The "oh no" alert system |
| State format | YAML + Markdown | Human-readable, agent-writable, occasionally coherent |
| Version control | Git branches + GitHub PRs | The only thing standing between you and production |

## Directory Layout

```
hubris/
├── CLAUDE.md                  # What agents read (the gospel)
├── HUMANS.md                  # What you're reading (the apology)
├── Makefile                   # Common tasks
│
├── docs/
│   ├── DESIGN_RATIONALE.md    # Why decisions were made (hindsight cosplaying as foresight)
│   └── REPO_CONVENTION.md     # Shared repo structure convention (for colleagues)
│
├── scripts/                   # Core orchestration
│   ├── init.sh                # Initialize project + repo
│   ├── intent.sh              # Create/refine intent document
│   ├── sprint.sh              # Execute autonomous sprint (background) — the leap of faith
│   ├── session.sh             # Execute interactive session (foreground) — the safety net
│   ├── status.sh              # Show project/sprint status
│   ├── review.sh              # Review sprint + conversational feedback
│   ├── feedback.sh            # Quick or interactive feedback
│   ├── reconcile_skills.sh    # Compare skill coverage (agent-driven)
│   ├── retro.sh               # Auto-retrospective across sprint journals
│   ├── pause.sh               # Pause project
│   ├── stop.sh                # Stop project (pull the handbrake)
│   ├── complete.sh            # Archive completed project (declare victory)
│   ├── repo_init.sh           # Register + profile a repo
│   └── lib/
│       ├── common.sh          # Shared shell utilities
│       ├── state.sh           # State read/write helpers
│       ├── git.sh             # Git operations (branch, PR, merge)
│       ├── notify.sh          # macOS notification helpers
│       └── guardrails.sh      # ADR creation helpers
│
├── prompts/                   # Agent prompt templates (the personality disorders)
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
│   │   ├── intent.md          # What we want
│   │   ├── backlog.md         # What we haven't done
│   │   ├── state.yaml         # Where we are
│   │   ├── guardrails.md      # What they're not allowed to touch
│   │   └── sprints/
│   │       └── {NNN}/
│   │           ├── plan.md    # What they said they'd do
│   │           ├── journal.md # What actually happened
│   │           ├── review.md  # What we thought about that
│   │           └── outcome.yaml
│   └── _completed/            # The graveyard of triumph
│
├── improvements/              # System self-improvement (the agents improving themselves, what could go wrong)
│   ├── backlog.md
│   ├── retro_log.md
│   └── adaptation.yaml
│
├── workspace/                 # Cloned working repos (gitignored)
│
└── tests/
```

## Prerequisites

- macOS (for notifications via `osascript` — you'll want the warnings)
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) authenticated
- Git + GitHub CLI (`gh`) installed
- SSH key loaded (`ssh-add`)
- A tolerance for ambiguity

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
- `tests/acceptance/` — Protected acceptance tests (the ones the agents aren't allowed to "fix")

### 2. Create a project

```bash
./scripts/init.sh add-auth my-app
```

Creates the project directory at `projects/add-auth/` with initial state. The project exists. The hubris begins.

### 3. Write the intent document

```bash
./scripts/intent.sh add-auth
```

Interactive session where an agent interviews you to create a lightweight intent document: problem, approach, key outcomes. Share this with colleagues for alignment before building.

This is the last moment you have full control. Savour it.

### 4. Run a sprint

```bash
# Autonomous (background — you can work on other things)
./scripts/sprint.sh add-auth

# Autonomous (foreground — watch the sausage get made)
FOREGROUND=1 ./scripts/sprint.sh add-auth

# Interactive (foreground — real-time collaboration)
./scripts/session.sh add-auth
./scripts/session.sh add-auth --preview "npm run dev"
```

Autonomous sprints run in the background. The team lead plans the sprint, spawns implementers for parallel tasks, coordinates dependent work, and notifies you on completion or blockers. You are free to do other things. Whether you can psychologically bring yourself to is another matter.

Interactive sessions run in the foreground for rapid iteration — UI design, debugging, prototyping. Optionally start a preview mechanism (dev server, test watcher) for immediate visual feedback.

### 5. Review and give feedback

```bash
# Check status (are they still going? what have they done? oh god)
./scripts/status.sh add-auth

# Review the sprint PR and journal
./scripts/review.sh add-auth

# Quick feedback
./scripts/feedback.sh add-auth "error messages need work"

# Conversational feedback (agent interviews you about what went wrong)
./scripts/feedback.sh add-auth --interactive
```

The review step is where you discover the delta between what you asked for and what you got. This delta is the core Hubris experience.

### 6. Iterate

Start the next sprint — it incorporates your feedback and updated backlog:

```bash
./scripts/sprint.sh add-auth
```

Sisyphus pushed the boulder. You push the sprint. The boulder, at least, didn't rewrite its own acceptance tests.

### 7. Complete the project

```bash
./scripts/complete.sh add-auth
```

Archives the project to `projects/_completed/`. Pour one out.

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

`reconcile_skills.sh` is also called automatically during `repo_init.sh`. It uses an agent to compare skill content semantically — not by filename — so it catches overlaps like `dbt.md` vs `data_pipelines.md`. The agents are better at reading than they are at writing. Small mercies.

`retro.sh` is suggested automatically every 5 sprints. Proposed improvements go to `improvements/backlog.md` for user review. Yes, the agents are suggesting improvements to the system that manages the agents. We are aware of the implications.

## Project Lifecycle

```
created ──→ active ──→ completed
              │
              ├── sprint 001 → PR → merged (hope)
              ├── sprint 002 → PR → merged (momentum)
              └── sprint NNN → PR → merged (against all odds)
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

This is the loop. It is, on good days, a virtuous cycle. On bad days it is a Möbius strip of feedback and rework. Either way, it converges. Eventually.

## Two Execution Modes

| Signal | Mode | Subtext |
|--------|------|---------|
| Well-spec'd implementation tasks | Autonomous sprint | They've got this (probably) |
| Independent parallelisable tasks | Autonomous sprint | Divide and conquer (emphasis on conquer) |
| UI/design iteration | Interactive session | Trust but verify, in real time |
| Debugging a specific failure | Interactive session | Pair programming with an optimist |
| Prototyping with uncertain approach | Interactive session | Thinking out loud, expensively |
| Task failed in previous sprint | Interactive session | Supervised remediation |

## Notifications

macOS notifications via `osascript`. You'll see alerts for:
- **Sprint complete** — PR ready for review
- **Question** — Team needs input (they're stuck but won't admit it)
- **Blocked** — All remaining tasks blocked (they're stuck and have admitted it)
- **Error** — Sprint failed (Icarus moment)

## Git Model

```
main
 └── add-auth/sprint-001  (PR → main, merged after review)
      └── add-auth/sprint-002  (PR → main, from updated main)
```

- Each sprint branches from current `main`
- Tasks are commits within the sprint branch
- Automatic rebase onto latest `main` before PR creation
- **Strict repo exclusivity**: one active sprint per repo at a time (we learned this the hard way)

### Context PRs

When a sprint modifies convention files (skills, ADRs, architecture docs, acceptance tests, CLAUDE.md), the team lead automatically creates a **separate context PR** for team discussion alongside the normal code PR.

Context PR merges first (requires team consensus). Code PR follows (normal single approval). This ensures convention changes are always a deliberate team decision, never buried in a code review. The agents don't get to quietly redefine the rules they operate under. Checks and balances. Prometheus had chains; they have PRs.

## Skills Model

Build agents ONLY read skills from the target repo (`.ai/skills/` in the working repo, mirrored in `repos/{name}/skills/`).

The skill bank (`skill-bank/`) contains templates accumulated across repos. It is NEVER directly loaded by agents during execution. Skills are reconciled at repo initialization (via `reconcile_skills.sh --interactive`) or on-demand — never at runtime. Reconciliation is agent-driven: the agent reads skill content and reasons about semantic coverage rather than comparing filenames.

The skill bank grows. The agents don't know it exists. This is by design.

## Guardrails

Three layers prevent agents from regressing intent:

1. **ADRs** (`docs/decisions/` in working repo) — capture *why* decisions were made, so agents can't "optimise" them away
2. **Protected acceptance tests** (`tests/acceptance/` in working repo) — executable specs agents cannot modify (the immovable objects)
3. **Project guardrails** (`projects/{name}/guardrails.md`) — project-specific constraints

Without guardrails, agents will cheerfully refactor your architecture to make their tests pass. This is not a hypothetical. This is lore.

## System Self-Improvement

Two feedback channels:
```bash
# Project feedback (goes to backlog)
./scripts/feedback.sh my-project "needs better error handling"

# System feedback (goes to improvements/backlog.md)
./scripts/feedback.sh --system "team lead should check dependencies earlier"
```

Hubris is registered as its own managed repo — system improvements are executed through the same sprint process. Auto-retrospectives periodically review sprint journals across projects to identify patterns and propose improvements.

The system improves itself. The name remains appropriate at every stage.

## Relevant Documentation

- [CLAUDE.md](CLAUDE.md) — Agent system conventions (what agents read)
- [HUMANS.md](HUMANS.md) — Developer guide (what you just read, congratulations)
- [docs/DESIGN_RATIONALE.md](docs/DESIGN_RATIONALE.md) — Why every decision was made
- [docs/REPO_CONVENTION.md](docs/REPO_CONVENTION.md) — Shared repo structure (for colleague alignment)

---

*Named in the tradition of engineers who know exactly what they're doing and are only slightly terrified.*

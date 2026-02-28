# Hubris — Agent Reference

Hubris is a sprint-based agent engineering platform that manages development of external repositories through iterative milestone sprints. It orchestrates Agent Teams for parallel execution, supports autonomous and interactive modes, and evolves requirements through sprint cycles rather than upfront specification.

## How It Works

### Core Concepts

| Concept | Description |
|---------|-------------|
| Project | A unit of work targeting one repo — has intent, backlog, sprints, guardrails |
| Sprint | A milestone delivering enough value for human review. Produces a PR. |
| Backlog | Evolving prioritized work items. Refined at sprint boundaries. |
| Agent Team | Team lead + implementers within one Claude Code session. Created fresh per sprint. |
| Interactive Session | Real-time user + agent collaboration with optional preview mechanism |

### Sprint Lifecycle

1. Team lead reads project state (intent, backlog, journals, guardrails, repo knowledge)
2. Plans milestone: selects items, decides parallelism vs sequential
3. Spawns implementers for independent tasks (parallel via Agent Teams)
4. Coordinates dependent tasks sequentially
5. On blocker: notifies user, continues non-blocked work
6. On completion: creates PR, writes sprint journal, sends notification
7. User reviews PR, gives conversational feedback
8. Next sprint incorporates feedback, refined backlog

### Two Execution Modes

**Autonomous Sprint** (`./scripts/sprint.sh`): Background execution. Team lead + implementers work independently. User reviews at milestone boundaries.

**Interactive Session** (`./scripts/session.sh`): Foreground, conversational. Single agent works with user in real-time. Optional preview mechanism (dev server, test watcher, etc.).

### Agent Roles

**Team Lead**: Plans sprint, spawns implementers, coordinates, handles blockers, writes journal, creates PR, notifies user. Runs as the main Claude Code session.

**Implementer**: Receives task from team lead, reads repo skills + knowledge, implements, runs checks, reports back. Spawned via Task tool.

**Collaborative Mode**: For hard problems — multiple agents investigate different angles, team lead synthesizes.

## File Placement Rules

| What | Where |
|------|-------|
| Project state | `projects/{project-name}/` |
| Sprint artifacts | `projects/{project-name}/sprints/{NNN}/` |
| Repo config | `repos/{repo-name}/config.yaml` |
| Repo knowledge | `repos/{repo-name}/knowledge.md` |
| Repo skills (authoritative) | `repos/{repo-name}/skills/` |
| Skill bank (templates only) | `skill-bank/` |
| Agent prompts | `prompts/` |
| Shell scripts | `scripts/` |
| System improvements | `improvements/` |
| Working repos | `workspace/` (gitignored) |

## Repo Convention (Working Repos)

All managed repos follow this structure:

```
.ai/skills/          # AI development conventions (agents read these)
docs/decisions/      # ADRs — PROTECTED (agents cannot modify without approval)
docs/architecture.md # System overview — PROTECTED
tests/acceptance/    # Acceptance tests — PROTECTED (agents cannot delete/modify)
CLAUDE.md            # Claude-specific tool instructions
```

**PROTECTED** means: agents can read but cannot modify or delete without explicit user approval. Agents CAN add new ADRs, new acceptance tests, and new content — but cannot change or remove existing protected content.

## Skills Model

- Build agents ONLY read skills from the target repo (`repos/{name}/skills/`)
- The skill bank (`skill-bank/`) is NEVER directly loaded by agents during execution
- Skills are reconciled at repo initialization (via `reconcile_skills.sh`) or on-demand, not at runtime

## Code Conventions

### Shell Scripts

- Use `set -euo pipefail`
- Source `scripts/lib/common.sh` for shared utilities
- Quote all variable expansions
- Use functions for reusable logic

## Anti-Patterns

- Do not load skills from the skill bank during sprint execution — use repo skills only
- Do not modify PROTECTED files without user approval
- Do not create sprints on a repo that already has an active sprint (repo exclusivity)
- Do not skip the intent document — always start with a lightweight spec
- Do not flatten context into files when it can be preserved in the team session
- Do not batch feedback — give conversational feedback that refines understanding

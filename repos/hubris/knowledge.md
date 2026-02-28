# Hubris — Repository Knowledge

Last updated: 2026-02-28

## Overview

Hubris is a sprint-based agent engineering platform that manages development of external repositories through iterative milestone sprints. It orchestrates Agent Teams for parallel execution, supports autonomous and interactive modes, and evolves requirements through sprint cycles.

This is the platform's own repo — registered for dogfooding. System improvements identified through feedback or auto-retros become projects that hubris executes on itself.

## Architecture

### Directory Structure

- `scripts/` — Shell scripts for all user-facing commands and orchestration
- `scripts/lib/` — Shared library functions (common, state, git, notify, guardrails)
- `prompts/` — Agent prompt templates (team lead, implementer, intent creator, etc.)
- `prompts/refs/` — Reference documents loaded by agent prompts
- `repos/` — Repo registry (config + knowledge per managed repo)
- `projects/` — Project state (intent, backlog, sprints, guardrails)
- `skill-bank/` — Skill templates (never directly loaded by agents)
- `improvements/` — System self-improvement backlog and adaptation parameters
- `docs/` — Design rationale and repo convention document
- `workspace/` — Cloned working repos (gitignored)

### Key Patterns

- Scripts source `scripts/lib/common.sh` which bootstraps all other libraries
- State is stored as YAML (`state.yaml`) with simple grep/sed-based read/write
- Prompts use `{VARIABLE}` placeholders rendered by `render_prompt`
- All scripts use `set -euo pipefail`

## Development Conventions

- Shell scripts: `set -euo pipefail`, quote all expansions, use functions
- Prompt templates: Markdown with `{VARIABLE}` placeholders
- Skill bank files: Always include the "this is a template" banner
- Commits: descriptive messages, no auto-commit

## Testing

No automated tests yet. Validation is manual via end-to-end script execution.

## Sensitive Areas

- `scripts/lib/state.sh` — YAML parsing is basic (grep/sed). Complex nested YAML will break.
- `scripts/sprint.sh` — Background process management (PID files, disown) is fragile.
- Prompt templates are the most critical files — changes affect all agent behaviour.

## Discoveries

<!-- Build agents append observations here as they learn about the repo -->

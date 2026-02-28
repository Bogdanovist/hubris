# Design Rationale

This document captures the reasoning behind every major architectural decision in Hubris, derived from analysis of Keywork's strengths and weaknesses, the hello-computer project experience (66 tasks, 168 Python tests, 65 Swift tests), and detailed design discussion.

The intent is to preserve the *why* — not just the *what* — so that future decisions (by humans or agents) can build on this reasoning rather than rediscovering it.

## Why sprint-based instead of waterfall?

**Problem observed**: Keywork's Ralph Loop front-loads all requirements into a PRD + specs, then executes a linear plan (plan → build × N → gate). The hello-computer project started with 42 planned tasks but grew to 67 — tasks T043-T067 were almost entirely remediation for issues that couldn't have been specified upfront (installation scripts, platform-specific compilation errors, type mismatches). The system treats requirement changes as exceptions (feedback.md, .replan triggers) rather than as the expected norm.

**Insight**: Requirements can rarely be fully known before implementation begins. Late-stage issues (the "last 5%") are inherently unpredictable. A system that expects and embraces this — rather than patching for it — will be fundamentally more effective.

**Decision**: Break work into milestone-based sprints. Each sprint delivers a testable increment. Requirements evolve between sprints based on what was learned. The backlog is a living document, not a fixed checklist.

## Why Agent Teams instead of sequential single-agent execution?

**Problem observed**: Keywork's build agent executes exactly ONE task per invocation. Each invocation is stateless — the agent reads files, does work, writes results, and dies. The next invocation reconstructs understanding from files. This causes three compounding problems:

1. **Latency**: Each feedback-replan-build cycle takes too long
2. **Cost**: Reconstructing context each time burns tokens
3. **Context loss**: Nuanced understanding ("I tried X, it failed because of Y, the real root cause is Z") gets flattened into journal entries that subsequent agents may misinterpret

**Insight**: Within a sprint, the team lead maintains context across all tasks. When something fails, the same team retries with full understanding of what was tried. Parallel execution of independent tasks increases throughput. Collaborative mode (multiple agents on the same hard problem) addresses the "last 5%" with depth instead of repetition.

**Decision**: Each sprint is one Agent Team session. Context is preserved within a sprint (solving the context loss problem). Parallelism is used for independent tasks (solving the latency problem). Teams are recreated per sprint with rich state files (sprint journals) bridging context between sprints.

## Why dual execution modes (autonomous + interactive)?

**Problem observed**: Keywork has one execution mode: autonomous build loop. For the first 80% of work this is fine, but for rapid iteration tasks (UI design, debugging, prototyping), the feedback loop is too slow. The athena repo's `design_studio.sh` provides near-instant feedback via Streamlit hot-reload + conversational agent interaction. This pattern is extremely effective but was built as a separate, specific tool rather than a general capability.

**Insight**: Different work needs different feedback loops. Well-understood implementation tasks benefit from autonomous parallel execution. Design, debugging, and prototyping benefit from real-time human-agent collaboration. The same system should support both, with the team lead recommending the appropriate mode based on the task type.

**Decision**: Two modes — autonomous sprints (background, parallel, async review) and interactive sessions (foreground, conversational, immediate feedback). Interactive sessions support an optional preview mechanism (dev server, test watcher, etc.) for instant visual feedback. The pattern is general-purpose, not tied to any specific tool.

**When to use which:**

| Signal | Mode |
|--------|------|
| Well-spec'd implementation tasks | Autonomous sprint |
| Independent parallelisable tasks | Autonomous sprint |
| UI/design iteration | Interactive session |
| Debugging a specific failure | Interactive session |
| Prototyping with uncertain approach | Interactive session |
| Task failed in previous autonomous sprint | Interactive session |

## Why no TUI?

**Problem observed**: Keywork's Textual-based TUI provides a dashboard with goal status, attention items, and activity logs. But every substantive action (PRD creation, feedback interviews, retrospectives) drops into a terminal with Claude CLI. The TUI monitors state that's already in files and launches scripts the user could run directly. It adds complexity without proportional value.

**User's actual need**: The user works as a tech lead managing agents alongside their other work. They need to be notified when attention is required and to issue commands efficiently. They don't need a persistent dashboard — they need responsive notifications and simple CLI commands.

**Decision**: Drop the TUI. Use shell scripts as the interface (simple, composable, scriptable). Use macOS notifications via `osascript` for async attention. Claude Code itself handles conversational interactions. The simplest approach that solves the need.

## Why no Docker sandbox?

**Problem observed**: Docker provides isolation (agents can't break the host) and reproducibility. But many repos need real OS access — hello-computer required macOS toolchain (Swift, Xcode) and had `sandbox.enabled: false`. Credential forwarding, SSH agent forwarding, and path mapping add complexity. The sandbox is frequently bypassed.

**User's actual need**: "Agents can work autonomously without asking for permission while ensuring agents can't break things." The sandbox is a means to this end, not a goal.

**Decision**: Accept dev-machine risk + Claude Code permission configuration. Git branches provide file-level recoverability. The real risks (agents deleting system files, pushing to production) are addressed by Claude Code's permission system, not by Docker. For repos that genuinely need containerisation, that's the repo's own Docker setup, not an agent sandbox.

## Why lightweight intent docs instead of PRDs + specs?

**Problem observed**: Keywork's create_prd.sh produces detailed PRDs with Must Have/Nice to Have/Non-Requirements sections, plus separate spec files per component. This takes significant upfront effort and creates an illusion of completeness that the system then fights against when reality diverges.

**User's actual need**: Some kind of initial document is needed for colleague review before building. Colleagues need to align on intent and outcomes, not implementation details. The same document should be agent-readable to avoid context drift.

**Decision**: Replace PRD + specs with a lightweight intent document: problem statement, proposed approach, key outcomes. Enough for colleague review, enough for agent context. Detailed requirements emerge through sprint iterations, not upfront specification. The format and detail level serve both audiences (human colleagues and agents) without over-specifying.

## Why ADRs + protected tests instead of spec promotion?

**Problem observed**: Keywork promotes goal-specific specs to `docs/specs/` in the working repo after completion. The intent is to prevent future projects from undoing existing functionality. However, agents change tests to make them pass and change code without understanding original intent — prose specs have the same vulnerability if agents misinterpret them.

**User's insight**: "Tests aren't enough because agents just change tests so they pass. Something needs to persist specification context."

**Decision**: Three-layer protection:

1. **ADRs** capture *why* decisions were made (not just *what*). An agent reading "We use SQLCipher because user data must be encrypted at rest" understands the constraint, not just the implementation.
2. **Protected acceptance tests** are executable specs. Agents can ADD tests but cannot modify or delete protected ones without user approval. This is machine-verifiable protection.
3. **Repo knowledge** captures conventions and patterns (inherited from Keywork, already proven).

The combination gives: *why* (ADRs) + *what must hold* (protected tests) + *how things work* (knowledge). More durable than prose specs, and protected tests are enforceable.

## Why conversational feedback instead of file-based?

**Problem observed**: Keywork's feedback loop: user observes problem → writes to feedback.md (or runs feedback.sh) → plan agent reads → creates remediation tasks → build agent implements. This is 3-4 agent invocations between "this doesn't work" and "let me fix it." The feedback.sh interview helps structure observations, but the incorporation is still async and loses nuance.

**Decision**: Feedback is a conversation. The user runs `./feedback.sh project --interactive` and an agent interviews them — asking clarifying questions, connecting feedback to backlog items, suggesting implications. The structured output directly updates the backlog for the next sprint. The interview step ensures the agent understands the user's intent, not just their words.

## Why PR-per-sprint with strict repo exclusivity?

**Problem**: Multiple concurrent projects on the same repo can create merge conflicts. The user explicitly doesn't want to handle merge conflicts manually ("I don't think I'd have the context").

**Decision**: Prevent conflicts rather than resolve them. One active sprint per repo at a time (strict repo exclusivity). Cross-repo concurrency is unlimited. Each sprint branches from latest main, automatic rebase before PR creation. Conflicts are structurally impossible except when the user manually edits the same files during a sprint (rare, and the system notifies if rebase fails).

**Tradeoff**: Less within-repo concurrency. Multiple projects on the same repo must take turns. This is acceptable because the alternative (merge conflicts) is worse — the user explicitly prefers preventing problems over maximising concurrency.

## Why separate PRs for context changes?

**Problem observed**: A sprint might change both code and AI context (skills, ADRs, CLAUDE.md, architecture docs, acceptance tests). If these are bundled in one PR, convention changes can be approved without the team noticing — a single reviewer approves the code, and the skills/ADR changes slip through. But skills and ADRs shape how the entire team (human and AI) works. They deserve dedicated review and team discussion.

**Decision**: When a sprint touches context paths (`.ai/skills/`, `docs/decisions/`, `docs/architecture.md`, `tests/acceptance/`, `CLAUDE.md`, `.cursorrules`), the team lead creates two PRs: a context PR (for team-wide discussion) and a code PR (normal single approval). The context PR is created first on a separate branch with only the convention file changes. The code PR links to it. When the context PR is merged (after team consensus), the code PR's context diffs disappear automatically. This creates a forcing function for team alignment on conventions without slowing down code review.

## Why smart auto-adaptation?

**User's need**: "Don't over-engineer for any specific pattern. Be efficient across different types of projects." The system should handle 10-task features and 66-task product builds equally well without the user configuring everything manually.

**Decision**: Adaptation based on three signal sources:

1. **Initial hints** from the user (project type, estimated size)
2. **Observed complexity** from codebase analysis (dependency depth, file count)
3. **Sprint outcomes** learned over time (feedback patterns, failure rates)

The team lead uses these signals to decide milestone boundaries, parallelism levels, and whether to recommend interactive sessions. Not a fixed parameter — the team lead's judgment, guided by adaptation data.

**Adaptation scope**: Both project-level (in `state.yaml`) and global (in `adaptation.yaml`). Global insights come from the auto-retro system.

## Why skills are repo code, not hubris config

**Problem observed**: In Keywork, bundled skills live in `agents/skills/` and repo-specific skills live in `agents/repos/{name}/skills/`. Build agents load both, with repo-specific taking precedence. This creates subtle conflict risks — what if `testing.md` (bundled) gives different advice than `data_pipeline.md` (repo-specific) on the same topic? The agent has to reconcile contradictory context.

**User's insight**: "Skills are part of the code of a repo. Hubris is building and improving them as much as it is for the 'code,' so the same approach to development should apply to them."

**Decision**: Strict separation. Build agents ONLY read skills from the target repo. Hubris maintains a skill bank (accumulated wisdom across repos) but the bank is never directly accessed during execution. At repo initialization (or on-demand via `reconcile_skills.sh`), an agent-driven reconciliation step reads skill content from both sources and reasons about semantic coverage — identifying genuine gaps, overlaps, and candidates for the bank. This is agent reasoning, not filename matching, so it handles cases like `dbt.md` vs `data_pipelines.md` correctly. New skills discovered during projects auto-propose back to the bank (user approves).

This eliminates runtime conflicts, treats skills as living documentation that evolves with the repo, and lets the bank grow organically from real experience.

## Why a shared repo convention document

**Problem observed**: The org has multiple people using different AI tools on the same repos. Without a shared convention, each tool puts context in different places — one uses `docs/specs/`, another uses `.ai/context/`, a third uses inline comments. This creates confusion, duplication, and risk of tools conflicting.

**Insight**: The convention is not hubris-specific. It's a team agreement about how repos are structured for AI-assisted development. ADRs, architecture docs, and acceptance tests are standard engineering practices — they benefit everyone regardless of tooling. Skills (`.ai/skills/`) are the only AI-specific addition.

**Decision**: Fixed directory layout (no manifest, no configuration). A standalone convention document (`REPO_CONVENTION.md`) explains the structure and rationale in colleague-friendly language. The repo init process sets up these directories. The convention is tool-agnostic — hubris implements it, but Cursor/Copilot users can follow the same structure.

**Why `.ai/` for skills**: Dotfile convention signals "tooling infrastructure." Skills are AI-specific guidance — humans don't need to read them day-to-day. Keeping them separate from `docs/` avoids cluttering human documentation with AI-specific content. But `docs/decisions/` and `docs/architecture.md` are for everyone — architectural decisions matter to all developers, not just AI tools.

## Why the system should improve itself

**Problem observed**: The overhaul of the Ralph Loop into Hubris happened entirely outside the system — a human and an AI having a long conversation about architecture. This is expensive, disruptive, and doesn't capture incremental learnings. Small improvements discovered during regular use have no systematic path to implementation.

**Decision**: Three-layer self-improvement:

1. **Two feedback channels** — user can mark feedback as "project" or "system" level. System improvements go to a dedicated backlog.
2. **Dogfooding** — hubris is registered as its own managed repo. System improvements become projects executed through the same sprint process.
3. **Auto-retrospective** — periodically reviews sprint journals across projects, identifies patterns, proposes improvements. Catches things the user might not notice.

This ensures the system can evolve continuously through small, iterative improvements rather than requiring periodic big-bang redesigns.

## Why the user is "tech lead," not "customer"

**Critical reframe**: Keywork treats the user as an external stakeholder who reviews deliverables. But the user described their actual workflow: "I am always around. I want to be involved interactively as much as is productive. The goal is the most productive way for me to work with the agents."

This changes everything. The user is part of the team, not waiting for a product. The system should behave like a team of developers that the user leads — notifying when decisions are needed, working independently when clear, escalating when stuck, and accepting course corrections at any time.

## What's kept from Keywork

- **Repo registration + knowledge profiles**: config.yaml and knowledge.md per repo (proven pattern)
- **Skill concept**: Task-type guidance, restructured as repo code with a bank for cross-pollination
- **Layered context**: System conventions → repo knowledge → project intent → task context
- **Journal concept**: Sprint journals replace the single goal journal
- **Check commands**: Repo config defines lint/test/typecheck/build commands
- **Cost tracking**: Per-sprint and per-project cost tracking with limits

## What's dropped

- **PRD + detailed specs upfront** → Replaced by lightweight intent document
- **IMPLEMENTATION.md as fixed plan** → Replaced by evolving backlog
- **Docker sandbox** → Replaced by git branches + Claude Code permissions
- **TUI** → Replaced by CLI commands + Claude Code as interface
- **Spec promotion** → Replaced by ADRs + protected acceptance tests
- **Orchestrator agent** → User manages project priority directly via commands
- **Sequential single-agent execution** → Replaced by Agent Teams with parallelism
- **File-based feedback/questions** → Replaced by direct conversational interaction
- **Stateless agent invocations** → Team maintains context within a sprint

## What's new

- **Sprint-based execution**: Small increments sized by testable functionality, reviewed and merged individually
- **Dual execution modes**: Autonomous sprints (background, parallel) + interactive sessions (foreground, real-time iteration)
- **Agent Teams**: Parallel execution + collaborative mode for hard problems
- **Backlog**: Evolving requirements, refined each sprint
- **Guardrails**: ADRs + protected tests to prevent intent regression
- **Smart auto-adaptation**: Sprint size, parallelism, mode recommendation adjust based on outcomes
- **PR-per-sprint**: Clean git model, easy review
- **Sprint journals**: Rich narrative context preservation between sprints
- **macOS notifications**: Async attention when the system needs the user
- **Conversational feedback**: Agent interviews user to refine feedback (not just file writing)
- **Mid-sprint continuation**: Blocked tasks don't block the sprint; team continues non-blocked work
- **Skills as repo code**: Skills belong to repos, not to hubris. Bank provides templates, repos hold authoritative copies
- **System self-improvement**: Two feedback channels + dogfooding + auto-retro
- **Review inference**: System infers checkpoint (user only) vs team review based on milestone scope

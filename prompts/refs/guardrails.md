# Guardrails Reference

This reference describes how agents interact with the guardrails system. Guardrails prevent agents from regressing functionality that previous projects established.

## Three Layers

### 1. Architectural Decision Records (ADRs)

**Location**: `docs/decisions/` in the working repo

ADRs capture *why* decisions were made. They provide constraints that agents must respect.

**Format**: `NNN-title.md`

```markdown
# NNN: Decision Title

## Context
What situation prompted this decision.

## Decision
What was decided.

## Constraints
What must remain true as a result.

## Consequences
What follows from this decision.
```

**Agent rules**:
- Read all ADRs before making architectural choices
- Respect the constraints in each ADR
- You MAY create new ADRs when making significant architectural decisions
- You MUST NOT modify or delete existing ADRs without user approval

**Example**: An ADR says "We use SQLCipher because user data must be encrypted at rest." An agent implementing a new storage feature must use SQLCipher, not plain SQLite — even if plain SQLite would be simpler.

### 2. Protected Acceptance Tests

**Location**: `tests/acceptance/` in the working repo

Acceptance tests are executable specifications that encode system invariants. They verify that fundamental requirements hold.

**Agent rules**:
- You MAY add new acceptance tests
- You MUST NOT modify existing acceptance tests
- You MUST NOT delete existing acceptance tests
- If an acceptance test fails, fix your implementation — NEVER change the test
- Run acceptance tests as part of the test suite after every task

**Why they're protected**: Agents sometimes change tests to make them pass rather than fixing the underlying issue. Protected tests prevent this — they are a hard boundary. If the test says "the database must be encrypted," no agent can remove that check.

### 3. Project Guardrails

**Location**: `projects/{name}/guardrails.md` in hubris

Project-specific constraints that the team lead reads at sprint start. These are softer than ADRs — they capture project-level intent that should be respected across sprints.

**Examples**:
- "Do not change the public API without user approval"
- "Performance must not regress — run benchmarks before and after"
- "All new endpoints must have integration tests"

## When to Create ADRs

Create a new ADR when:
- Making a technology choice (database, framework, library)
- Choosing between architectural approaches
- Establishing a pattern that future code should follow
- Making a security-relevant decision

Do NOT create ADRs for:
- Implementation details that don't constrain future work
- Temporary decisions that will be revisited
- Standard language/framework conventions (those go in knowledge.md)

## When to Create Acceptance Tests

Create a new acceptance test when:
- A fundamental requirement could be accidentally broken by future changes
- An ADR establishes a constraint that can be machine-verified
- A bug fix addresses an invariant that should never regress
- The user explicitly requests a behaviour be protected

Keep acceptance tests focused on invariants, not implementation details. `test_data_is_encrypted_at_rest()` is a good acceptance test. `test_uses_sqlcipher_version_4()` is an implementation test that belongs in the regular test suite.

## Context Changes Require Team Review

Changes to these paths affect how the entire team (human and AI) works:

- `.ai/skills/` — AI development conventions
- `docs/decisions/` — Architectural Decision Records
- `docs/architecture.md` — System overview
- `tests/acceptance/` — Protected acceptance tests
- `CLAUDE.md` — Claude-specific conventions
- `.cursorrules` — Cursor conventions
- `.github/copilot-instructions.md` — Copilot conventions

When a sprint modifies any of these files, the team lead creates a **separate context PR** alongside the code PR. The context PR is marked for team-wide discussion. The code PR links to it.

**Workflow**: Context PR is reviewed and merged first (team consensus). Code PR is reviewed and merged after (normal single approval).

This ensures convention changes are never buried in code PRs where they might be approved without team discussion.

# Repo Convention for AI-Assisted Development

A shared directory convention for repositories that use AI development tools. This convention is **tool-agnostic** — it works with Claude Code, Cursor, Copilot, or any other AI tool. The structure separates AI-specific content from standard engineering documentation that benefits everyone.

## Directory Structure

```
{repo}/
├── .ai/
│   └── skills/                # AI development conventions
│
├── docs/
│   ├── decisions/             # Architectural Decision Records (ADRs)
│   └── architecture.md        # System overview
│
├── tests/
│   └── acceptance/            # Acceptance tests encoding system invariants
│
├── CLAUDE.md                  # Claude-specific config (if using Claude Code)
└── ...                        # Other tool configs per their conventions
```

## What each part does

### `.ai/skills/` — AI development conventions

Task-type guidance for how AI tools should approach work in this repo. Skills describe patterns, conventions, and approaches specific to this codebase.

**Examples**: `testing.md` (how to write tests for this project), `api_development.md` (API patterns used here), `data_pipeline.md` (ETL conventions).

**Audience**: AI tools only. Humans rarely need to read these, which is why they're in a dotfile directory.

**Ownership**: Evolved alongside the code. AI tools can propose additions; humans approve.

### `docs/decisions/` — Architectural Decision Records

Standard ADRs capturing *why* architectural decisions were made — not just *what* was decided. These serve as guardrails for all developers (human and AI).

**Format**: `NNN-title.md` (e.g., `001-use-sqlcipher-for-storage.md`)

Each ADR contains:
- **Context**: What situation prompted the decision
- **Decision**: What was decided
- **Constraints**: What must remain true
- **Consequences**: What follows from this decision

**Example**: "We use SQLCipher because user correction data must be encrypted at rest. Do not downgrade to plain SQLite."

**Audience**: Everyone. Architectural decisions matter to all developers.

**Protection**: AI tools can ADD new ADRs. They cannot modify or delete existing ones without explicit human approval.

### `docs/architecture.md` — System overview

A concise description of the system's architecture: major components, how they interact, key design patterns. Kept up to date as the system evolves.

**Audience**: Everyone. Essential for onboarding and context.

**Protection**: Same as ADRs — AI tools can add to it but cannot modify or remove existing content without approval.

### `tests/acceptance/` — Acceptance tests

Executable specifications that encode system invariants. These tests verify that fundamental requirements hold. They serve double duty as both quality gates and machine-verifiable guardrails.

**Examples**: `test_ledger_uses_encrypted_storage()`, `test_api_requires_authentication()`, `test_data_export_includes_all_fields()`

**Audience**: Everyone. Standard tests that happen to also serve as enforceable constraints.

**Protection**: AI tools can ADD new acceptance tests. They cannot modify or delete existing ones without human approval. This prevents the common pattern where AI tools change tests to make them pass rather than fixing the underlying issue.

### `CLAUDE.md` / `.cursorrules` / etc. — Tool-specific configs

Each AI tool has its own configuration convention. These coexist without conflict:
- `CLAUDE.md` for Claude Code
- `.cursorrules` for Cursor
- `.github/copilot-instructions.md` for Copilot

These files point tools to the shared convention (`.ai/skills/`, `docs/decisions/`, etc.) and add any tool-specific instructions.

## What's AI-specific vs what's for everyone

| Directory | Who it's for | Purpose |
|-----------|-------------|---------|
| `.ai/skills/` | AI tools | How AI should work in this repo |
| `docs/decisions/` | Everyone | Why decisions were made |
| `docs/architecture.md` | Everyone | How the system works |
| `tests/acceptance/` | Everyone | What must always hold true |
| `CLAUDE.md`, `.cursorrules`, etc. | Specific tool | Tool configuration |

The key insight: most of this convention is standard engineering practice (ADRs, architecture docs, acceptance tests). The only AI-specific addition is `.ai/skills/`. Everything else benefits the whole team regardless of tooling.

## What "protected" means

Protected files cannot be modified or deleted by AI tools without explicit human approval. AI tools CAN:
- Add new ADRs to `docs/decisions/`
- Add new sections to `docs/architecture.md`
- Add new tests to `tests/acceptance/`

AI tools CANNOT (without approval):
- Modify existing ADR content
- Remove sections from `docs/architecture.md`
- Change or delete existing acceptance tests

This protection is enforced through AI tool configuration (CLAUDE.md, .cursorrules, etc.), not through file permissions. Each tool implements protection per its own conventions.

## Setting up a repo

To adopt this convention in an existing repo:

```bash
mkdir -p .ai/skills docs/decisions tests/acceptance
touch docs/architecture.md
```

Then add the protection rules to your AI tool configs. For Claude Code, add to `CLAUDE.md`:

```markdown
## Protected Files

Do not modify or delete files in `docs/decisions/` or `tests/acceptance/`
without explicit human approval. You may add new files to these directories.
Do not remove content from `docs/architecture.md` without approval.
```

## Rationale

### Why `.ai/` for skills?

Dotfile convention signals "tooling infrastructure." Skills are AI-specific guidance — humans don't need to read them day-to-day. Keeping them separate from `docs/` avoids cluttering human documentation with AI-specific content.

### Why `docs/decisions/` not `docs/adrs/`?

"Decisions" is more intuitive than the ADR acronym. The content follows ADR conventions, but the name is more accessible to team members who haven't encountered the ADR pattern before.

### Why protect acceptance tests?

AI tools sometimes change tests to make them pass rather than fixing the underlying code. Protected acceptance tests create a hard boundary: if a test fails, the implementation must be fixed, not the test. AI tools can still add new tests — they just can't weaken existing guarantees.

### Why a fixed layout instead of a manifest?

A manifest file (listing where things are) adds indirection and maintenance burden. A fixed layout means every repo looks the same. You know where to find things without reading configuration. New team members (human or AI) can navigate any repo immediately.

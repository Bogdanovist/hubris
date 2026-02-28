#!/bin/bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────
PROJECT_NAME="${1:-}"
REPO_NAME="${2:-}"

if [ -z "$PROJECT_NAME" ] || [ -z "$REPO_NAME" ]; then
    echo "Usage: ./scripts/init.sh <project-name> <repo-name>"
    echo ""
    echo "Create a new project targeting a registered repo."
    echo ""
    echo "Examples:"
    echo "  ./scripts/init.sh add-auth my-api"
    echo "  ./scripts/init.sh redesign-dashboard my-app"
    exit 1
fi

# ── Bootstrap ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ── Validate ──────────────────────────────────────────────────────────
validate_name "$PROJECT_NAME" "Project name"
validate_name "$REPO_NAME" "Repo name"

# Check repo exists
require_repo "$REPO_NAME" >/dev/null

# Check project doesn't already exist
PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"
if [ -d "$PROJECT_DIR" ]; then
    log_error "Project '$PROJECT_NAME' already exists at $PROJECT_DIR"
    exit 1
fi

# Check for archived project with same name
if [ -d "$PROJECTS_DIR/_completed/$PROJECT_NAME" ]; then
    log_warn "A completed project with name '$PROJECT_NAME' exists in _completed/."
    echo "Choose a different name or remove the archived project first."
    exit 1
fi

# ── Create project structure ─────────────────────────────────────────
log "Creating project '$PROJECT_NAME' targeting repo '$REPO_NAME'"

ensure_dir "$PROJECT_DIR"
ensure_dir "$PROJECT_DIR/sprints"

# ── State file ───────────────────────────────────────────────────────
cat > "$PROJECT_DIR/state.yaml" << EOF
# Project state for $PROJECT_NAME
name: "$PROJECT_NAME"
repo: "$REPO_NAME"
status: "created"
current_sprint: "0"
created: "$(today)"

# Adaptation parameters (adjusted by team lead based on outcomes)
adaptation:
  parallelism: 2
  collaborative_threshold: 2
  prefer_interactive: false
EOF

# ── Intent placeholder ───────────────────────────────────────────────
cat > "$PROJECT_DIR/intent.md" << EOF
# Intent: $PROJECT_NAME

## Problem

What problem are we solving? Why does it matter?

## Approach

How will we solve it? Key technical decisions.

## Key Outcomes

What does "done" look like? How will we verify?

## Open Questions

What don't we know yet?
EOF

# ── Backlog placeholder ──────────────────────────────────────────────
cat > "$PROJECT_DIR/backlog.md" << EOF
# Backlog: $PROJECT_NAME

Prioritised work items. Refined at sprint boundaries.

## Ready

<!-- Items ready for the next sprint -->

## Discovered

<!-- Items discovered during sprints, not yet prioritised -->

## Done

<!-- Completed items moved here for reference -->
EOF

# ── Guardrails placeholder ───────────────────────────────────────────
cat > "$PROJECT_DIR/guardrails.md" << EOF
# Guardrails: $PROJECT_NAME

Project-specific constraints that agents must respect.
Updated at sprint boundaries based on discoveries.

## Constraints

<!-- Add project-specific constraints here -->

## References

- Repo ADRs: \`docs/decisions/\` in the working repo
- Protected tests: \`tests/acceptance/\` in the working repo
- Repo knowledge: \`repos/$REPO_NAME/knowledge.md\`
EOF

echo ""
log "Project '$PROJECT_NAME' created."
echo ""
echo "  Project dir: $PROJECT_DIR"
echo "  Target repo: $REPO_NAME"
echo ""
echo "Next steps:"
echo "  1. Check skill coverage:    ./scripts/reconcile_skills.sh $REPO_NAME"
echo "  2. Write the intent document: ./scripts/intent.sh $PROJECT_NAME"
echo "  3. Or edit directly: \$EDITOR $PROJECT_DIR/intent.md"
echo "  4. Then start a sprint: ./scripts/sprint.sh $PROJECT_NAME"

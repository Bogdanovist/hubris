#!/bin/bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────
PROJECT_NAME="${1:-}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./scripts/intent.sh <project-name>"
    echo ""
    echo "Create or refine the intent document for a project."
    echo "Launches an interactive agent that interviews you about"
    echo "the problem, approach, and key outcomes."
    exit 1
fi

# ── Bootstrap ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ── Validate ──────────────────────────────────────────────────────────
PROJECT_DIR=$(require_project "$PROJECT_NAME")
REPO_NAME=$(project_state_read "$PROJECT_NAME" "repo")

if [ -z "$REPO_NAME" ]; then
    log_error "Project '$PROJECT_NAME' has no repo configured in state.yaml"
    exit 1
fi

REPO_DIR=$(require_repo "$REPO_NAME")
WS_DIR="$WORKSPACE_DIR/$REPO_NAME"
INTENT_FILE="$PROJECT_DIR/intent.md"

if [ ! -f "$INTENT_FILE" ]; then
    log_error "Intent file not found at $INTENT_FILE"
    exit 1
fi

# ── Read repo knowledge for context ──────────────────────────────────
KNOWLEDGE_FILE="$REPO_DIR/knowledge.md"

# ── Launch intent creation agent ─────────────────────────────────────
log "Launching intent creation agent for '$PROJECT_NAME'"
echo ""

PROMPT_FILE="$PROMPTS_DIR/intent_creator.md"
if [ ! -f "$PROMPT_FILE" ]; then
    log_error "Intent creator prompt not found at $PROMPT_FILE"
    exit 1
fi

PROMPT=$(render_prompt "$PROMPT_FILE" \
    "PROJECT_NAME=$PROJECT_NAME" \
    "PROJECT_DIR=$PROJECT_DIR" \
    "REPO_NAME=$REPO_NAME" \
    "REPO_DIR=$REPO_DIR" \
    "WORKSPACE_DIR=$WS_DIR" \
    "KNOWLEDGE_FILE=$KNOWLEDGE_FILE")

claude --system-prompt "$PROMPT" --dangerously-skip-permissions \
    "Read the current intent document and repo knowledge, then help me refine the intent for project '$PROJECT_NAME' targeting repo '$REPO_NAME'."

# ── Update state ─────────────────────────────────────────────────────
project_state_write "$PROJECT_NAME" "status" "active"

echo ""
log "Intent document updated."
echo ""
echo "  Intent: $INTENT_FILE"
echo ""
echo "Next steps:"
echo "  1. Share with colleagues for alignment"
echo "  2. Start a sprint: ./scripts/sprint.sh $PROJECT_NAME"
echo "  3. Or start interactive: ./scripts/session.sh $PROJECT_NAME"

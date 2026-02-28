#!/bin/bash
set -euo pipefail

PROJECT_NAME="${1:-}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./scripts/complete.sh <project-name>"
    echo ""
    echo "Archive a completed project."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PROJECT_DIR=$(require_project "$PROJECT_NAME")

STATUS=$(project_state_read "$PROJECT_NAME" "status" 2>/dev/null || echo "unknown")
if [ "$STATUS" = "sprinting" ]; then
    log_error "Project '$PROJECT_NAME' has a sprint in progress. Stop it first: ./scripts/stop.sh $PROJECT_NAME"
    exit 1
fi

# ── Show summary ─────────────────────────────────────────────────────
SPRINT_NUM=$(current_sprint "$PROJECT_NAME" 2>/dev/null || echo "0")
REPO_NAME=$(project_state_read "$PROJECT_NAME" "repo" 2>/dev/null || echo "unknown")

echo "=== Completing project: $PROJECT_NAME ==="
echo ""
echo "  Repo:    $REPO_NAME"
echo "  Sprints: $SPRINT_NUM"
echo ""

# ── Confirm ──────────────────────────────────────────────────────────
echo "Archive this project to _completed/? (y/N)"
read -r -n 1 REPLY
echo ""

if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# ── Archive ──────────────────────────────────────────────────────────
COMPLETED_DIR="$PROJECTS_DIR/_completed"
ensure_dir "$COMPLETED_DIR"

project_state_write "$PROJECT_NAME" "status" "completed"
project_state_write "$PROJECT_NAME" "completed" "$(today)"

mv "$PROJECT_DIR" "$COMPLETED_DIR/$PROJECT_NAME"

log "Project '$PROJECT_NAME' archived to $COMPLETED_DIR/$PROJECT_NAME"

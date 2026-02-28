#!/bin/bash
set -euo pipefail

PROJECT_NAME="${1:-}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./scripts/stop.sh <project-name>"
    echo ""
    echo "Stop a running sprint immediately."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PROJECT_DIR=$(require_project "$PROJECT_NAME")

SPRINT_NUM=$(current_sprint "$PROJECT_NAME" 2>/dev/null || echo "0")
SPRINT_DIR=$(sprint_dir "$PROJECT_NAME" "$SPRINT_NUM")

# Kill the sprint process if running
PID_FILE="$SPRINT_DIR/.pid"
if [ -f "$PID_FILE" ]; then
    SPRINT_PID=$(cat "$PID_FILE")
    if kill -0 "$SPRINT_PID" 2>/dev/null; then
        log "Stopping sprint process (PID: $SPRINT_PID)"
        kill "$SPRINT_PID" 2>/dev/null || true
        # Give it a moment, then force kill if needed
        sleep 2
        if kill -0 "$SPRINT_PID" 2>/dev/null; then
            kill -9 "$SPRINT_PID" 2>/dev/null || true
        fi
    fi
    rm -f "$PID_FILE"
fi

# Transition back to active
project_state_write "$PROJECT_NAME" "status" "active"

log "Project '$PROJECT_NAME' stopped."
echo "  Sprint $SPRINT_NUM was interrupted."
echo "  Resume: ./scripts/sprint.sh $PROJECT_NAME"

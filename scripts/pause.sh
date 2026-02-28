#!/bin/bash
set -euo pipefail

PROJECT_NAME="${1:-}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./scripts/pause.sh <project-name>"
    echo ""
    echo "Pause a project after the current sprint completes."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

PROJECT_DIR=$(require_project "$PROJECT_NAME")

project_transition "$PROJECT_NAME" "paused"
log "Project '$PROJECT_NAME' paused."
echo "  Resume: ./scripts/sprint.sh $PROJECT_NAME (will unpause automatically)"

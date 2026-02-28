#!/bin/bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────
PROJECT_NAME="${1:-}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./scripts/review.sh <project-name>"
    echo ""
    echo "Review the latest sprint for a project."
    echo "Shows the PR, sprint journal, and launches a conversational"
    echo "feedback session to capture your observations."
    exit 1
fi

# ── Bootstrap ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ── Validate ──────────────────────────────────────────────────────────
PROJECT_DIR=$(require_project "$PROJECT_NAME")
REPO_NAME=$(project_state_read "$PROJECT_NAME" "repo")
WS_DIR="$WORKSPACE_DIR/$REPO_NAME"

SPRINT_NUM=$(current_sprint "$PROJECT_NAME" 2>/dev/null || echo "0")
if [ "$SPRINT_NUM" = "0" ]; then
    log_error "No sprints found for project '$PROJECT_NAME'"
    exit 1
fi

SPRINT_DIR=$(sprint_dir "$PROJECT_NAME" "$SPRINT_NUM")

# ── Show sprint summary ──────────────────────────────────────────────
echo "=== Sprint $SPRINT_NUM Review: $PROJECT_NAME ==="
echo ""

# Show journal if it exists
JOURNAL="$SPRINT_DIR/journal.md"
if [ -f "$JOURNAL" ]; then
    echo "--- Sprint Journal ---"
    cat "$JOURNAL"
    echo ""
    echo "---"
    echo ""
else
    echo "  (No journal found for sprint $SPRINT_NUM)"
    echo ""
fi

# Show questions if any are unanswered
QUESTIONS="$SPRINT_DIR/questions.md"
if [ -f "$QUESTIONS" ]; then
    echo "--- Open Questions ---"
    cat "$QUESTIONS"
    echo ""
    echo "---"
    echo ""
fi

# Show PR if one exists
echo "--- Pull Request ---"
(
    cd "$WS_DIR"
    SPRINT_BRANCH="${PROJECT_NAME}/sprint-$(format_sprint "$SPRINT_NUM")"
    gh pr view "$SPRINT_BRANCH" --json title,url,state,body --template \
        'Title: {{.title}}
URL:   {{.url}}
State: {{.state}}

{{.body}}
' 2>/dev/null || echo "  (No PR found for branch $SPRINT_BRANCH)"
)
echo ""

# ── Launch feedback session ──────────────────────────────────────────
echo "Would you like to give feedback? (y/N)"
read -r -n 1 REPLY
echo ""

if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    exec "$SCRIPT_DIR/feedback.sh" "$PROJECT_NAME" --interactive
fi

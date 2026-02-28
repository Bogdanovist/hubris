#!/bin/bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────
PROJECT_NAME="${1:-}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./scripts/sprint.sh <project-name>"
    echo ""
    echo "Execute the next autonomous sprint for a project."
    echo "Runs in the background — you'll get a macOS notification on completion."
    echo ""
    echo "Options (via environment variables):"
    echo "  FOREGROUND=1    Run in foreground instead of background"
    exit 1
fi

# ── Bootstrap ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ── Validate ──────────────────────────────────────────────────────────
PROJECT_DIR=$(require_project "$PROJECT_NAME")
REPO_NAME=$(project_state_read "$PROJECT_NAME" "repo")

if [ -z "$REPO_NAME" ]; then
    log_error "Project '$PROJECT_NAME' has no repo configured"
    exit 1
fi

require_repo "$REPO_NAME" >/dev/null

WS_DIR="$WORKSPACE_DIR/$REPO_NAME"
validate_workspace "$REPO_NAME"

REPO_DIR="$REPOS_DIR/$REPO_NAME"

# ── Check project status ─────────────────────────────────────────────
STATUS=$(project_state_read "$PROJECT_NAME" "status" 2>/dev/null || echo "unknown")

if [ "$STATUS" = "sprinting" ]; then
    log_error "Project '$PROJECT_NAME' already has a sprint in progress."
    echo "  Check status: ./scripts/status.sh $PROJECT_NAME"
    exit 1
fi

if [ "$STATUS" = "completed" ]; then
    log_error "Project '$PROJECT_NAME' is completed."
    exit 1
fi

if [ "$STATUS" = "created" ]; then
    log_warn "Project has no intent document yet. Consider running: ./scripts/intent.sh $PROJECT_NAME"
    echo "  Continuing anyway..."
fi

# ── Check repo exclusivity ───────────────────────────────────────────
BLOCKING_PROJECT=$(repo_has_active_sprint "$REPO_NAME" 2>/dev/null || true)
if [ -n "$BLOCKING_PROJECT" ]; then
    log_error "Repo '$REPO_NAME' already has an active sprint from project '$BLOCKING_PROJECT'."
    echo "  Only one sprint per repo at a time (prevents merge conflicts)."
    echo "  Wait for '$BLOCKING_PROJECT' to finish or stop it: ./scripts/stop.sh $BLOCKING_PROJECT"
    exit 1
fi

# ── Check intent and backlog exist ───────────────────────────────────
if [ ! -f "$PROJECT_DIR/intent.md" ]; then
    log_error "No intent.md found. Run: ./scripts/intent.sh $PROJECT_NAME"
    exit 1
fi

if [ ! -f "$PROJECT_DIR/backlog.md" ]; then
    log_error "No backlog.md found. Run: ./scripts/intent.sh $PROJECT_NAME"
    exit 1
fi

# ── Determine sprint number ──────────────────────────────────────────
SPRINT_NUM=$(next_sprint "$PROJECT_NAME")
SPRINT_DIR=$(sprint_dir "$PROJECT_NAME" "$SPRINT_NUM")
SPRINT_BRANCH="${PROJECT_NAME}/sprint-$(format_sprint "$SPRINT_NUM")"

log "Starting sprint $SPRINT_NUM for project '$PROJECT_NAME'"

# ── Create sprint directory ──────────────────────────────────────────
ensure_dir "$SPRINT_DIR"

# ── Create sprint branch ─────────────────────────────────────────────
log "Creating branch: $SPRINT_BRANCH"
create_sprint_branch "$WS_DIR" "$PROJECT_NAME" "$SPRINT_NUM" >/dev/null

# ── Update state ─────────────────────────────────────────────────────
project_state_write "$PROJECT_NAME" "current_sprint" "$SPRINT_NUM"
project_transition "$PROJECT_NAME" "sprinting"

# ── Read adaptation parameters ───────────────────────────────────────
PARALLELISM=$(yaml_read "$PROJECT_DIR/state.yaml" "  parallelism" 2>/dev/null || echo "2")
COLLAB_THRESHOLD=$(yaml_read "$PROJECT_DIR/state.yaml" "  collaborative_threshold" 2>/dev/null || echo "2")
PREFER_INTERACTIVE=$(yaml_read "$PROJECT_DIR/state.yaml" "  prefer_interactive" 2>/dev/null || echo "false")

# Check previous sprint outcome for adaptation hints
PREV_SPRINT=$((SPRINT_NUM - 1))
if [ "$PREV_SPRINT" -gt 0 ]; then
    PREV_OUTCOME="$(sprint_dir "$PROJECT_NAME" "$PREV_SPRINT")/outcome.yaml"
    if [ -f "$PREV_OUTCOME" ]; then
        PREV_RESULT=$(yaml_read "$PREV_OUTCOME" "outcome" 2>/dev/null || echo "")
        if [ -n "$PREV_RESULT" ]; then
            log "Previous sprint outcome: $PREV_RESULT"
        fi
    fi
fi

# ── Build team lead prompt ───────────────────────────────────────────
PROMPT_FILE="$PROMPTS_DIR/team_lead.md"
if [ ! -f "$PROMPT_FILE" ]; then
    log_error "Team lead prompt not found at $PROMPT_FILE"
    exit 1
fi

# Read check commands from config
LINT_CMD=$(yaml_read "$REPO_DIR/config.yaml" "  lint" 2>/dev/null || echo "")
TEST_CMD=$(yaml_read "$REPO_DIR/config.yaml" "  test" 2>/dev/null || echo "")
TYPECHECK_CMD=$(yaml_read "$REPO_DIR/config.yaml" "  typecheck" 2>/dev/null || echo "")
BUILD_CMD=$(yaml_read "$REPO_DIR/config.yaml" "  build" 2>/dev/null || echo "")

TEAM_NAME="sprint-${PROJECT_NAME}-$(format_sprint "$SPRINT_NUM")"

PROMPT=$(render_prompt "$PROMPT_FILE" \
    "PROJECT_NAME=$PROJECT_NAME" \
    "REPO_NAME=$REPO_NAME" \
    "PROJECT_DIR=$PROJECT_DIR" \
    "REPO_DIR=$REPO_DIR" \
    "WORKSPACE_DIR=$WS_DIR" \
    "SPRINT_DIR=$SPRINT_DIR" \
    "SPRINT_NUM=$SPRINT_NUM" \
    "SPRINT_BRANCH=$SPRINT_BRANCH" \
    "TEAM_NAME=$TEAM_NAME")

# ── Run the sprint ───────────────────────────────────────────────────
run_sprint() {
    local start_time
    start_time=$(date +%s)

    log "Sprint $SPRINT_NUM running..."

    claude --system-prompt "$PROMPT" --dangerously-skip-permissions \
        "Read the project state and begin sprint $SPRINT_NUM. Plan the milestone, execute tasks, create the PR, and write the sprint journal."

    EXIT_CODE=$?

    local end_time
    end_time=$(date +%s)
    local duration=$(( end_time - start_time ))

    # Transition back to active
    project_state_write "$PROJECT_NAME" "status" "active"

    # Write outcome tracking (supplement what the team lead writes)
    OUTCOME_FILE="$SPRINT_DIR/outcome.yaml"
    if [ ! -f "$OUTCOME_FILE" ]; then
        # Team lead didn't write one — create a basic one from script-level data
        local outcome="clean"
        [ "$EXIT_CODE" -ne 0 ] && outcome="failed"
        cat > "$OUTCOME_FILE" << EOF
sprint: "$SPRINT_NUM"
project: "$PROJECT_NAME"
outcome: "$outcome"
duration_seconds: "$duration"
exit_code: "$EXIT_CODE"
timestamp: "$(timestamp)"
EOF
    else
        # Append duration to what the team lead wrote
        yaml_write "$OUTCOME_FILE" "duration_seconds" "$duration"
        yaml_write "$OUTCOME_FILE" "timestamp" "$(timestamp)"
    fi

    if [ "$EXIT_CODE" -eq 0 ]; then
        notify_sprint_complete "$PROJECT_NAME" "$SPRINT_NUM"
        log "Sprint $SPRINT_NUM complete (${duration}s)."
        echo ""
        echo "Next steps:"
        echo "  Review: ./scripts/review.sh $PROJECT_NAME"
        echo "  Status: ./scripts/status.sh $PROJECT_NAME"
        echo "  Next:   ./scripts/sprint.sh $PROJECT_NAME"

        # Check if auto-retro is due (every 5 sprints)
        if [ $((SPRINT_NUM % 5)) -eq 0 ]; then
            echo ""
            log "Sprint $SPRINT_NUM is a multiple of 5 — consider running: ./scripts/retro.sh"
        fi
    else
        notify_error "$PROJECT_NAME" "Sprint $SPRINT_NUM failed (exit code $EXIT_CODE)"
        log_error "Sprint $SPRINT_NUM failed with exit code $EXIT_CODE (${duration}s)"
        echo "  Check the sprint directory: $SPRINT_DIR"
    fi
}

if [ "${FOREGROUND:-}" = "1" ]; then
    run_sprint
else
    log "Running in background. You'll get a notification when done."
    echo "  Status: ./scripts/status.sh $PROJECT_NAME"
    echo "  Stop:   ./scripts/stop.sh $PROJECT_NAME"
    run_sprint &
    SPRINT_PID=$!
    echo "  PID:    $SPRINT_PID"

    # Write PID for stop.sh
    echo "$SPRINT_PID" > "$SPRINT_DIR/.pid"

    disown "$SPRINT_PID"
fi

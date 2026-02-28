#!/bin/bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────
PROJECT_NAME="${1:-}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./scripts/session.sh <project-name> [--preview \"command\"]"
    echo ""
    echo "Start an interactive session for a project."
    echo "Runs in the foreground for real-time collaboration."
    echo ""
    echo "Examples:"
    echo "  ./scripts/session.sh my-project"
    echo "  ./scripts/session.sh my-project --preview \"npm run dev\""
    echo "  ./scripts/session.sh my-project --preview \"streamlit run app.py\""
    echo "  ./scripts/session.sh my-project --preview \"pytest --watch\""
    exit 1
fi

# ── Parse arguments ──────────────────────────────────────────────────
shift
PREVIEW_CMD=""
while [ $# -gt 0 ]; do
    case "$1" in
        --preview)
            PREVIEW_CMD="${2:-}"
            if [ -z "$PREVIEW_CMD" ]; then
                echo "Error: --preview requires a command argument"
                exit 1
            fi
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

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

# ── Check repo exclusivity ───────────────────────────────────────────
BLOCKING_PROJECT=$(repo_has_active_sprint "$REPO_NAME" 2>/dev/null || true)
if [ -n "$BLOCKING_PROJECT" ]; then
    log_error "Repo '$REPO_NAME' has an active sprint from project '$BLOCKING_PROJECT'."
    echo "  Wait for it to finish or stop it first."
    exit 1
fi

# ── Determine sprint number ──────────────────────────────────────────
SPRINT_NUM=$(next_sprint "$PROJECT_NAME")
SPRINT_DIR=$(sprint_dir "$PROJECT_NAME" "$SPRINT_NUM")
SPRINT_BRANCH="${PROJECT_NAME}/sprint-$(format_sprint "$SPRINT_NUM")"

log "Starting interactive session (sprint $SPRINT_NUM) for '$PROJECT_NAME'"

# ── Create sprint directory and branch ───────────────────────────────
ensure_dir "$SPRINT_DIR"
create_sprint_branch "$WS_DIR" "$PROJECT_NAME" "$SPRINT_NUM" >/dev/null

project_state_write "$PROJECT_NAME" "current_sprint" "$SPRINT_NUM"
project_transition "$PROJECT_NAME" "sprinting"

# ── Start preview mechanism (if requested) ────────────────────────────
PREVIEW_PID=""

cleanup() {
    if [ -n "$PREVIEW_PID" ] && kill -0 "$PREVIEW_PID" 2>/dev/null; then
        echo ""
        log "Stopping preview process (PID: $PREVIEW_PID)"
        kill "$PREVIEW_PID" 2>/dev/null || true
        wait "$PREVIEW_PID" 2>/dev/null || true
    fi
    # Transition back to active
    project_state_write "$PROJECT_NAME" "status" "active"
}

trap cleanup EXIT INT TERM

if [ -n "$PREVIEW_CMD" ]; then
    log "Starting preview: $PREVIEW_CMD"
    PREVIEW_LOG="$SPRINT_DIR/.preview.log"

    (cd "$WS_DIR" && eval "$PREVIEW_CMD") > "$PREVIEW_LOG" 2>&1 &
    PREVIEW_PID=$!

    # Wait briefly for the preview to start
    sleep 3

    if ! kill -0 "$PREVIEW_PID" 2>/dev/null; then
        log_error "Preview process exited unexpectedly."
        echo "Log:"
        cat "$PREVIEW_LOG"
        exit 1
    fi

    log "Preview running (PID: $PREVIEW_PID)"
    echo ""
fi

# ── Build session prompt ──────────────────────────────────────────────
PROMPT="You are an interactive session agent for Hubris project '$PROJECT_NAME', sprint $SPRINT_NUM.

You are working with a human in real-time. This is a conversational, iterative session — not an autonomous sprint. Make changes, explain what you did, and ask for feedback.

## Environment

- Project: $PROJECT_NAME targeting repo $REPO_NAME
- Working repo: $WS_DIR (on branch $SPRINT_BRANCH)
- Project dir: $PROJECT_DIR
- Repo knowledge: $REPO_DIR/knowledge.md
- Repo skills: $REPO_DIR/skills/

## Inputs — Read These First

1. $PROJECT_DIR/intent.md — what we're building
2. $PROJECT_DIR/backlog.md — work items
3. $REPO_DIR/knowledge.md — repo conventions
4. Previous sprint journals in $PROJECT_DIR/sprints/ (if any)
5. $WS_DIR/docs/decisions/ — ADRs to respect

## Process

1. Read the inputs above
2. Discuss the approach with the human
3. Make changes iteratively:
   - Make one logical change at a time
   - Explain what you changed and why
   - Ask the human to check (in browser, tests, etc.)
   - Get feedback, adjust, repeat
4. Commit each meaningful change: git commit -m \"S$SPRINT_NUM: {description}\"
5. When the session is done:
   - Update $PROJECT_DIR/backlog.md (move done items, add discoveries)
   - Write $SPRINT_DIR/journal.md with what was accomplished
   - Commit the updates

## Rules

- Do NOT modify or delete files in docs/decisions/ or tests/acceptance/
- Make one change at a time for clear feedback loops
- Commit after each meaningful change
- Follow conventions from knowledge.md
- If the human requests something that conflicts with an ADR, mention the conflict"

if [ -n "$PREVIEW_CMD" ]; then
    PROMPT="$PROMPT

## Preview

A preview process is running: $PREVIEW_CMD
Changes to source files should be reflected automatically.
Tell the human to check their browser/terminal after each change."
fi

# ── Run the interactive session ──────────────────────────────────────
claude --system-prompt "$PROMPT" --dangerously-skip-permissions \
    "Read the project state and let's begin this interactive session. What would you like to work on?"

log "Interactive session complete."
echo ""
echo "  Journal: $SPRINT_DIR/journal.md"
echo "  Backlog: $PROJECT_DIR/backlog.md"
echo ""
echo "Next steps:"
echo "  Review changes: cd $WS_DIR && git log --oneline"
echo "  Create PR:      cd $WS_DIR && gh pr create"
echo "  Next sprint:    ./scripts/sprint.sh $PROJECT_NAME"

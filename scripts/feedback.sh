#!/bin/bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────
PROJECT_NAME="${1:-}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./scripts/feedback.sh <project-name> [message]"
    echo "       ./scripts/feedback.sh <project-name> --interactive"
    echo "       ./scripts/feedback.sh --system \"system improvement suggestion\""
    echo ""
    echo "Give feedback on a project or suggest system improvements."
    echo ""
    echo "Modes:"
    echo "  Quick:       ./scripts/feedback.sh my-project \"error messages need work\""
    echo "  Interactive: ./scripts/feedback.sh my-project --interactive"
    echo "  System:      ./scripts/feedback.sh --system \"team lead should check deps earlier\""
    exit 1
fi

# ── Bootstrap ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ── System feedback mode ─────────────────────────────────────────────
if [ "$PROJECT_NAME" = "--system" ]; then
    FEEDBACK="${2:-}"
    if [ -z "$FEEDBACK" ]; then
        echo "Usage: ./scripts/feedback.sh --system \"your improvement suggestion\""
        exit 1
    fi

    BACKLOG_FILE="$IMPROVEMENTS_DIR/backlog.md"
    ensure_dir "$IMPROVEMENTS_DIR"

    if [ ! -f "$BACKLOG_FILE" ]; then
        cat > "$BACKLOG_FILE" << 'EOF'
# System Improvement Backlog

Suggestions for improving Hubris itself.

## Pending

## Done
EOF
    fi

    # Append the feedback
    TIMESTAMP=$(timestamp)
    sed -i '' "/^## Pending/a\\
\\
- [ ] [$TIMESTAMP] $FEEDBACK" "$BACKLOG_FILE"

    log "System feedback recorded in $BACKLOG_FILE"
    exit 0
fi

# ── Project feedback ─────────────────────────────────────────────────
PROJECT_DIR=$(require_project "$PROJECT_NAME")
REPO_NAME=$(project_state_read "$PROJECT_NAME" "repo")
REPO_DIR="$REPOS_DIR/$REPO_NAME"
WS_DIR="$WORKSPACE_DIR/$REPO_NAME"

SPRINT_NUM=$(current_sprint "$PROJECT_NAME" 2>/dev/null || echo "0")
SPRINT_DIR=$(sprint_dir "$PROJECT_NAME" "$SPRINT_NUM")

MODE="${2:-}"

# ── Quick feedback mode ──────────────────────────────────────────────
if [ -n "$MODE" ] && [ "$MODE" != "--interactive" ]; then
    FEEDBACK="$MODE"

    REVIEW_FILE="$SPRINT_DIR/review.md"
    ensure_dir "$SPRINT_DIR"

    if [ ! -f "$REVIEW_FILE" ]; then
        echo "# Sprint $SPRINT_NUM Review" > "$REVIEW_FILE"
        echo "" >> "$REVIEW_FILE"
    fi

    TIMESTAMP=$(timestamp)
    echo "" >> "$REVIEW_FILE"
    echo "## Feedback ($TIMESTAMP)" >> "$REVIEW_FILE"
    echo "" >> "$REVIEW_FILE"
    echo "$FEEDBACK" >> "$REVIEW_FILE"

    log "Feedback recorded in $REVIEW_FILE"
    echo "  This will be incorporated in the next sprint."
    exit 0
fi

# ── Interactive feedback mode ────────────────────────────────────────
if [ "$MODE" = "--interactive" ]; then
    log "Launching interactive feedback session for '$PROJECT_NAME'"
    echo ""

    PROMPT_FILE="$PROMPTS_DIR/feedback_interviewer.md"
    if [ ! -f "$PROMPT_FILE" ]; then
        # Inline prompt if the file doesn't exist yet
        PROMPT="You are a feedback interviewer for Hubris project '$PROJECT_NAME'.

Your job is to interview the user about their experience with the latest sprint and capture structured feedback.

Read these files first:
- $PROJECT_DIR/intent.md (project intent)
- $PROJECT_DIR/backlog.md (current backlog)
- $SPRINT_DIR/journal.md (what happened in the sprint)
- $SPRINT_DIR/plan.md (what was planned)
- $SPRINT_DIR/questions.md (any open questions)
- $SPRINT_DIR/review.md (any existing feedback)

Then have a conversation:
1. Ask what they tested and what they observed
2. Ask clarifying questions to understand the root issue (not just symptoms)
3. Connect feedback to backlog items where possible
4. Suggest implications ('if X is wrong, Y might also need updating')
5. Ask if there's anything else

When the conversation is complete, write structured feedback to $SPRINT_DIR/review.md and update $PROJECT_DIR/backlog.md with any new items discovered.

Commit with message: 'review: sprint $SPRINT_NUM feedback for $PROJECT_NAME'"
    else
        PROMPT=$(render_prompt "$PROMPT_FILE" \
            "PROJECT_NAME=$PROJECT_NAME" \
            "PROJECT_DIR=$PROJECT_DIR" \
            "SPRINT_DIR=$SPRINT_DIR" \
            "SPRINT_NUM=$SPRINT_NUM" \
            "REPO_NAME=$REPO_NAME" \
            "WORKSPACE_DIR=$WS_DIR")
    fi

    claude --system-prompt "$PROMPT" --dangerously-skip-permissions \
        "I'd like to give feedback on sprint $SPRINT_NUM of project '$PROJECT_NAME'. Let's discuss what I observed."

    log "Feedback session complete."
    echo ""
    echo "  Review: $SPRINT_DIR/review.md"
    echo "  Backlog: $PROJECT_DIR/backlog.md"
    echo ""
    echo "Next: ./scripts/sprint.sh $PROJECT_NAME"
    exit 0
fi

# ── No feedback provided ─────────────────────────────────────────────
echo "Provide feedback as an argument or use --interactive:"
echo "  ./scripts/feedback.sh $PROJECT_NAME \"your feedback here\""
echo "  ./scripts/feedback.sh $PROJECT_NAME --interactive"
exit 1

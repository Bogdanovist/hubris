#!/bin/bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────
JOURNAL_COUNT="${1:-5}"

if [ "$JOURNAL_COUNT" = "--help" ] || [ "$JOURNAL_COUNT" = "-h" ]; then
    echo "Usage: ./scripts/retro.sh [journal-count]"
    echo ""
    echo "Run an auto-retrospective across recent sprint journals."
    echo "Identifies patterns, recurring issues, and proposes system improvements."
    echo ""
    echo "Arguments:"
    echo "  journal-count  Number of recent journals to review (default: 5)"
    echo ""
    echo "Proposed improvements are appended to improvements/backlog.md"
    echo "for user review and approval."
    exit 0
fi

# ── Bootstrap ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ── Collect recent sprint journals ───────────────────────────────────
log "Collecting last $JOURNAL_COUNT sprint journals across all projects..."

JOURNALS=()
for project_dir in "$PROJECTS_DIR"/*/; do
    [ -d "$project_dir" ] || continue
    project_name=$(basename "$project_dir")
    [ "$project_name" = "_completed" ] && continue

    for sprint_dir in "$project_dir"/sprints/*/; do
        [ -d "$sprint_dir" ] || continue
        journal="$sprint_dir/journal.md"
        [ -f "$journal" ] || continue
        JOURNALS+=("$journal")
    done
done

# Also check completed projects
if [ -d "$PROJECTS_DIR/_completed" ]; then
    for project_dir in "$PROJECTS_DIR/_completed"/*/; do
        [ -d "$project_dir" ] || continue
        for sprint_dir in "$project_dir"/sprints/*/; do
            [ -d "$sprint_dir" ] || continue
            journal="$sprint_dir/journal.md"
            [ -f "$journal" ] || continue
            JOURNALS+=("$journal")
        done
    done
fi

if [ ${#JOURNALS[@]} -eq 0 ]; then
    log "No sprint journals found. Run some sprints first."
    exit 0
fi

# Sort by modification time (most recent first) and take the last N
RECENT_JOURNALS=()
for journal in $(ls -t "${JOURNALS[@]}" 2>/dev/null | head -n "$JOURNAL_COUNT"); do
    RECENT_JOURNALS+=("$journal")
done

log "Found ${#RECENT_JOURNALS[@]} journals to review."
echo ""

# Also collect outcome files if they exist
OUTCOMES=()
for journal in "${RECENT_JOURNALS[@]}"; do
    outcome_file="$(dirname "$journal")/outcome.yaml"
    if [ -f "$outcome_file" ]; then
        OUTCOMES+=("$outcome_file")
    fi
done

# ── Build journal list for the prompt ────────────────────────────────
JOURNAL_LIST=""
for journal in "${RECENT_JOURNALS[@]}"; do
    JOURNAL_LIST="$JOURNAL_LIST- $journal
"
done

OUTCOME_LIST=""
for outcome in "${OUTCOMES[@]}"; do
    OUTCOME_LIST="$OUTCOME_LIST- $outcome
"
done

# ── Launch retro agent ───────────────────────────────────────────────
PROMPT_FILE="$PROMPTS_DIR/retro.md"
if [ ! -f "$PROMPT_FILE" ]; then
    log_error "Retro prompt not found at $PROMPT_FILE"
    exit 1
fi

PROMPT=$(render_prompt "$PROMPT_FILE" \
    "IMPROVEMENTS_DIR=$IMPROVEMENTS_DIR" \
    "JOURNAL_COUNT=$JOURNAL_COUNT")

# Build the file list into the initial message
FILES_MSG="Review these sprint journals:
$JOURNAL_LIST"

if [ -n "$OUTCOME_LIST" ]; then
    FILES_MSG="$FILES_MSG
And these sprint outcomes:
$OUTCOME_LIST"
fi

claude --system-prompt "$PROMPT" --dangerously-skip-permissions \
    "$FILES_MSG

Analyse these journals for patterns and propose system improvements."

log "Retro complete. Check improvements/backlog.md for proposals."

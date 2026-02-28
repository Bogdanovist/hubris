#!/bin/bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────
PROJECT_NAME="${1:-}"

# ── Bootstrap ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ── Single project detail ────────────────────────────────────────────
if [ -n "$PROJECT_NAME" ]; then
    PROJECT_DIR=$(require_project "$PROJECT_NAME")

    status=$(project_state_read "$PROJECT_NAME" "status" 2>/dev/null || echo "unknown")
    repo=$(project_state_read "$PROJECT_NAME" "repo" 2>/dev/null || echo "unknown")
    sprint=$(current_sprint "$PROJECT_NAME" 2>/dev/null || echo "0")
    created=$(project_state_read "$PROJECT_NAME" "created" 2>/dev/null || echo "unknown")

    echo "Project: $PROJECT_NAME"
    echo "  Status:  $status"
    echo "  Repo:    $repo"
    echo "  Sprint:  $sprint"
    echo "  Created: $created"
    echo "  Dir:     $PROJECT_DIR"
    echo ""

    # Show sprint history
    SPRINTS_DIR="$PROJECT_DIR/sprints"
    if [ -d "$SPRINTS_DIR" ]; then
        sprint_count=$(find "$SPRINTS_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        if [ "$sprint_count" -gt 0 ]; then
            echo "  Sprints:"
            for sprint_dir in "$SPRINTS_DIR"/*/; do
                [ -d "$sprint_dir" ] || continue
                sprint_num=$(basename "$sprint_dir")
                has_journal=""
                has_review=""
                [ -f "$sprint_dir/journal.md" ] && has_journal=" [journal]"
                [ -f "$sprint_dir/review.md" ] && has_review=" [reviewed]"
                echo "    $sprint_num$has_journal$has_review"
            done
            echo ""
        fi
    fi

    # Show backlog summary
    BACKLOG="$PROJECT_DIR/backlog.md"
    if [ -f "$BACKLOG" ]; then
        ready_count=$(grep -c '^\- \[ \]' "$BACKLOG" 2>/dev/null || echo "0")
        done_count=$(grep -c '^\- \[x\]' "$BACKLOG" 2>/dev/null || echo "0")
        echo "  Backlog: $ready_count ready, $done_count done"
    fi

    exit 0
fi

# ── All projects overview ────────────────────────────────────────────
echo "=== Hubris Projects ==="
echo ""

has_projects=false

for project_dir in "$PROJECTS_DIR"/*/; do
    [ -d "$project_dir" ] || continue
    project_name=$(basename "$project_dir")
    [ "$project_name" = "_completed" ] && continue

    has_projects=true

    status=$(project_state_read "$project_name" "status" 2>/dev/null || echo "unknown")
    repo=$(project_state_read "$project_name" "repo" 2>/dev/null || echo "?")
    sprint=$(current_sprint "$project_name" 2>/dev/null || echo "0")

    printf "  %-25s %-12s repo:%-15s sprint:%s\n" "$project_name" "[$status]" "$repo" "$sprint"
done

if [ "$has_projects" = false ]; then
    echo "  No active projects."
    echo ""
    echo "  Create one: ./scripts/init.sh <project-name> <repo-name>"
fi

# Show completed projects count
COMPLETED_DIR="$PROJECTS_DIR/_completed"
if [ -d "$COMPLETED_DIR" ]; then
    completed_count=$(find "$COMPLETED_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    if [ "$completed_count" -gt 0 ]; then
        echo ""
        echo "  ($completed_count completed projects in _completed/)"
    fi
fi

echo ""

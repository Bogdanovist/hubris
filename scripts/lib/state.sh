#!/bin/bash
# State read/write helpers for YAML project state

# ── YAML helpers ─────────────────────────────────────────────────────
# Simple YAML reading without external dependencies.
# For complex YAML operations, use python -c "import yaml; ..."

# Read a top-level key from a YAML file
# Usage: yaml_read state.yaml "status"
yaml_read() {
    local file="$1"
    local key="$2"
    if [ ! -f "$file" ]; then
        return 1
    fi
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}: *//" | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//"
}

# Write a top-level key to a YAML file (creates or updates)
# Usage: yaml_write state.yaml "status" "active"
yaml_write() {
    local file="$1"
    local key="$2"
    local value="$3"
    if [ ! -f "$file" ]; then
        echo "${key}: \"${value}\"" > "$file"
        return
    fi
    if grep -q "^${key}:" "$file" 2>/dev/null; then
        sed -i '' "s|^${key}:.*|${key}: \"${value}\"|" "$file"
    else
        echo "${key}: \"${value}\"" >> "$file"
    fi
}

# ── Project state ────────────────────────────────────────────────────
# Get the state file path for a project
project_state_file() {
    local project_name="$1"
    echo "$PROJECTS_DIR/$project_name/state.yaml"
}

# Read a project state field
# Usage: project_state_read my-project "status"
project_state_read() {
    local project_name="$1"
    local key="$2"
    yaml_read "$(project_state_file "$project_name")" "$key"
}

# Write a project state field
# Usage: project_state_write my-project "status" "active"
project_state_write() {
    local project_name="$1"
    local key="$2"
    local value="$3"
    yaml_write "$(project_state_file "$project_name")" "$key" "$value"
}

# Get the current sprint number for a project
current_sprint() {
    local project_name="$1"
    project_state_read "$project_name" "current_sprint"
}

# Get the next sprint number (current + 1, or 1 if none)
next_sprint() {
    local project_name="$1"
    local current
    current=$(current_sprint "$project_name" 2>/dev/null || echo "0")
    if [ -z "$current" ] || [ "$current" = "0" ]; then
        echo "1"
    else
        echo $((current + 1))
    fi
}

# Format sprint number with zero-padding (e.g., 1 → 001)
format_sprint() {
    printf "%03d" "$1"
}

# Get the sprint directory for a project
sprint_dir() {
    local project_name="$1"
    local sprint_num="$2"
    echo "$PROJECTS_DIR/$project_name/sprints/$(format_sprint "$sprint_num")"
}

# ── Repo state ───────────────────────────────────────────────────────
# Read a repo config field
# Usage: repo_config_read my-app "language"
repo_config_read() {
    local repo_name="$1"
    local key="$2"
    yaml_read "$REPOS_DIR/$repo_name/config.yaml" "$key"
}

# Check if a repo has an active sprint (repo exclusivity)
repo_has_active_sprint() {
    local repo_name="$1"
    for project_dir in "$PROJECTS_DIR"/*/; do
        [ -d "$project_dir" ] || continue
        local project_name
        project_name=$(basename "$project_dir")
        [ "$project_name" = "_completed" ] && continue
        local project_repo
        project_repo=$(project_state_read "$project_name" "repo" 2>/dev/null || true)
        local project_status
        project_status=$(project_state_read "$project_name" "status" 2>/dev/null || true)
        if [ "$project_repo" = "$repo_name" ] && [ "$project_status" = "sprinting" ]; then
            echo "$project_name"
            return 0
        fi
    done
    return 1
}

# ── State transitions ────────────────────────────────────────────────
# Valid transitions: created → active → sprinting → active → completed
# Also: any → paused → (previous state)

# Transition a project to a new status with validation
# Usage: project_transition my-project "active"
project_transition() {
    local project_name="$1"
    local new_status="$2"
    local current_status
    current_status=$(project_state_read "$project_name" "status" 2>/dev/null || echo "unknown")

    case "$new_status" in
        active)
            if [ "$current_status" != "created" ] && [ "$current_status" != "sprinting" ] && [ "$current_status" != "paused" ]; then
                log_error "Cannot transition from '$current_status' to 'active'"
                return 1
            fi
            ;;
        sprinting)
            if [ "$current_status" != "active" ]; then
                log_error "Cannot transition from '$current_status' to 'sprinting'. Must be 'active'."
                return 1
            fi
            ;;
        paused)
            project_state_write "$project_name" "paused_from" "$current_status"
            ;;
        completed)
            if [ "$current_status" != "active" ]; then
                log_error "Cannot complete project from '$current_status'. Must be 'active'."
                return 1
            fi
            ;;
        *)
            log_error "Unknown status: $new_status"
            return 1
            ;;
    esac

    project_state_write "$project_name" "status" "$new_status"
}

# List all active projects
list_projects() {
    local status_filter="${1:-}"
    for project_dir in "$PROJECTS_DIR"/*/; do
        [ -d "$project_dir" ] || continue
        local project_name
        project_name=$(basename "$project_dir")
        [ "$project_name" = "_completed" ] && continue
        if [ -n "$status_filter" ]; then
            local status
            status=$(project_state_read "$project_name" "status" 2>/dev/null || true)
            [ "$status" = "$status_filter" ] || continue
        fi
        echo "$project_name"
    done
}

# Get the repo workspace path for a project
project_workspace() {
    local project_name="$1"
    local repo_name
    repo_name=$(project_state_read "$project_name" "repo")
    echo "$WORKSPACE_DIR/$repo_name"
}

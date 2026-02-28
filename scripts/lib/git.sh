#!/bin/bash
# Git operations for sprint branches and PRs

# ── Branch operations ────────────────────────────────────────────────
# Create a sprint branch from main
# Usage: create_sprint_branch /path/to/repo project-name 1
create_sprint_branch() {
    local repo_path="$1"
    local project_name="$2"
    local sprint_num="$3"
    local branch_name="${project_name}/sprint-$(format_sprint "$sprint_num")"

    (
        cd "$repo_path"
        git fetch origin 2>/dev/null || true
        local default_branch
        default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")
        git checkout "$default_branch"
        git pull origin "$default_branch" 2>/dev/null || true
        git checkout -b "$branch_name"
    )
    echo "$branch_name"
}

# Get the default branch for a repo
default_branch() {
    local repo_path="$1"
    (
        cd "$repo_path"
        git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main"
    )
}

# ── PR operations ────────────────────────────────────────────────────
# Create a PR for the current branch
# Usage: create_sprint_pr /path/to/repo "Sprint 1: Add auth module" "body text"
create_sprint_pr() {
    local repo_path="$1"
    local title="$2"
    local body="$3"

    (
        cd "$repo_path"
        local current_branch
        current_branch=$(git branch --show-current)
        git push -u origin "$current_branch"
        gh pr create --title "$title" --body "$body"
    )
}

# ── Rebase operations ────────────────────────────────────────────────
# Rebase sprint branch onto latest main before PR
# Returns 0 on success, 1 on conflict
rebase_onto_main() {
    local repo_path="$1"
    (
        cd "$repo_path"
        local default
        default=$(default_branch "$repo_path")
        git fetch origin "$default"
        if ! git rebase "origin/$default" 2>/dev/null; then
            git rebase --abort 2>/dev/null || true
            return 1
        fi
    )
}

# ── Context change detection ────────────────────────────────────────
# Paths that affect team conventions and require team-wide review.
# Changes to these files get a separate "context PR" for team discussion.
CONTEXT_PATHS=(".ai/skills" "docs/decisions" "docs/architecture.md" "tests/acceptance" "CLAUDE.md" ".cursorrules" ".github/copilot-instructions.md")

# Check if the current branch has context changes vs main
# Usage: has_context_changes /path/to/repo
has_context_changes() {
    local repo_path="$1"
    (
        cd "$repo_path"
        local default
        default=$(default_branch "$repo_path")
        for ctx_path in "${CONTEXT_PATHS[@]}"; do
            if git diff "origin/$default" --name-only | grep -q "^${ctx_path}"; then
                return 0
            fi
        done
        return 1
    )
}

# List context files changed in current branch vs main
# Usage: list_context_changes /path/to/repo
list_context_changes() {
    local repo_path="$1"
    (
        cd "$repo_path"
        local default
        default=$(default_branch "$repo_path")
        for ctx_path in "${CONTEXT_PATHS[@]}"; do
            git diff "origin/$default" --name-only | grep "^${ctx_path}" || true
        done
    )
}

# Create a context-only branch from main with context file changes from sprint branch
# Usage: create_context_branch /path/to/repo sprint-branch-name
# Outputs the context branch name, or empty string if no context changes
create_context_branch() {
    local repo_path="$1"
    local sprint_branch="$2"
    local context_branch="${sprint_branch}-context"
    (
        cd "$repo_path"
        local default
        default=$(default_branch "$repo_path")
        git checkout -b "$context_branch" "origin/$default"
        for ctx_path in "${CONTEXT_PATHS[@]}"; do
            git checkout "$sprint_branch" -- "$ctx_path" 2>/dev/null || true
        done
        git add -A
        if git diff --cached --quiet; then
            # No context changes to commit
            git checkout "$sprint_branch"
            git branch -D "$context_branch" 2>/dev/null || true
            echo ""
            return 1
        fi
        git commit -m "Context changes for team review"
        echo "$context_branch"
    )
}

# ── Workspace helpers ────────────────────────────────────────────────
# Get the workspace path for a repo
workspace_path() {
    local repo_name="$1"
    echo "$WORKSPACE_DIR/$repo_name"
}

# Check if a workspace exists and is a git repo
validate_workspace() {
    local repo_name="$1"
    local ws
    ws=$(workspace_path "$repo_name")
    if [ ! -d "$ws" ]; then
        log_error "Workspace not found at $ws"
        return 1
    fi
    if [ ! -d "$ws/.git" ]; then
        log_warn "Workspace at $ws is not a git repository"
    fi
}

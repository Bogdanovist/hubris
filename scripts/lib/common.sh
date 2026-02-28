#!/bin/bash
# Shared utilities for hubris scripts
# Source this file: source "$(dirname "$0")/lib/common.sh"

set -euo pipefail

# ── Resolve hubris root ──────────────────────────────────────────
# Works whether sourced from scripts/ or scripts/lib/
HUBRIS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ── Directories ──────────────────────────────────────────────────────
PROJECTS_DIR="$HUBRIS_ROOT/projects"
REPOS_DIR="$HUBRIS_ROOT/repos"
WORKSPACE_DIR="$HUBRIS_ROOT/workspace"
PROMPTS_DIR="$HUBRIS_ROOT/prompts"
IMPROVEMENTS_DIR="$HUBRIS_ROOT/improvements"
SKILL_BANK_DIR="$HUBRIS_ROOT/skill-bank"

# ── Logging ──────────────────────────────────────────────────────────
log() {
    echo "[hubris] $*"
}

log_error() {
    echo "[hubris] ERROR: $*" >&2
}

log_warn() {
    echo "[hubris] WARN: $*" >&2
}

# ── Validation ───────────────────────────────────────────────────────
validate_name() {
    local name="$1"
    local label="${2:-name}"
    if ! echo "$name" | grep -qE '^[a-z][a-z0-9._-]*$'; then
        log_error "$label must be lowercase, start with a letter, and contain only letters, numbers, hyphens, dots, or underscores."
        return 1
    fi
}

require_project() {
    local project_name="$1"
    local project_dir="$PROJECTS_DIR/$project_name"
    if [ ! -d "$project_dir" ]; then
        log_error "Project '$project_name' not found at $project_dir"
        return 1
    fi
    echo "$project_dir"
}

require_repo() {
    local repo_name="$1"
    local repo_dir="$REPOS_DIR/$repo_name"
    if [ ! -d "$repo_dir" ]; then
        log_error "Repo '$repo_name' not registered. Run: ./scripts/repo_init.sh $repo_name <git-url>"
        return 1
    fi
    echo "$repo_dir"
}

# ── Template rendering ───────────────────────────────────────────────
# Render a prompt template with variable substitutions
# Usage: render_prompt prompts/team_lead.md VAR1=value1 VAR2=value2
render_prompt() {
    local template_file="$1"
    shift
    if [ ! -f "$template_file" ]; then
        log_error "Prompt template not found: $template_file"
        return 1
    fi
    local content
    content=$(cat "$template_file")
    for pair in "$@"; do
        local key="${pair%%=*}"
        local value="${pair#*=}"
        content=$(echo "$content" | sed "s|{$key}|$value|g")
    done
    echo "$content"
}

# ── Date helpers ─────────────────────────────────────────────────────
today() {
    date +%Y-%m-%d
}

timestamp() {
    date +%Y-%m-%dT%H:%M:%S
}

# ── File helpers ─────────────────────────────────────────────────────
ensure_dir() {
    mkdir -p "$1"
}

# Source additional libraries
source "$HUBRIS_ROOT/scripts/lib/notify.sh"
source "$HUBRIS_ROOT/scripts/lib/state.sh"
source "$HUBRIS_ROOT/scripts/lib/git.sh"
source "$HUBRIS_ROOT/scripts/lib/guardrails.sh"

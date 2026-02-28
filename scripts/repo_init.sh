#!/bin/bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────
REPO_NAME="${1:-}"
REMOTE_URL="${2:-}"

if [ -z "$REPO_NAME" ]; then
    echo "Usage: ./scripts/repo_init.sh <repo-name> [git-remote-url]"
    echo ""
    echo "Register a repository for hubris management."
    echo "Clones the repo, runs an interactive initialization agent,"
    echo "and produces config.yaml + knowledge.md."
    echo ""
    echo "Examples:"
    echo "  ./scripts/repo_init.sh my-api git@github.com:org/my-api.git"
    echo "  ./scripts/repo_init.sh my-api    # uses existing workspace/my-api/"
    exit 1
fi

# ── Bootstrap ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ── Validate naming ──────────────────────────────────────────────────
validate_name "$REPO_NAME" "Repo name"

REPO_DIR="$REPOS_DIR/$REPO_NAME"
TEMPLATE_DIR="$REPOS_DIR/_template"
WS_DIR="$WORKSPACE_DIR/$REPO_NAME"

# ── Clone or validate workspace ──────────────────────────────────────
if [ -n "$REMOTE_URL" ] && [ ! -d "$WS_DIR" ]; then
    log "Cloning $REMOTE_URL to $WS_DIR"
    ensure_dir "$WORKSPACE_DIR"
    git clone "$REMOTE_URL" "$WS_DIR"
    log "Clone complete."
elif [ -n "$REMOTE_URL" ] && [ -d "$WS_DIR" ]; then
    log "Workspace already exists at $WS_DIR — skipping clone."
elif [ -z "$REMOTE_URL" ] && [ ! -d "$WS_DIR" ]; then
    log_error "No remote URL provided and workspace not found at $WS_DIR"
    echo ""
    echo "Either:"
    echo "  1. Provide a remote URL:  ./scripts/repo_init.sh $REPO_NAME <git-remote-url>"
    echo "  2. Manually clone/copy to: $WS_DIR"
    exit 1
fi

if [ ! -d "$WS_DIR" ]; then
    log_error "Workspace not found at $WS_DIR after setup."
    exit 1
fi

# ── Create repo config from template ─────────────────────────────────
if [ ! -d "$REPO_DIR" ]; then
    if [ ! -d "$TEMPLATE_DIR" ]; then
        log_error "Template not found at $TEMPLATE_DIR"
        exit 1
    fi

    log "Creating repo config from template"
    cp -r "$TEMPLATE_DIR" "$REPO_DIR"
    mkdir -p "$REPO_DIR/skills"

    # Fill basic config.yaml fields
    CONFIG_FILE="$REPO_DIR/config.yaml"
    if [ -f "$CONFIG_FILE" ]; then
        sed -i '' "s|^name: .*|name: \"$REPO_NAME\"|" "$CONFIG_FILE"
        sed -i '' "s|^remote: .*|remote: \"${REMOTE_URL:-}\"|" "$CONFIG_FILE"
        sed -i '' "s|^registered: .*|registered: \"$(today)\"|" "$CONFIG_FILE"
    fi

    log "Config created at $REPO_DIR/config.yaml"
else
    log "Repo config already exists at $REPO_DIR — skipping template copy."
fi

# ── Validate workspace is a git repo ─────────────────────────────────
if [ ! -d "$WS_DIR/.git" ]; then
    log_warn "$WS_DIR is not a git repository. Sprint workflows require git."
fi

# ── Set up repo convention structure ─────────────────────────────────
log "Setting up repo convention structure"

# Create convention directories if they don't exist
for dir in ".ai/skills" "docs/decisions" "tests/acceptance"; do
    if [ ! -d "$WS_DIR/$dir" ]; then
        mkdir -p "$WS_DIR/$dir"
        log "  Created $dir/"
    fi
done

# Create architecture.md if it doesn't exist
if [ ! -f "$WS_DIR/docs/architecture.md" ]; then
    echo "# Architecture" > "$WS_DIR/docs/architecture.md"
    echo "" >> "$WS_DIR/docs/architecture.md"
    echo "System architecture overview. Updated as the system evolves." >> "$WS_DIR/docs/architecture.md"
    log "  Created docs/architecture.md"
fi

# ── Launch interactive repo initialization agent ─────────────────────
echo ""
log "Launching repo initialization agent"
echo "The agent will explore the codebase and fill in config.yaml and knowledge.md."
echo ""

PROMPT_FILE="$PROMPTS_DIR/repo_init.md"
if [ -f "$PROMPT_FILE" ]; then
    PROMPT=$(sed \
        -e "s|{REPO_NAME}|$REPO_NAME|g" \
        -e "s|{WORKSPACE_DIR}|$WS_DIR|g" \
        -e "s|{REPO_DIR}|$REPO_DIR|g" \
        "$PROMPT_FILE")

    claude --system-prompt "$PROMPT" --dangerously-skip-permissions \
        "Explore the codebase at $WS_DIR and fill in the repo configuration and knowledge files."
else
    log_warn "No repo_init prompt found at $PROMPT_FILE"
    echo "Skipping interactive initialization. Please fill in config.yaml manually."
fi

# ── Skills reconciliation ─────────────────────────────────────────────
RECONCILE_SCRIPT="$SCRIPT_DIR/reconcile_skills.sh"
if [ -f "$RECONCILE_SCRIPT" ]; then
    echo ""
    log "Checking skill bank for relevant skills..."
    bash "$RECONCILE_SCRIPT" "$REPO_NAME" --interactive
fi

echo ""
log "Repo '$REPO_NAME' initialized."
echo ""
echo "  Config:    $REPO_DIR/config.yaml"
echo "  Knowledge: $REPO_DIR/knowledge.md"
echo "  Skills:    $REPO_DIR/skills/"
echo "  Workspace: $WS_DIR"
echo ""
echo "Next steps:"
echo "  1. Review $REPO_DIR/config.yaml (especially check commands)"
echo "  2. Create a project: ./scripts/init.sh <project-name> $REPO_NAME"

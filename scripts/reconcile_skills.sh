#!/bin/bash
set -euo pipefail

# ── Usage ─────────────────────────────────────────────────────────────
REPO_NAME="${1:-}"

if [ -z "$REPO_NAME" ]; then
    echo "Usage: ./scripts/reconcile_skills.sh <repo-name> [--interactive]"
    echo ""
    echo "Compare skill-bank templates against a repo's skills using agent reasoning."
    echo "Reads the content of all skills and produces a semantic assessment of coverage."
    echo ""
    echo "Modes:"
    echo "  Default:     Print assessment (gaps, overlaps, recommendations)"
    echo "  Interactive: After assessment, offer to copy recommended skills"
    exit 1
fi

INTERACTIVE=false
if [ "${2:-}" = "--interactive" ]; then
    INTERACTIVE=true
fi

# ── Bootstrap ─────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ── Validate ──────────────────────────────────────────────────────────
require_repo "$REPO_NAME" >/dev/null

REPO_SKILLS_DIR="$REPOS_DIR/$REPO_NAME/skills"
ensure_dir "$REPO_SKILLS_DIR"

# ── Gather skill content ─────────────────────────────────────────────
BANK_CONTENT=""
BANK_COUNT=0
for bank_skill in "$SKILL_BANK_DIR"/*.md; do
    [ -f "$bank_skill" ] || continue
    skill_name=$(basename "$bank_skill")
    BANK_CONTENT+="
--- BANK SKILL: $skill_name ---
$(cat "$bank_skill")

"
    BANK_COUNT=$((BANK_COUNT + 1))
done

REPO_CONTENT=""
REPO_COUNT=0
for repo_skill in "$REPO_SKILLS_DIR"/*.md; do
    [ -f "$repo_skill" ] || continue
    skill_name=$(basename "$repo_skill")
    REPO_CONTENT+="
--- REPO SKILL: $skill_name ---
$(cat "$repo_skill")

"
    REPO_COUNT=$((REPO_COUNT + 1))
done

# ── Quick exit if nothing to compare ──────────────────────────────────
if [ "$BANK_COUNT" -eq 0 ]; then
    log "No skills in the skill bank. Nothing to reconcile."
    exit 0
fi

if [ "$REPO_COUNT" -eq 0 ]; then
    echo "=== Skills Reconciliation: $REPO_NAME ==="
    echo ""
    echo "  Repo has no skills yet. All $BANK_COUNT bank templates are gaps."
    echo "  Bank skills:"
    for bank_skill in "$SKILL_BANK_DIR"/*.md; do
        [ -f "$bank_skill" ] || continue
        echo "    - $(basename "$bank_skill")"
    done
    echo ""

    if [ "$INTERACTIVE" = true ]; then
        echo "Copy bank skills to repo? (Each skill should be adapted to repo conventions.)"
        echo ""
        for bank_skill in "$SKILL_BANK_DIR"/*.md; do
            [ -f "$bank_skill" ] || continue
            skill_name=$(basename "$bank_skill")
            echo -n "  Copy $skill_name? (y/N) "
            read -r -n 1 REPLY
            echo ""
            if [[ "$REPLY" =~ ^[Yy]$ ]]; then
                cp "$bank_skill" "$REPO_SKILLS_DIR/$skill_name"
                log "  Copied $skill_name"
            fi
        done
    fi
    exit 0
fi

# ── Build prompt ──────────────────────────────────────────────────────
PROMPT_FILE="$PROMPTS_DIR/reconcile_skills.md"
if [ ! -f "$PROMPT_FILE" ]; then
    log_error "Reconciliation prompt not found at $PROMPT_FILE"
    exit 1
fi

SYSTEM_PROMPT=$(cat "$PROMPT_FILE")

echo "=== Skills Reconciliation: $REPO_NAME ==="
echo "  Bank: $BANK_COUNT skills | Repo: $REPO_COUNT skills"
echo "  Running agent comparison..."
echo ""

# ── Run agent ─────────────────────────────────────────────────────────
ASSESSMENT=$(claude --system-prompt "$SYSTEM_PROMPT" --print \
    "Compare these skill sets for repo '$REPO_NAME':

SKILL BANK TEMPLATES:
$BANK_CONTENT

REPO SKILLS:
$REPO_CONTENT")

echo "$ASSESSMENT"
echo ""

# ── Interactive mode: offer to copy gap skills ────────────────────────
if [ "$INTERACTIVE" = true ]; then
    # Extract gap skill names from the assessment (lines starting with "- **filename.md**" under Gaps)
    GAP_SKILLS=()
    while IFS= read -r line; do
        # Match lines like "- **testing.md**:" or "- **api_development.md**:"
        if echo "$line" | grep -qE '^\- \*\*[a-zA-Z0-9_.-]+\.md\*\*'; then
            skill_name=$(echo "$line" | sed 's/^- \*\*\([a-zA-Z0-9_.-]*\.md\)\*\*.*/\1/')
            if [ -f "$SKILL_BANK_DIR/$skill_name" ]; then
                GAP_SKILLS+=("$skill_name")
            fi
        fi
    done <<< "$(echo "$ASSESSMENT" | sed -n '/### Gaps/,/### /p')"

    if [ ${#GAP_SKILLS[@]} -gt 0 ]; then
        echo "Copy recommended bank skills to repo?"
        echo ""
        for skill in "${GAP_SKILLS[@]}"; do
            echo -n "  Copy $skill? (y/N) "
            read -r -n 1 REPLY
            echo ""
            if [[ "$REPLY" =~ ^[Yy]$ ]]; then
                cp "$SKILL_BANK_DIR/$skill" "$REPO_SKILLS_DIR/$skill"
                log "  Copied $skill"
            fi
        done
        echo ""
    fi
fi

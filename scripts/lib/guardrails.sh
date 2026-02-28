#!/bin/bash
# ADR and guardrails helpers

# ── ADR operations ───────────────────────────────────────────────────

# Get the next ADR number for a workspace
# Usage: next_adr_number /path/to/workspace
next_adr_number() {
    local workspace_dir="$1"
    local decisions_dir="$workspace_dir/docs/decisions"
    ensure_dir "$decisions_dir"

    local max=0
    for adr_file in "$decisions_dir"/[0-9]*.md; do
        [ -f "$adr_file" ] || continue
        local num
        num=$(basename "$adr_file" | grep -oE '^[0-9]+' || echo "0")
        if [ "$num" -gt "$max" ]; then
            max=$num
        fi
    done
    printf "%03d" $((max + 1))
}

# List existing ADRs in a workspace
# Usage: list_adrs /path/to/workspace
list_adrs() {
    local workspace_dir="$1"
    local decisions_dir="$workspace_dir/docs/decisions"

    if [ ! -d "$decisions_dir" ]; then
        echo "  No docs/decisions/ directory found."
        return
    fi

    local found=false
    for adr_file in "$decisions_dir"/[0-9]*.md; do
        [ -f "$adr_file" ] || continue
        found=true
        local filename
        filename=$(basename "$adr_file")
        local title
        title=$(head -1 "$adr_file" | sed 's/^# //')
        echo "  $filename — $title"
    done

    if [ "$found" = false ]; then
        echo "  No ADRs found."
    fi
}

# Create a new ADR from template
# Usage: create_adr /path/to/workspace "Use SQLCipher for storage"
create_adr() {
    local workspace_dir="$1"
    local title="$2"
    local decisions_dir="$workspace_dir/docs/decisions"
    ensure_dir "$decisions_dir"

    local num
    num=$(next_adr_number "$workspace_dir")
    local slug
    slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')
    local filename="${num}-${slug}.md"
    local filepath="$decisions_dir/$filename"

    cat > "$filepath" << EOF
# $num: $title

## Context

What situation prompted this decision.

## Decision

What was decided.

## Constraints

What must remain true as a result of this decision.

## Consequences

What follows from this decision.
EOF

    echo "$filepath"
}

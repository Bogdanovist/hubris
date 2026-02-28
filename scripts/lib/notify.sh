#!/bin/bash
# macOS notification helpers

# ── Notifications ────────────────────────────────────────────────────
# Send a macOS notification via osascript
# Usage: notify "Title" "Message body"
notify() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"Hubris: $title\"" 2>/dev/null || true
}

# Convenience wrappers for common notification types
notify_sprint_complete() {
    local project="$1"
    local sprint="$2"
    notify "Sprint Complete" "$project sprint $sprint complete. PR ready for review."
}

notify_question() {
    local project="$1"
    local summary="$2"
    notify "Need Input" "$project: $summary"
}

notify_blocked() {
    local project="$1"
    local reason="$2"
    notify "Blocked" "$project: $reason"
}

notify_error() {
    local project="$1"
    local message="$2"
    notify "Error" "$project: $message"
}

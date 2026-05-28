#!/usr/bin/env bash
# =============================================================================
# lib/session.sh â Session state management
# =============================================================================
# Tracks claude-ac session state across retries: working directory,
# start time, retry count, and any session ID extracted from output.
# =============================================================================

CLAUDE_AC_STATE_DIR="${CLAUDE_AC_STATE_DIR:-${HOME}/.cache/claude-ac}"

# ---------------------------------------------------------------------------
# save_session_state <cwd> <retry_count> [session_id]
# ---------------------------------------------------------------------------
save_session_state() {
    local cwd="$1"
    local retry_count="$2"
    local session_id="${3:-}"

    mkdir -p "$CLAUDE_AC_STATE_DIR"
    cat > "$CLAUDE_AC_STATE_DIR/state.json" <<EOF
{
  "cwd": "$cwd",
  "retry_count": $retry_count,
  "session_id": "$session_id",
  "start_time": "$_START_TIME",
  "last_updated": "$(date +%s)"
}
EOF
}

# ---------------------------------------------------------------------------
# load_session_state
# Prints the JSON state or an empty object if no state file exists.
# ---------------------------------------------------------------------------
load_session_state() {
    local state_file="$CLAUDE_AC_STATE_DIR/state.json"
    if [[ -f "$state_file" ]]; then
        cat "$state_file"
    else
        echo '{}'
    fi
}

# ---------------------------------------------------------------------------
# clear_session_state
# ---------------------------------------------------------------------------
clear_session_state() {
    rm -f "$CLAUDE_AC_STATE_DIR/state.json"
}

# ---------------------------------------------------------------------------
# get_total_runtime_secs
# Returns seconds elapsed since the first invocation.
# ---------------------------------------------------------------------------
get_total_runtime_secs() {
    echo $(( $(date +%s) - _START_TIME ))
}

# ---------------------------------------------------------------------------
# format_duration <secs>
# Converts a duration in seconds to a human-readable string.
# ---------------------------------------------------------------------------
format_duration() {
    local secs="$1"
    local h=$(( secs / 3600 ))
    local m=$(( (secs % 3600) / 60 ))
    local s=$(( secs % 60 ))
    printf "%02dh %02dm %02ds" "$h" "$m" "$s"
}

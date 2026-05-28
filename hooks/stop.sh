#!/usr/bin/env bash
# =============================================================================
# hooks/stop.sh â Claude Code Stop Hook
# =============================================================================
# Registered in ~/.claude/settings.json under hooks.Stop.
# Fires every time Claude Code stops a session. Reads the hook context
# from stdin (JSON), checks the transcript for credit exhaustion, and if
# detected spawns a background daemon that will run `claude --continue`
# once credits reset.
#
# Install via: claude-ac install-hook
# Manual install: add to ~/.claude/settings.json (see README)
# =============================================================================

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$HOOK_DIR/../lib" && pwd)"
CONFIG_DIR="$(cd "$HOOK_DIR/../config" && pwd)"

source "$LIB_DIR/detect.sh"
source "$LIB_DIR/notify.sh"
source "$LIB_DIR/session.sh"
source "$CONFIG_DIR/defaults.sh"

# ---------------------------------------------------------------------------
# Read hook context from stdin (Claude Code passes JSON)
# ---------------------------------------------------------------------------
HOOK_INPUT=""
if read -t 2 -r HOOK_INPUT 2>/dev/null; then
    :
fi

# Parse fields from JSON (minimal parser, no jq dependency)
parse_json_field() {
    local json="$1"
    local field="$2"
    echo "$json" | grep -oP "\"${field}\":\s*\K\"[^\"]+\"" | tr -d '"' | head -1
}

TRANSCRIPT_PATH=$(parse_json_field "$HOOK_INPUT" "transcript_path")
SESSION_ID=$(parse_json_field "$HOOK_INPUT" "session_id")
SESSION_CWD=$(parse_json_field "$HOOK_INPUT" "cwd")
STOP_HOOK_ACTIVE=$(parse_json_field "$HOOK_INPUT" "stop_hook_active")

log_hook() {
    local msg="$1"
    local log_dir="${HOME}/.cache/claude-ac"
    mkdir -p "$log_dir"
    echo "[HOOK $(date '+%H:%M:%S')] $msg" >> "$log_dir/hook.log"
}

log_hook "Stop hook fired. Session: $SESSION_ID | CWD: $SESSION_CWD"

# ---------------------------------------------------------------------------
# Check if the transcript shows credit exhaustion
# ---------------------------------------------------------------------------
CREDIT_DETECTED=0

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
    log_hook "Checking transcript: $TRANSCRIPT_PATH"
    if should_retry "$TRANSCRIPT_PATH" 1; then
        CREDIT_DETECTED=1
        log_hook "Credit exhaustion detected in transcript."
    fi
fi

# ---------------------------------------------------------------------------
# If credits exhausted: spawn background daemon and signal to not block
# ---------------------------------------------------------------------------
if [[ "$CREDIT_DETECTED" -eq 1 ]]; then
    RETRY_INTERVAL="${CLAUDE_AC_INTERVAL:-$DEFAULT_RETRY_INTERVAL}"
    MAX_RETRIES="${CLAUDE_AC_MAX_RETRIES:-$DEFAULT_MAX_RETRIES}"

    # Calculate wait time
    WAIT_SECS="$RETRY_INTERVAL"
    if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
        WAIT_SECS=$(extract_wait_time "$TRANSCRIPT_PATH" "$RETRY_INTERVAL")
    fi

    RESUME_AT=$(date -d "+${WAIT_SECS} seconds" '+%H:%M:%S' 2>/dev/null \
             || date -v+${WAIT_SECS}S '+%H:%M:%S' 2>/dev/null \
             || echo "soon")

    log_hook "Spawning background daemon. Wait: ${WAIT_SECS}s. Resume at: $RESUME_AT"

    notify_send "Claude Auto-Continue" \
        "Usage limit detected. Will resume at $RESUME_AT." \
        "info"

    # Save state for the daemon
    save_session_state "${SESSION_CWD:-$PWD}" 0 "$SESSION_ID"

    # Spawn the daemon in background, detached from this process
    # The daemon will sleep then run `claude --continue` in the correct dir
    (
        sleep "$WAIT_SECS"
        cd "${SESSION_CWD:-$PWD}"
        log_hook "Daemon woke up. Running: claude --continue"
        notify_send "Claude Auto-Continue" "Resuming your session now..." "info"
        # Run with auto-continue enabled again in case of further credit limits
        exec "${CLAUDE_AC_BIN:-claude-ac}" --continue
    ) </dev/null >/dev/null 2>&1 &
    disown

    log_hook "Daemon PID: $! spawned."
fi

# ---------------------------------------------------------------------------
# Always emit a valid JSON response so Claude Code doesn't error
# The hook MUST output valid JSON â we never block the stop, just observe it.
# ---------------------------------------------------------------------------
echo '{"continue": false, "suppressOutput": false}'

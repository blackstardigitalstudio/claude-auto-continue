#!/usr/bin/env bash
# =============================================================================
# lib/detect.sh â Credit exhaustion detection
# =============================================================================
# Parses Claude Code output to determine whether a session ended because of
# API usage limits / credit exhaustion, and extracts the reset time when
# available.
# =============================================================================

# ---------------------------------------------------------------------------
# Patterns that indicate credit / usage-limit exhaustion
# These cover both Claude.ai subscription limits and raw API rate limits.
# ---------------------------------------------------------------------------
readonly CREDIT_PATTERNS=(
    # Claude.ai subscription messages
    "usage limit"
    "Usage limit"
    "usage_limit"
    "You've reached your"
    "you have reached"
    "Claude AI usage"
    "your monthly usage"
    "credits have been"
    "out of credits"
    "no credits"
    "insufficient credits"

    # API rate limit / quota messages
    "rate limit"
    "Rate limit"
    "rate_limit_error"
    "RateLimitError"
    "429"
    "quota exceeded"
    "Quota exceeded"
    "RESOURCE_EXHAUSTED"
    "overloaded"
    "capacity"
    "too many requests"
    "Too Many Requests"

    # Generic retry messages paired with API failures
    "try again later"
    "please try again"
    "Please try again"
    "will reset"
    "resets at"
    "resets in"
)

# Patterns that indicate NORMAL completion (so we don't false-positive)
readonly NORMAL_COMPLETION_PATTERNS=(
    "Task completed"
    "All done"
    "â"
)

# Exit codes that Claude Code uses for usage limit errors
# (empirically observed; may vary across versions)
readonly CREDIT_EXIT_CODES=(1 2 130)

# Safe fallback for log function when detect.sh is sourced standalone
if ! declare -f log &>/dev/null; then
    log() { :; }  # no-op
fi

# ---------------------------------------------------------------------------
# should_retry <log_file> <exit_code>
# Returns 0 (true) if the session should be retried due to credit exhaustion
# ---------------------------------------------------------------------------
should_retry() {
    local log_file="$1"
    local exit_code="${2:-1}"

    # Exit code 0 = success, never retry
    [[ "$exit_code" -eq 0 ]] && return 1

    # Must have a readable log file
    [[ -f "$log_file" ]] || return 1

    # Check output for credit exhaustion patterns
    for pattern in "${CREDIT_PATTERNS[@]}"; do
        if grep -qi "$pattern" "$log_file" 2>/dev/null; then
            log DEBUG "Credit pattern matched: '$pattern'"
            return 0
        fi
    done

    return 1
}

# ---------------------------------------------------------------------------
# extract_wait_time <log_file> <default_secs>
# Tries to parse a reset timestamp from the output.
# Falls back to <default_secs> when no timestamp is found.
# ---------------------------------------------------------------------------
extract_wait_time() {
    local log_file="$1"
    local default_secs="$2"

    # Pattern: "resets at HH:MM" or "will reset at HH:MM"
    local reset_time
    reset_time=$(grep -oiE "reset[s]? at [0-9]{1,2}:[0-9]{2}( [AP]M)?" "$log_file" 2>/dev/null \
               | head -1 \
               | grep -oE "[0-9]{1,2}:[0-9]{2}( [AP]M)?")

    if [[ -n "$reset_time" ]]; then
        local target_epoch now_epoch diff
        target_epoch=$(date -d "$reset_time" +%s 2>/dev/null || date -j -f "%I:%M %p" "$reset_time" +%s 2>/dev/null || echo "")
        now_epoch=$(date +%s)

        if [[ -n "$target_epoch" ]]; then
            diff=$(( target_epoch - now_epoch ))
            # Add 60s buffer so we don't retry the very moment credits reset
            diff=$(( diff + 60 ))
            # If the reset time is in the past (clock/timezone issues), use default
            if [[ $diff -gt 0 && $diff -lt 86400 ]]; then
                echo "$diff"
                return 0
            fi
        fi
    fi

    # Pattern: "resets in Xh Ym" or "available in X minutes"
    local hours minutes
    hours=$(grep -oiE "[0-9]+ hour" "$log_file" 2>/dev/null | grep -oE "[0-9]+" | head -1)
    minutes=$(grep -oiE "[0-9]+ minute" "$log_file" 2>/dev/null | grep -oE "[0-9]+" | head -1)

    if [[ -n "$hours" || -n "$minutes" ]]; then
        local total=$(( (${hours:-0} * 3600) + (${minutes:-0} * 60) + 60 ))
        echo "$total"
        return 0
    fi

    # No timestamp found â use the configured default
    echo "$default_secs"
}

# ---------------------------------------------------------------------------
# get_session_id <log_file>
# Extracts a Claude Code session ID from the output if present.
# ---------------------------------------------------------------------------
get_session_id() {
    local log_file="$1"
    grep -oE "Session [a-f0-9-]{36}" "$log_file" 2>/dev/null | head -1 | awk '{print $2}' || echo ""
}

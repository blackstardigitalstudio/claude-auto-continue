#!/usr/bin/env bash
# =============================================================================
# config/defaults.sh â Default configuration values for claude-ac
# =============================================================================
# Override any of these via environment variables (see bin/claude-ac --help)
# or by creating ~/.config/claude-ac/config.sh
# =============================================================================

readonly CLAUDE_AC_VERSION="1.0.0"

# Seconds to wait between retry attempts.
# Claude.ai Pro resets every ~5 hours; API rate limits clear in minutes.
# Default 300s (5 min) â conservative to avoid hammering the API.
readonly DEFAULT_RETRY_INTERVAL=300

# Maximum number of consecutive retry attempts before giving up.
# 12 retries x 5 min = up to 1 hour of automatic waiting.
readonly DEFAULT_MAX_RETRIES=12

# Log file location
readonly DEFAULT_LOG_FILE="${HOME}/.cache/claude-ac/claude-ac.log"

# Whether to send desktop notifications (1 = yes, 0 = no)
readonly DEFAULT_NOTIFY=1

# Load user overrides if present
USER_CONFIG="${HOME}/.config/claude-ac/config.sh"
if [[ -f "$USER_CONFIG" ]]; then
    source "$USER_CONFIG"
fi

#!/usr/bin/env bash
# =============================================================================
# lib/session.sh — Gestione stato sessione (v1.1: JSON sicuro)
# =============================================================================

CLAUDE_AC_STATE_DIR="${CLAUDE_AC_STATE_DIR:-${HOME}/.cache/claude-ac}"

# ---------------------------------------------------------------------------
# json_escape <string>
# Esegue l'escape di una stringa per inserirla in modo sicuro in un JSON.
# Evita che path con virgolette/backslash/newline rompano il file di stato.
# ---------------------------------------------------------------------------
json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"   # backslash
    s="${s//\"/\\\"}"   # virgolette
    s="${s//$'\n'/\\n}" # newline
    s="${s//$'\r'/\\r}" # carriage return
    s="${s//$'\t'/\\t}" # tab
    printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# save_session_state <cwd> <retry_count> [session_id]
# ---------------------------------------------------------------------------
save_session_state() {
    local cwd retry_count session_id
    cwd="$(json_escape "$1")"
    retry_count="${2:-0}"
    session_id="$(json_escape "${3:-}")"
    # retry_count deve essere numerico: se non lo è, azzera.
    [[ "$retry_count" =~ ^[0-9]+$ ]] || retry_count=0

    mkdir -p "$CLAUDE_AC_STATE_DIR"
    cat > "$CLAUDE_AC_STATE_DIR/state.json" <<JSON
{
  "cwd": "$cwd",
  "retry_count": $retry_count,
  "session_id": "$session_id",
  "start_time": "${_START_TIME:-$(date +%s)}",
  "last_updated": "$(date +%s)"
}
JSON
}

load_session_state() {
    local state_file="$CLAUDE_AC_STATE_DIR/state.json"
    [[ -f "$state_file" ]] && cat "$state_file" || echo '{}'
}

clear_session_state() {
    rm -f "$CLAUDE_AC_STATE_DIR/state.json"
}

get_total_runtime_secs() {
    echo $(( $(date +%s) - ${_START_TIME:-$(date +%s)} ))
}

format_duration() {
    local secs="$1"
    printf "%02dh %02dm %02ds" $(( secs / 3600 )) $(( (secs % 3600) / 60 )) $(( secs % 60 ))
}

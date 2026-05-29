#!/usr/bin/env bash
# =============================================================================
# hooks/stop.sh — Claude Code Stop Hook (v1.1: anti-loop + lock)
# =============================================================================
# Registrato in ~/.claude/settings.json sotto hooks.Stop.
# Scatta a ogni stop di sessione: legge il contesto JSON da stdin, controlla
# il transcript per l'esaurimento crediti e, se rilevato, avvia un daemon in
# background che eseguirà `claude --continue` al reset.
#
# Fix v1.1:
#  - Rispetta stop_hook_active: se l'hook è già attivo, esce subito (no loop).
#  - Lockfile: evita l'accumulo di daemon sovrapposti.
#  - Output JSON sempre valido.
# =============================================================================

set -euo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$HOOK_DIR/../lib" && pwd)"
CONFIG_DIR="$(cd "$HOOK_DIR/../config" && pwd)"

source "$LIB_DIR/detect.sh"
source "$LIB_DIR/notify.sh"
source "$LIB_DIR/session.sh"
source "$CONFIG_DIR/defaults.sh"

CACHE_DIR="${HOME}/.cache/claude-ac"
LOCK_FILE="$CACHE_DIR/daemon.lock"
mkdir -p "$CACHE_DIR"

log_hook() { echo "[HOOK $(date '+%H:%M:%S')] $1" >> "$CACHE_DIR/hook.log"; }

emit_and_exit() { echo '{"continue": false, "suppressOutput": false}'; exit 0; }

# ---------------------------------------------------------------------------
# Leggi il contesto dell'hook da stdin (JSON da Claude Code)
# ---------------------------------------------------------------------------
HOOK_INPUT=""
read -t 2 -r HOOK_INPUT 2>/dev/null || true

parse_json_field() {
    grep -oP "\"$2\":\s*\K\"[^\"]+\"" <<<"$1" 2>/dev/null | tr -d '"' | head -1
}

TRANSCRIPT_PATH=$(parse_json_field "$HOOK_INPUT" "transcript_path")
SESSION_ID=$(parse_json_field "$HOOK_INPUT" "session_id")
SESSION_CWD=$(parse_json_field "$HOOK_INPUT" "cwd")
STOP_HOOK_ACTIVE=$(parse_json_field "$HOOK_INPUT" "stop_hook_active")

# ---------------------------------------------------------------------------
# ANTI-LOOP: se siamo già dentro un ciclo di Stop avviato dall'hook, esci.
# Claude Code fornisce stop_hook_active proprio per questo.
# ---------------------------------------------------------------------------
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
    log_hook "stop_hook_active=true → esco per evitare loop."
    emit_and_exit
fi

log_hook "Stop hook avviato. Session: ${SESSION_ID:-?} | CWD: ${SESSION_CWD:-?}"

# ---------------------------------------------------------------------------
# LOCK: se un daemon è già in attesa (lock fresco), non spawnarne un altro.
# ---------------------------------------------------------------------------
if [[ -f "$LOCK_FILE" ]]; then
    lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
        log_hook "Daemon già attivo (PID $lock_pid) → non ne avvio un altro."
        emit_and_exit
    fi
    rm -f "$LOCK_FILE"  # lock stantio
fi

# ---------------------------------------------------------------------------
# Rileva esaurimento crediti dal transcript
# ---------------------------------------------------------------------------
CREDIT_DETECTED=0
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
    should_retry "$TRANSCRIPT_PATH" 1 && CREDIT_DETECTED=1
fi

if [[ "$CREDIT_DETECTED" -ne 1 ]]; then
    log_hook "Nessun esaurimento crediti rilevato. Stop normale."
    emit_and_exit
fi

# ---------------------------------------------------------------------------
# Crediti esauriti: calcola attesa e avvia il daemon
# ---------------------------------------------------------------------------
RETRY_INTERVAL="${CLAUDE_AC_INTERVAL:-$DEFAULT_RETRY_INTERVAL}"
WAIT_SECS="$RETRY_INTERVAL"
[[ -f "$TRANSCRIPT_PATH" ]] && WAIT_SECS=$(extract_wait_time "$TRANSCRIPT_PATH" "$RETRY_INTERVAL")

RESUME_AT=$(date -d "+${WAIT_SECS} seconds" '+%H:%M:%S' 2>/dev/null \
         || date -v+${WAIT_SECS}S '+%H:%M:%S' 2>/dev/null || echo "presto")

log_hook "Avvio daemon. Attesa: ${WAIT_SECS}s. Ripresa: $RESUME_AT"
notify_send "Claude Auto-Continue" "Limite rilevato. Riprendo alle $RESUME_AT." "info"
save_session_state "${SESSION_CWD:-$PWD}" 0 "${SESSION_ID:-}"

# Daemon in background, scollegato, protetto da lock.
(
    echo $$ > "$LOCK_FILE"
    trap 'rm -f "$LOCK_FILE"' EXIT
    sleep "$WAIT_SECS"
    cd "${SESSION_CWD:-$PWD}" || exit 1
    log_hook "Daemon attivo. Eseguo: claude --continue"
    notify_send "Claude Auto-Continue" "Riprendo la sessione ora..." "info"
    exec "${CLAUDE_AC_BIN:-claude-ac}" --continue
) </dev/null >/dev/null 2>&1 &
disown
log_hook "Daemon PID $! avviato (lock: $LOCK_FILE)."

emit_and_exit

#!/usr/bin/env bash
# =============================================================================
# lib/detect.sh — Rilevamento esaurimento crediti (versione rafforzata)
# =============================================================================
# Determina se una sessione si è fermata per limiti di utilizzo / crediti.
# v1.1: pattern ristretti a marcatori d'errore reali delle API e ricerca
# limitata alla coda dell'output, per ridurre i falsi positivi causati da
# contenuti esterni (pagine web, output di tool) letti durante la sessione.
# =============================================================================

# Numero di righe finali da ispezionare: gli errori di limite compaiono in
# fondo all'output, non nel mezzo della conversazione.
readonly DETECT_TAIL_LINES="${CLAUDE_AC_DETECT_TAIL:-60}"

# Pattern FORTI e specifici: tipi d'errore delle API Anthropic e messaggi di
# limite inequivocabili. Niente più parole generiche tipo "capacity" o "429"
# da sole, che facevano scattare falsi positivi.
readonly CREDIT_PATTERNS=(
    "rate_limit_error"
    "RateLimitError"
    "overloaded_error"
    "RESOURCE_EXHAUSTED"
    "insufficient_quota"
    "insufficient credits"
    "out of credits"
    "usage limit reached"
    "reached your usage limit"
    "reached your daily"
    "monthly usage limit"
    "429 Too Many Requests"
    "HTTP 429"
    "status code 429"
    "Error code: 429"
    "quota exceeded"
)

# Safe fallback per la funzione log se sourcato da solo
if ! declare -f log &>/dev/null; then
    log() { :; }
fi

# ---------------------------------------------------------------------------
# should_retry <log_file> <exit_code>
# Ritorna 0 (vero) se la sessione va ripresa per esaurimento crediti.
# ---------------------------------------------------------------------------
should_retry() {
    local log_file="$1"
    local exit_code="${2:-1}"

    # Uscita 0 = successo: non riprovare mai.
    [[ "$exit_code" -eq 0 ]] && return 1
    [[ -f "$log_file" ]] || return 1

    # Cerca SOLO nelle ultime righe (zona d'errore), non in tutto il transcript.
    local tail_buf
    tail_buf="$(tail -n "$DETECT_TAIL_LINES" "$log_file" 2>/dev/null)" || return 1

    local pattern
    for pattern in "${CREDIT_PATTERNS[@]}"; do
        if grep -qiF -- "$pattern" <<<"$tail_buf"; then
            log DEBUG "Pattern crediti rilevato: '$pattern'"
            return 0
        fi
    done

    return 1
}

# ---------------------------------------------------------------------------
# extract_wait_time <log_file> <default_secs>
# Prova a leggere l'orario di reset dall'output. Ripiega su <default_secs>.
# ---------------------------------------------------------------------------
extract_wait_time() {
    local log_file="$1"
    local default_secs="$2"
    local tail_buf
    tail_buf="$(tail -n "$DETECT_TAIL_LINES" "$log_file" 2>/dev/null)"

    # Pattern: "resets at HH:MM" / "will reset at HH:MM"
    local reset_time
    reset_time=$(grep -oiE "reset[s]? at [0-9]{1,2}:[0-9]{2}( ?[AP]M)?" <<<"$tail_buf" \
               | head -1 | grep -oiE "[0-9]{1,2}:[0-9]{2}( ?[AP]M)?")

    if [[ -n "$reset_time" ]]; then
        local target_epoch now_epoch diff
        target_epoch=$(date -d "$reset_time" +%s 2>/dev/null \
                     || date -j -f "%I:%M %p" "$reset_time" +%s 2>/dev/null || echo "")
        now_epoch=$(date +%s)
        if [[ -n "$target_epoch" ]]; then
            diff=$(( target_epoch - now_epoch + 60 ))  # +60s di margine
            if [[ $diff -gt 0 && $diff -lt 86400 ]]; then
                echo "$diff"; return 0
            fi
        fi
    fi

    # Pattern: "resets in Xh Ym" / "available in X minutes"
    local hours minutes
    hours=$(grep -oiE "[0-9]+ ?hour" <<<"$tail_buf" | grep -oE "[0-9]+" | head -1)
    minutes=$(grep -oiE "[0-9]+ ?minute" <<<"$tail_buf" | grep -oE "[0-9]+" | head -1)
    if [[ -n "$hours" || -n "$minutes" ]]; then
        echo $(( (${hours:-0} * 3600) + (${minutes:-0} * 60) + 60 )); return 0
    fi

    echo "$default_secs"
}

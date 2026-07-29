#!/usr/bin/env bash
# =============================================================================
# config/defaults.sh — Valori di default per claude-ac
# =============================================================================
# Sovrascrivibili via variabili d'ambiente (vedi `claude-ac --ac-help`) o
# creando ~/.config/claude-ac/config.sh
# =============================================================================

# Include-guard: evita doppio source nello stesso processo.
[[ -n "${_CLAUDE_AC_DEFAULTS_LOADED:-}" ]] && return 0
_CLAUDE_AC_DEFAULTS_LOADED=1

# NB: NON usare `readonly` qui. Renderebbe impossibile sovrascrivere questi
# valori dal config utente sottostante (causando un errore fatale) e romperebbe
# i test che fanno il source del file.
CLAUDE_AC_VERSION="1.7.4"

# Secondi tra un tentativo e l'altro.
# Claude.ai Pro si resetta ~ogni 5 ore; i rate limit API si liberano in minuti.
# Default 300s (5 min): conservativo, per non martellare le API.
DEFAULT_RETRY_INTERVAL=300

# Numero massimo di tentativi consecutivi prima di arrendersi.
# 12 tentativi x 5 min = fino a 1 ora di attesa automatica.
DEFAULT_MAX_RETRIES=12

DEFAULT_LOG_FILE="${HOME}/.cache/claude-ac/claude-ac.log"
DEFAULT_NOTIFY=1

# Override utente, se presente.
USER_CONFIG="${HOME}/.config/claude-ac/config.sh"
if [[ -f "$USER_CONFIG" ]]; then
    # shellcheck source=/dev/null
    source "$USER_CONFIG"
fi

# IMPORTANTE: l'ultimo comando del file DEVE avere exit-code 0, altrimenti
# qualunque script che fa `source` di questo file sotto `set -e` morirebbe.
:

#!/usr/bin/env bash
# =============================================================================
# config/defaults.sh — Valori di default per claude-ac
# =============================================================================
# Sovrascrivibili via variabili d'ambiente (vedi `claude-ac --ac-help`) o
# creando ~/.config/claude-ac/config.sh
# =============================================================================

readonly CLAUDE_AC_VERSION="1.1.0"

# Secondi tra un tentativo e l'altro.
# Claude.ai Pro si resetta ~ogni 5 ore; i rate limit API si liberano in minuti.
# Default 300s (5 min): conservativo, per non martellare le API.
readonly DEFAULT_RETRY_INTERVAL=300

# Numero massimo di tentativi consecutivi prima di arrendersi.
# 12 tentativi x 5 min = fino a 1 ora di attesa automatica.
readonly DEFAULT_MAX_RETRIES=12

readonly DEFAULT_LOG_FILE="${HOME}/.cache/claude-ac/claude-ac.log"
readonly DEFAULT_NOTIFY=1

# Override utente, se presenti.
USER_CONFIG="${HOME}/.config/claude-ac/config.sh"
[[ -f "$USER_CONFIG" ]] && source "$USER_CONFIG"

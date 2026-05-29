#!/usr/bin/env bash
# =============================================================================
# lib/notify.sh — Notifiche desktop (v1.1: input sanificato)
# =============================================================================
# macOS (osascript), Linux (notify-send), Windows WSL (powershell toast).
# Tutti i testi vengono ripuliti da caratteri che potrebbero rompere o
# iniettare comandi nei backend (difesa preventiva).
# =============================================================================

# Rimuove virgolette, backslash, backtick, $ e newline dai testi notifica.
_notify_sanitize() {
    local s="$1"
    s="${s//\\/}"; s="${s//\"/}"; s="${s//\'/}"
    s="${s//\`/}"; s="${s//\$/}"
    s="${s//$'\n'/ }"; s="${s//$'\r'/ }"
    printf '%s' "$s"
}

# notify_send <title> <message> [urgency: info|warning|critical]
notify_send() {
    [[ "${NOTIFY:-1}" == "0" ]] && return 0

    local title message urgency
    title="$(_notify_sanitize "$1")"
    message="$(_notify_sanitize "$2")"
    urgency="${3:-info}"

    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
        return 0
    fi

    if command -v notify-send &>/dev/null; then
        local urgency_flag
        case "$urgency" in
            warning)  urgency_flag="normal" ;;
            critical) urgency_flag="critical" ;;
            *)        urgency_flag="low" ;;
        esac
        notify-send -u "$urgency_flag" -t 8000 -- "$title" "$message" 2>/dev/null || true
        return 0
    fi

    if command -v powershell.exe &>/dev/null; then
        powershell.exe -NoProfile -Command "
            Add-Type -AssemblyName System.Windows.Forms
            \$n = New-Object System.Windows.Forms.NotifyIcon
            \$n.Icon = [System.Drawing.SystemIcons]::Information
            \$n.Visible = \$true
            \$n.ShowBalloonTip(8000, '$title', '$message', [System.Windows.Forms.ToolTipIcon]::Info)
            Start-Sleep 9; \$n.Dispose()
        " 2>/dev/null &
        return 0
    fi

    printf '\a' 2>/dev/null || true
}

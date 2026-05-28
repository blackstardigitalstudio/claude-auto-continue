#!/usr/bin/env bash
# =============================================================================
# lib/notify.sh â Desktop notification abstraction
# =============================================================================
# Sends desktop notifications on macOS (osascript), Linux (notify-send),
# and Windows WSL (powershell toast). Falls back silently if unavailable.
# =============================================================================

# notify_send <title> <message> [urgency: info|warning|critical]
notify_send() {
    [[ "${NOTIFY:-1}" == "0" ]] && return 0

    local title="$1"
    local message="$2"
    local urgency="${3:-info}"

    # ââ macOS ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
    if command -v osascript &>/dev/null; then
        osascript -e "display notification \"$message\" with title \"$title\"" 2>/dev/null || true
        return 0
    fi

    # ââ Linux / notify-send ââââââââââââââââââââââââââââââââââââââââââââââââââ
    if command -v notify-send &>/dev/null; then
        local urgency_flag
        case "$urgency" in
            warning)  urgency_flag="normal" ;;
            critical) urgency_flag="critical" ;;
            *)        urgency_flag="low" ;;
        esac
        notify-send -u "$urgency_flag" -t 8000 "$title" "$message" 2>/dev/null || true
        return 0
    fi

    # ââ Windows WSL âââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
    if command -v powershell.exe &>/dev/null; then
        powershell.exe -Command "
            Add-Type -AssemblyName System.Windows.Forms
            \$n = New-Object System.Windows.Forms.NotifyIcon
            \$n.Icon = [System.Drawing.SystemIcons]::Information
            \$n.Visible = \$true
            \$n.ShowBalloonTip(8000, '$title', '$message', [System.Windows.Forms.ToolTipIcon]::Info)
            Start-Sleep 9
            \$n.Dispose()
        " 2>/dev/null &
        return 0
    fi

    # ââ Terminal bell (last resort) ââââââââââââââââââââââââââââââââââââââââââ
    printf '\a' 2>/dev/null || true
}

#!/usr/bin/env bash
# =============================================================================
# install.sh - Installer for claude-ac (Auto-Continue for Claude Code)
# =============================================================================
# Installs claude-ac (user-local or system-wide) and registers the Stop hook
# in ~/.claude/settings.json.
#
# Usage:
#   ./install.sh              install to ~/.local/bin (user-local)
#   ./install.sh --system     install to /usr/local/bin (needs sudo)
#   ./install.sh --uninstall  remove everything
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.7.2"

# ANSI colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}  >${RESET} $*"; }
success() { echo -e "${GREEN}  +${RESET} $*"; }
warn()    { echo -e "${YELLOW}  !${RESET} $*"; }
error()   { echo -e "${RED}  x${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}$*${RESET}"; }

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
print_banner() {
    echo -e "${BOLD}${CYAN}"
    cat <<'BANNER'
  +---------------------------------------------------------+
  |        claude-ac - Auto-Continue for Claude Code        |
  |                                                         |
  |   Never lose progress to credit limits again.          |
  |   Your sessions resume automatically.                  |
  |                                                         |
  |   Made in Italy - Crafted for Claude Code              |
  +---------------------------------------------------------+
BANNER
    echo -e "${RESET}"
}

# ---------------------------------------------------------------------------
# Detect install prefix
# ---------------------------------------------------------------------------
SYSTEM_INSTALL=0
UNINSTALL=0

for arg in "$@"; do
    case "$arg" in
        --system)    SYSTEM_INSTALL=1 ;;
        --uninstall) UNINSTALL=1 ;;
        --help|-h)
            echo "Usage: ./install.sh [--system] [--uninstall]"
            exit 0 ;;
    esac
done

if [[ "$SYSTEM_INSTALL" -eq 1 ]]; then
    INSTALL_PREFIX="/usr/local"
    LIB_PREFIX="/usr/local/lib/claude-ac"
else
    INSTALL_PREFIX="${HOME}/.local"
    LIB_PREFIX="${HOME}/.local/lib/claude-ac"
fi

BIN_DIR="${INSTALL_PREFIX}/bin"
HOOK_PATH="${LIB_PREFIX}/hooks/stop.sh"
SETTINGS_FILE="${HOME}/.claude/settings.json"

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
uninstall() {
    header "Uninstalling claude-ac..."

    [[ -f "$BIN_DIR/claude-ac" ]] && rm -f "$BIN_DIR/claude-ac" && success "Removed $BIN_DIR/claude-ac"
    [[ -d "$LIB_PREFIX" ]] && rm -rf "$LIB_PREFIX" && success "Removed $LIB_PREFIX"
    [[ -d "${HOME}/.cache/claude-ac" ]] && rm -rf "${HOME}/.cache/claude-ac" && success "Removed cache"

    if [[ -f "$SETTINGS_FILE" ]] && grep -q "claude-ac" "$SETTINGS_FILE" 2>/dev/null; then
        if command -v python3 &>/dev/null; then
            python3 - "$SETTINGS_FILE" <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    sys.exit(0)
hooks = data.get("hooks", {})
stop = hooks.get("Stop", [])
new_stop = []
for group in stop:
    inner = [h for h in group.get("hooks", []) if "claude-ac" not in str(h.get("command", ""))]
    if inner:
        group["hooks"] = inner
        new_stop.append(group)
if new_stop:
    hooks["Stop"] = new_stop
else:
    hooks.pop("Stop", None)
if hooks:
    data["hooks"] = hooks
else:
    data.pop("hooks", None)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
            success "Removed Stop hook from $SETTINGS_FILE"
        else
            warn "Please manually remove the 'claude-ac' Stop hook from $SETTINGS_FILE"
        fi
    fi

    success "claude-ac uninstalled."
}

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
check_deps() {
    header "Checking dependencies..."

    local missing=()
    for cmd in bash grep sed; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done

    if ! command -v claude &>/dev/null; then
        error "Claude Code ('claude') not found in PATH."
        error "Install it from: https://claude.ai/code"
        exit 1
    fi

    local claude_version
    claude_version=$(claude --version 2>/dev/null | head -1 || echo "unknown")
    success "Found Claude Code: $claude_version"

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        exit 1
    fi

    if ! command -v python3 &>/dev/null; then
        warn "python3 not found: the installer cannot auto-merge settings.json."
        warn "It will print manual instructions instead."
    fi

    success "All required dependencies satisfied."
}

# ---------------------------------------------------------------------------
# Install files
# ---------------------------------------------------------------------------
install_files() {
    header "Installing claude-ac v${VERSION}..."

    mkdir -p "$BIN_DIR" "$LIB_PREFIX"/{lib,config,hooks}

    cp "$SCRIPT_DIR/bin/claude-ac"      "$BIN_DIR/claude-ac"
    cp "$SCRIPT_DIR/lib/detect.sh"      "$LIB_PREFIX/lib/detect.sh"
    cp "$SCRIPT_DIR/lib/notify.sh"      "$LIB_PREFIX/lib/notify.sh"
    cp "$SCRIPT_DIR/lib/session.sh"     "$LIB_PREFIX/lib/session.sh"
    cp "$SCRIPT_DIR/config/defaults.sh" "$LIB_PREFIX/config/defaults.sh"
    cp "$SCRIPT_DIR/hooks/stop.sh"      "$LIB_PREFIX/hooks/stop.sh"

    chmod +x "$BIN_DIR/claude-ac" "$LIB_PREFIX/hooks/stop.sh"

    # Point the installed wrapper at the installed lib/config location.
    sed -i.bak "s|\$SCRIPT_DIR/../lib|${LIB_PREFIX}/lib|g; s|\$SCRIPT_DIR/../config|${LIB_PREFIX}/config|g" \
        "$BIN_DIR/claude-ac" 2>/dev/null || true
    rm -f "$BIN_DIR/claude-ac.bak" 2>/dev/null || true

    success "Files installed to $INSTALL_PREFIX"
}

# ---------------------------------------------------------------------------
# Register the Stop hook in ~/.claude/settings.json
# ---------------------------------------------------------------------------
register_hook() {
    header "Registering Claude Code Stop hook..."

    mkdir -p "$(dirname "$SETTINGS_FILE")"

    if [[ -f "$SETTINGS_FILE" ]] && grep -q "claude-ac" "$SETTINGS_FILE" 2>/dev/null; then
        warn "Hook already registered in $SETTINGS_FILE. Skipping."
        return 0
    fi

    if command -v python3 &>/dev/null; then
        [[ -f "$SETTINGS_FILE" ]] && cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak" \
            && success "Backed up existing settings to ${SETTINGS_FILE}.bak"

        python3 - "$SETTINGS_FILE" "$HOOK_PATH" <<'PYEOF'
import json, os, sys
path, hook_cmd = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f:
            data = json.load(f)
    except Exception:
        data = {}
hooks = data.setdefault("hooks", {})
stop = hooks.setdefault("Stop", [])
entry = {"type": "command", "command": hook_cmd}
# Reuse a matcher:"" group if present, otherwise create one.
group = next((g for g in stop if g.get("matcher", "") == ""), None)
if group is None:
    group = {"matcher": "", "hooks": []}
    stop.append(group)
group.setdefault("hooks", []).append(entry)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
        success "Stop hook registered in $SETTINGS_FILE"
        return 0
    fi

    # Fallback: no python3 -> print manual instructions.
    warn "python3 not available: add this to 'hooks.Stop' in $SETTINGS_FILE manually:"
    cat <<EOF

  {
    "hooks": {
      "Stop": [
        {
          "matcher": "",
          "hooks": [
            { "type": "command", "command": "$HOOK_PATH" }
          ]
        }
      ]
    }
  }
EOF
}

# ---------------------------------------------------------------------------
# PATH check
# ---------------------------------------------------------------------------
check_path() {
    if ! echo "$PATH" | grep -q "$BIN_DIR"; then
        warn "$BIN_DIR is not in your PATH."
        echo ""
        echo "  Add this to your shell config (~/.bashrc, ~/.zshrc, etc.):"
        echo "    export PATH=\"\$PATH:$BIN_DIR\""
        echo ""
    else
        success "$BIN_DIR is in PATH."
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
print_banner

if [[ "$UNINSTALL" -eq 1 ]]; then
    uninstall
    exit 0
fi

check_deps
install_files
register_hook
check_path

header "Installation complete! Made in Italy"
echo ""
echo -e "  ${BOLD}Quick start:${RESET}"
echo "    claude-ac \"build me a todo app\""
echo "    claude-ac --continue   # resume last session"
echo "    claude-ac --ac-help"
echo ""
echo "  When Claude Code hits a usage limit, claude-ac will"
echo "  automatically resume your session. No babysitting required."
echo ""
echo -e "  ${CYAN}Made in Italy - https://github.com/blackstardigitalstudio/claude-auto-continue${RESET}"
echo ""

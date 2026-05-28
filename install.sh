#!/usr/bin/env bash
# =============================================================================
# install.sh â Installer for claude-ac (Auto-Continue for Claude Code)
# =============================================================================
# Installs claude-ac system-wide (or user-local) and optionally registers
# the Stop hook in ~/.claude/settings.json.
#
# Usage:
#   ./install.sh              â install to ~/.local/bin (user-local)
#   ./install.sh --system     â install to /usr/local/bin (needs sudo)
#   ./install.sh --uninstall  â remove everything
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="1.0.0"

# ANSI colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}  â¸${RESET} $*"; }
success() { echo -e "${GREEN}  â${RESET} $*"; }
warn()    { echo -e "${YELLOW}  â ${RESET} $*"; }
error()   { echo -e "${RED}  â${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}$*${RESET}"; }

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
print_banner() {
    echo -e "${BOLD}"
    cat <<'BANNER'
  âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
  â         claude-ac â Auto-Continue for Claude Code        â
  â                                                           â
  â   Never lose progress to credit limits again.             â
  â   Your sessions resume automatically. ð®ð¹                 â
  â                                                           â
  â   Made in Italy Â· Crafted for Claude Code                 â
  âââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
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
    HOOK_PREFIX="/usr/local/lib/claude-ac/hooks"
else
    INSTALL_PREFIX="${HOME}/.local"
    LIB_PREFIX="${HOME}/.local/lib/claude-ac"
    HOOK_PREFIX="${HOME}/.local/lib/claude-ac/hooks"
fi

BIN_DIR="${INSTALL_PREFIX}/bin"
SETTINGS_FILE="${HOME}/.claude/settings.json"

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
uninstall() {
    header "Uninstalling claude-ac..."

    [[ -f "$BIN_DIR/claude-ac" ]] && rm -f "$BIN_DIR/claude-ac" && success "Removed $BIN_DIR/claude-ac"
    [[ -d "$LIB_PREFIX" ]] && rm -rf "$LIB_PREFIX" && success "Removed $LIB_PREFIX"
    [[ -d "${HOME}/.cache/claude-ac" ]] && rm -rf "${HOME}/.cache/claude-ac" && success "Removed cache"

    # Remove hook from settings.json if present
    if [[ -f "$SETTINGS_FILE" ]]; then
        warn "Please manually remove the 'Stop' hook entry from $SETTINGS_FILE"
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
    claude_version=$(claude --version 2>/dev/null | head -1)
    success "Found: $claude_version"

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        exit 1
    fi

    success "All dependencies satisfied."
}

# ---------------------------------------------------------------------------
# Install files
# ---------------------------------------------------------------------------
install_files() {
    header "Installing claude-ac v${VERSION}..."

    mkdir -p "$BIN_DIR" "$LIB_PREFIX"/{lib,config,hooks}

    # Copy core files
    cp "$SCRIPT_DIR/bin/claude-ac"     "$BIN_DIR/claude-ac"
    cp "$SCRIPT_DIR/lib/detect.sh"     "$LIB_PREFIX/lib/detect.sh"
    cp "$SCRIPT_DIR/lib/notify.sh"     "$LIB_PREFIX/lib/notify.sh"
    cp "$SCRIPT_DIR/lib/session.sh"    "$LIB_PREFIX/lib/session.sh"
    cp "$SCRIPT_DIR/config/defaults.sh" "$LIB_PREFIX/config/defaults.sh"
    cp "$SCRIPT_DIR/hooks/stop.sh"     "$LIB_PREFIX/hooks/stop.sh"

    # Make scripts executable
    chmod +x "$BIN_DIR/claude-ac" "$LIB_PREFIX/hooks/stop.sh"

    # Update lib paths in the wrapper to point to the installed location
    sed -i "s|SCRIPT_DIR/../lib|${LIB_PREFIX}/lib|g; s|SCRIPT_DIR/../config|${LIB_PREFIX}/config|g" \
        "$BIN_DIR/claude-ac" 2>/dev/null || true

    success "Files installed to $INSTALL_PREFIX"
}

# ---------------------------------------------------------------------------
# Register the Stop hook in ~/.claude/settings.json
# ---------------------------------------------------------------------------
register_hook() {
    header "Registering Claude Code Stop hook..."

    mkdir -p "$(dirname "$SETTINGS_FILE")"

    local hook_cmd="$LIB_PREFIX/hooks/stop.sh"
    local hook_entry
    hook_entry=$(cat <<EOF
{
  "type": "command",
  "command": "$hook_cmd"
}
EOF
)

    if [[ ! -f "$SETTINGS_FILE" ]]; then
        # Create a fresh settings file
        cat > "$SETTINGS_FILE" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [$hook_entry]
      }
    ]
  }
}
EOF
        success "Created $SETTINGS_FILE with Stop hook."
        return 0
    fi

    # Settings file exists â check if hook already registered
    if grep -q "claude-ac" "$SETTINGS_FILE" 2>/dev/null; then
        warn "Hook already registered in $SETTINGS_FILE. Skipping."
        return 0
    fi

    # Backup existing settings
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
    success "Backed up existing settings to ${SETTINGS_FILE}.bak"

    warn "Automatic merge of existing settings.json is not supported."
    echo ""
    echo "  Please add this to the 'hooks.Stop' array in $SETTINGS_FILE:"
    echo ""
    echo "  $hook_entry"
    echo ""
    echo "  Full example:"
    cat <<EOF
  {
    "hooks": {
      "Stop": [
        {
          "matcher": "",
          "hooks": [$hook_entry]
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

header "Installation complete! ð®ð¹"
echo ""
echo -e "  ${BOLD}Quick start:${RESET}"
echo "    claude-ac \"build me a todo app\""
echo "    claude-ac --continue   # resume last session"
echo "    claude-ac --help"
echo ""
echo "  When Claude Code hits a usage limit, claude-ac will"
echo "  automatically resume your session. No babysitting required."
echo ""
echo "  ${CYAN}Made with â¤ï¸  in Italy â https://github.com/YOUR_USERNAME/claude-auto-continue${RESET}"
echo ""

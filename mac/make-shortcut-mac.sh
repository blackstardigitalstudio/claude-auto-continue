#!/bin/bash
# =============================================================================
# make-shortcut-mac.sh  --  Crea i "tasti" sul Desktop (macOS)
# =============================================================================
# Installa gli script in ~/.local/share/claude-ac e crea sul Desktop due file
# cliccabili (.command):
#   - "Continua il lavoro - Claude" -> riprende le sessioni bloccate
#   - "Scegli sessioni - Claude"    -> check-up con lista da cui scegliere
#
# Uso:
#   bash make-shortcut-mac.sh
#   bash make-shortcut-mac.sh --uninstall
#
# Made in Italy.
# =============================================================================
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/share/claude-ac"
DESKTOP="$HOME/Desktop"

NOW_CMD="$DESKTOP/Continua il lavoro - Claude.command"
PICK_CMD="$DESKTOP/Scegli sessioni - Claude.command"

if [[ "${1:-}" == "--uninstall" ]]; then
    rm -f "$NOW_CMD" "$PICK_CMD" && echo "Tasti rimossi dal Desktop." || true
    exit 0
fi

mkdir -p "$INSTALL_DIR"
cp "$SRC_DIR/resume-now.sh"    "$INSTALL_DIR/resume-now.sh"
cp "$SRC_DIR/resume-picker.sh" "$INSTALL_DIR/resume-picker.sh"
chmod +x "$INSTALL_DIR/resume-now.sh" "$INSTALL_DIR/resume-picker.sh"

cat > "$NOW_CMD" <<EOF
#!/bin/bash
# Tasto "Continua il lavoro" per l'app Claude. Made in Italy.
"$INSTALL_DIR/resume-now.sh"
EOF
chmod +x "$NOW_CMD"

cat > "$PICK_CMD" <<EOF
#!/bin/bash
# Check-up "Scegli sessioni" per l'app Claude. Made in Italy.
"$INSTALL_DIR/resume-picker.sh"
EOF
chmod +x "$PICK_CMD"

echo "Fatto! Sul Desktop trovi due tasti:"
echo "  - $NOW_CMD"
echo "  - $PICK_CMD"
echo ""
echo "IMPORTANTE (la prima volta): concedi l'accesso Accessibilita' al Terminale in"
echo "Impostazioni di Sistema > Privacy e Sicurezza > Accessibilita'."

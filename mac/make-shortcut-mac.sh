#!/bin/bash
# =============================================================================
# make-shortcut-mac.sh  --  Crea il "tasto" Continua il lavoro sul Desktop (macOS)
# =============================================================================
# Installa resume-now.sh in ~/.local/share/claude-ac e crea sul Desktop un file
# cliccabile "Continua il lavoro - Claude.command" che lo esegue.
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
TARGET="$INSTALL_DIR/resume-now.sh"
DESKTOP="$HOME/Desktop"
CMD="$DESKTOP/Continua il lavoro - Claude.command"

if [[ "${1:-}" == "--uninstall" ]]; then
    rm -f "$CMD" && echo "Tasto rimosso dal Desktop." || true
    exit 0
fi

mkdir -p "$INSTALL_DIR"
cp "$SRC_DIR/resume-now.sh" "$TARGET"
chmod +x "$TARGET"

cat > "$CMD" <<EOF
#!/bin/bash
# Tasto "Continua il lavoro" per l'app Claude. Made in Italy.
"$TARGET"
EOF
chmod +x "$CMD"

echo "Fatto! Tasto creato sul Desktop:"
echo "  $CMD"
echo ""
echo "Quando i crediti tornano, fai doppio clic sul tasto e Claude riprende."
echo ""
echo "IMPORTANTE (solo la prima volta): concedi l'accesso Accessibilita' a"
echo "Terminale in: Impostazioni di Sistema > Privacy e Sicurezza > Accessibilita'."

#!/bin/bash
# install.sh — Install Claude 2× Tracker widget for KDE Plasma

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/package"
PLUGIN_ID="com.claude2x.tracker"

echo "╔══════════════════════════════════════════╗"
echo "║   Claude 2× Tracker — KDE Plasma Widget ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Detect which package tool is available
if command -v kpackagetool6 &>/dev/null; then
    TOOL="kpackagetool6"
    echo "→ Detected Plasma 6 (kpackagetool6)"
elif command -v kpackagetool5 &>/dev/null; then
    TOOL="kpackagetool5"
    echo "→ Detected Plasma 5 (kpackagetool5)"
elif command -v plasmapkg2 &>/dev/null; then
    TOOL="plasmapkg2"
    echo "→ Detected Plasma 5 (plasmapkg2)"
else
    echo "✗ Error: No Plasma package tool found."
    echo "  Install kpackagetool6 (Plasma 6) or plasmapkg2 (Plasma 5)."
    exit 1
fi

echo ""

# Try to remove existing installation first (ignore errors)
echo "→ Removing previous installation (if any)..."
$TOOL --type Plasma/Applet --remove "$PLUGIN_ID" 2>/dev/null || true

# Install the widget
echo "→ Installing widget from $PACKAGE_DIR ..."
$TOOL --type Plasma/Applet --install "$PACKAGE_DIR"

echo ""
echo "Done! The widget is now installed."
echo ""
echo "To add it to your desktop or panel:"
echo "  1. Right-click your desktop → 'Add Widgets...'"
echo "  2. Search for 'Claude 2x Tracker'"
echo "  3. Drag it to your desktop or panel"
echo ""
echo "To uninstall:"
echo "  $TOOL --type Plasma/Applet --remove $PLUGIN_ID"
echo ""

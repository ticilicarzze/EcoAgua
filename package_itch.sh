#!/usr/bin/env bash
set -e

# =========================================================
# Script de Exportación y Empaquetado para itch.io
# EcoAguaUNR
# =========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GODOT_BIN="/home/ticiano/Software/Godot_v4.6.2-stable_linux.x86_64"
EXPORT_DIR="$PROJECT_ROOT/web_export"
ZIP_OUTPUT="$PROJECT_ROOT/web_export.zip"

echo "🚀 1/3 Exportando versión Web con Godot..."
"$GODOT_BIN" --headless --path "$SCRIPT_DIR" --export-release "Web" "$EXPORT_DIR/index.html"

echo "💉 2/3 Inyectando polyfills si aplica..."
if [ -f "$PROJECT_ROOT/inject_polyfill.sh" ]; then
    (cd "$PROJECT_ROOT" && bash inject_polyfill.sh)
fi

echo "📦 3/3 Generando archivo zip para itch.io ($ZIP_OUTPUT)..."
(cd "$EXPORT_DIR" && zip -j -r "$ZIP_OUTPUT" index.html index.js index.wasm index.pck *.png *.js)

echo ""
echo "✅ ¡Listo! Archivo generado exitosamente en:"
echo "   $ZIP_OUTPUT"
echo ""
echo "👉 Ahora puedes subir este archivo directamente a tu panel de itch.io."

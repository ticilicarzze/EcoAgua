#!/usr/bin/env bash
set -e

# =========================================================
# Script de Exportación y Despliegue Automático a Netlify
# EcoAguaUNR
# =========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT_BIN="/home/ticiano/Software/Godot_v4.6.2-stable_linux.x86_64"
EXPORT_DIR="$SCRIPT_DIR/../web_export"

echo "🚀 1/3 Compilando exportación WebGL con Godot..."
"$GODOT_BIN" --headless --path "$SCRIPT_DIR" --export-release "Web" "$EXPORT_DIR/index.html"

echo "📄 2/3 Asegurando archivo _headers para Cross-Origin Isolation..."
cat << 'EOF' > "$EXPORT_DIR/_headers"
/*
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
EOF

echo "🌐 3/3 Subiendo a producción en Netlify..."
cd "$EXPORT_DIR"
netlify deploy --prod --dir=.

echo "✅ ¡Despliegue completado con éxito a https://ecoagua-unr.netlify.app!"

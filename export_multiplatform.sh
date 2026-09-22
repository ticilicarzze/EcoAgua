#!/usr/bin/env bash
# =============================================================
# EcoAgua UNR — Exportación Multi-Plataforma + GitHub
# Plataformas: APK Meta Quest 3 | Linux x86_64 | Windows x86_64
# =============================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
PARENT_DIR="$SCRIPT_DIR/.."
GODOT_BIN="/home/ticiano/Software/Godot_v4.6.2-stable_linux.x86_64"

APK_OUT="$PARENT_DIR/EcoAgua_Quest3HUD.apk"
LINUX_OUT="$PARENT_DIR/EcoAgua_PC_Linux/EcoAgua.x86_64"
WINDOWS_OUT="$PARENT_DIR/EcoAgua_PC_Windows/EcoAgua.exe"

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${YELLOW}🔄 $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; exit 1; }

# ── 1. Commit cambios pendientes ──────────────────────────────
info "1/6 Verificando cambios pendientes en Git..."
cd "$PROJECT_DIR"
if ! git diff --quiet || ! git diff --cached --quiet; then
    FECHA=$(date '+%Y-%m-%d %H:%M')
    git add -A
    git commit -m "chore: auto-commit antes de exportación multi-plataforma ($FECHA)"
    log "Cambios commiteados."
else
    log "Árbol de trabajo limpio, no se necesita commit."
fi

# ── 2. Crear directorios de salida ────────────────────────────
info "2/6 Preparando directorios de exportación..."
mkdir -p "$PARENT_DIR/EcoAgua_PC_Linux"
mkdir -p "$PARENT_DIR/EcoAgua_PC_Windows"
log "Directorios listos."

# ── 3. Exportar APK Meta Quest 3 ──────────────────────────────
info "3/6 Exportando APK para Meta Quest 3..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    --export-release "Android Quest 3" "$APK_OUT" \
    && log "APK exportado → $APK_OUT" \
    || err "Falló la exportación del APK. Verificar Android SDK y templates de Godot."

# ── 4. Exportar Linux x86_64 ─────────────────────────────────
info "4/6 Exportando para Linux x86_64..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    --export-release "Linux/X11" "$LINUX_OUT" \
    && log "Linux exportado → $LINUX_OUT" \
    || err "Falló la exportación de Linux."
chmod +x "$LINUX_OUT"

# ── 5. Exportar Windows x86_64 ───────────────────────────────
info "5/6 Exportando para Windows x86_64..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" \
    --export-release "Windows Desktop" "$WINDOWS_OUT" \
    && log "Windows exportado → $WINDOWS_OUT" \
    || err "Falló la exportación de Windows."

# ── 6. Actualizar README con fecha + push a GitHub ────────────
info "6/6 Actualizando README y subiendo a GitHub..."
FECHA_README=$(date '+%d/%m/%Y %H:%M')
# Actualiza la línea de "Última exportación" en el README si existe, si no la agrega
if grep -q "Última exportación:" "$PROJECT_DIR/README.md"; then
    sed -i "s/Última exportación: .*/Última exportación: $FECHA_README/" "$PROJECT_DIR/README.md"
else
    # Agrega badge de exportación debajo de la primera línea de badges
    sed -i "s|^\(\[!\[License\].*\)$|\1\n[![Last Export](https://img.shields.io/badge/Última_exportación-$(date '+%Y--M--%d')-informational)](https://github.com/ticilicarzze/EcoAgua)|" "$PROJECT_DIR/README.md"
fi

cd "$PROJECT_DIR"
git add README.md export_presets.cfg
git diff --cached --quiet || git commit -m "docs: actualizar README con fecha de exportación $FECHA_README"
git push origin main
log "Push a GitHub completado."

# ── Resumen final ─────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  🎉 EXPORTACIÓN COMPLETADA — EcoAgua UNR${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  📱 APK Meta Quest 3 : $APK_OUT"
echo "  🐧 Linux x86_64     : $LINUX_OUT"
echo "  🪟 Windows x86_64   : $WINDOWS_OUT"
echo ""
echo "  🐙 GitHub           : https://github.com/ticilicarzze/EcoAgua"
echo ""
ls -lh "$APK_OUT" "$LINUX_OUT" "$WINDOWS_OUT" 2>/dev/null || true

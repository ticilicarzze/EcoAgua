---
name: export-multiplatform
description: >-
  Exporta el proyecto EcoAgua UNR para Meta Quest 3 (APK), Linux x86_64 y Windows x86_64,
  actualiza el README con la fecha de exportación y sube todo a GitHub.
  Usar cuando el usuario pida exportar, compilar o generar binarios del juego para Quest, PC, Linux o Windows.
---

# Export Multi-Plataforma — EcoAgua UNR

Esta skill define el procedimiento completo para exportar EcoAgua en todas las plataformas nativas (APK Quest 3, Linux, Windows), actualizar el README y subir los cambios a GitHub.

## Variables del Entorno

| Variable | Valor |
|---|---|
| `GODOT_BIN` | `/home/ticiano/Software/Godot_v4.6.2-stable_linux.x86_64` |
| `PROJECT_DIR` | `/home/ticiano/Proyects/EcoAguaUNR/EcoAgua` |
| `APK_OUT` | `../EcoAgua_Quest3HUD.apk` |
| `LINUX_OUT` | `../EcoAgua_PC_Linux/EcoAgua.x86_64` |
| `WINDOWS_OUT` | `../EcoAgua_PC_Windows/EcoAgua.exe` |
| `GITHUB_REMOTE` | `https://github.com/ticilicarzze/EcoAgua.git` |

## Procedimiento Estándar

**Usar siempre el script automatizado** — no exportar manualmente:

```bash
cd /home/ticiano/Proyects/EcoAguaUNR/EcoAgua
chmod +x export_multiplatform.sh
./export_multiplatform.sh
```

El script realiza los 6 pasos en orden:
1. Auto-commit de cambios pendientes.
2. Export APK Meta Quest 3.
3. Export Linux x86_64 + `chmod +x`.
4. Export Windows x86_64.
5. Actualizar README con fecha.
6. `git push origin main`.

## Paso a Paso Manual (si el script falla)

### 1. Commit de cambios pendientes

```bash
cd /home/ticiano/Proyects/EcoAguaUNR/EcoAgua
git add -A
git commit -m "chore: pre-export commit $(date '+%Y-%m-%d')"
```

### 2. Crear directorios de salida

```bash
mkdir -p /home/ticiano/Proyects/EcoAguaUNR/EcoAgua_PC_Linux
mkdir -p /home/ticiano/Proyects/EcoAguaUNR/EcoAgua_PC_Windows
```

### 3. Exportar APK Meta Quest 3

```bash
/home/ticiano/Software/Godot_v4.6.2-stable_linux.x86_64 \
  --headless \
  --path /home/ticiano/Proyects/EcoAguaUNR/EcoAgua \
  --export-release "Android Quest 3" \
  /home/ticiano/Proyects/EcoAguaUNR/EcoAgua_Quest3HUD.apk
```

**Prerequisitos APK:** Android SDK instalado, Godot Android build template generado.
Si falla por Gradle, verificar `android/` en el proyecto y que el keystore esté configurado.

### 4. Exportar Linux x86_64

```bash
/home/ticiano/Software/Godot_v4.6.2-stable_linux.x86_64 \
  --headless \
  --path /home/ticiano/Proyects/EcoAguaUNR/EcoAgua \
  --export-release "Linux/X11" \
  /home/ticiano/Proyects/EcoAguaUNR/EcoAgua_PC_Linux/EcoAgua.x86_64
chmod +x /home/ticiano/Proyects/EcoAguaUNR/EcoAgua_PC_Linux/EcoAgua.x86_64
```

### 5. Exportar Windows x86_64

```bash
/home/ticiano/Software/Godot_v4.6.2-stable_linux.x86_64 \
  --headless \
  --path /home/ticiano/Proyects/EcoAguaUNR/EcoAgua \
  --export-release "Windows Desktop" \
  /home/ticiano/Proyects/EcoAguaUNR/EcoAgua_PC_Windows/EcoAgua.exe
```

### 6. Verificar tamaños

```bash
ls -lh \
  /home/ticiano/Proyects/EcoAguaUNR/EcoAgua_Quest3HUD.apk \
  /home/ticiano/Proyects/EcoAguaUNR/EcoAgua_PC_Linux/EcoAgua.x86_64 \
  /home/ticiano/Proyects/EcoAguaUNR/EcoAgua_PC_Windows/EcoAgua.exe
```

Cada binario debe ser **> 10 MB** para considerarse válido.

### 7. Push a GitHub

```bash
cd /home/ticiano/Proyects/EcoAguaUNR/EcoAgua
git add README.md export_presets.cfg
git commit -m "docs: actualizar README con fecha de exportación"
git push origin main
```

## Errores Frecuentes

| Error | Causa | Solución |
|---|---|---|
| `No export template found` | Templates de Godot no instalados | Godot → Editor → Manage Export Templates → Download |
| `Android SDK not found` | ANDROID_HOME no configurado | `export ANDROID_HOME=~/Android/Sdk` |
| `Gradle build failed` | Build template Android no generado | Godot → Project → Install Android Build Template |
| `git push rejected` | Push rechazado por divergencia | `git pull --rebase origin main` y volver a pushear |

## Notas de Configuración

- El preset **"Android Quest 3"** tiene `gradle_build/use_gradle_build=true`. Requiere build template generado en `android/`.
- El preset **"Windows Desktop"** exporta a `../EcoAgua_PC_Windows/EcoAgua.exe`.
- El preset **"Linux/X11"** exporta a `../EcoAgua_PC_Linux/EcoAgua.x86_64`.
- Los binarios exportados **NO se versiona en Git** (están en `.gitignore` o son carpetas externas al repo).

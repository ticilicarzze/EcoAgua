---
name: deploy-itch
description: >-
  Exporta, optimiza y empaqueta el proyecto EcoAgua UNR para su despliegue en itch.io.
  Usar cuando el usuario pida subir, actualizar o exportar el juego para itch o itch.io.
---

# Deploy a itch.io — EcoAgua UNR

Esta skill define el procedimiento estandarizado para exportar y empaquetar la versión Web del proyecto para itch.io, garantizando compatibilidad y respetando los límites de tamaño.

## Requisitos Críticos de itch.io

1. **Límite de tamaño:** Ningún archivo descomprimido dentro del ZIP puede superar los **200 MB** (en particular `index.pck`).
2. **Estructura del ZIP:** `index.html` y todos los assets deben estar en la **raíz** del `.zip`, no dentro de una subcarpeta.
3. **Cielo HDRI:** Usar siempre la versión 2K HDR (`grasslands_sunset_2k.hdr`) en `env_op1.tres`, nunca el EXR 4K.
4. **Exclusiones de exportación:** Mantener `exclude_filter` en `export_presets.cfg` para no incluir texturas o modelos no instanciados.

## Procedimiento Paso a Paso

### 1. Verificar estado del proyecto y Git
- Revisar si hay cambios sin commitear en la rama de trabajo (`git status`).
- Si el usuario lo solicita, hacer commit y mergear a `main`.

### 2. Exportar y empaquetar
Ejecutar el script automatizado del proyecto:

```bash
cd /home/ticiano/Proyects/EcoAguaUNR/EcoAgua
./package_itch.sh
```

Este script ejecuta:
- Exportación headless de Godot con el preset "Web".
- Inyección del polyfill WebXR (`inject_polyfill.sh`).
- Compresión de los archivos a `/home/ticiano/Proyects/EcoAguaUNR/web_export.zip`.

### 3. Validar el tamaño del paquete
Verificar que `index.pck` no supere los 200 MB:

```bash
ls -lh /home/ticiano/Proyects/EcoAguaUNR/web_export/index.pck
```

Si `index.pck` supera los 190 MB, revisar `export_presets.cfg` y excluir assets no utilizados.

### 4. Instrucciones de configuración para el usuario en itch.io
Indicar al usuario la ruta del archivo generado (`/home/ticiano/Proyects/EcoAguaUNR/web_export.zip`) y recordar los ajustes clave en la página de itch.io:
- **Kind of project:** `HTML`.
- **Upload:** Subir `web_export.zip` y marcar ☑️ *This file will be played in the browser*.
- **Embed options:**
  - Viewport: `1152 x 648` (o `1280 x 720`).
  - ☑️ *Fullscreen button*.
  - ☑️ *Enable SharedArrayBuffer*.

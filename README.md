# 🌊 EcoAgua UNR - VR & Web River Environment Simulation

[![Godot Engine](https://img.shields.io/badge/Godot_Engine-v4.6_GL_Compatibility-blue?logo=godotengine)](https://godotengine.org/)
[![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20VR%20(Meta%20Quest)-brightgreen)](https://ecoagua-unr.netlify.app)
[![Deployment](https://img.shields.io/badge/Deployment-Live%20on%20Netlify-success?logo=netlify)](https://ecoagua-unr.netlify.app)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)

**EcoAgua UNR** es una simulación interactiva 3D en Realidad Virtual y WebGL desarrollada en **Godot Engine 4** que recrea el ecosistema de la llanura pampeana argentina. El proyecto integra modelado de terreno procedimental, shaders de agua de alta fidelidad e indicadores ecológicos de degradación del agua basados en estudios de laboratorio de la **Universidad Nacional de Rosario (UNR)** y el instituto **ICASFAS**.

🌐 **Demostración en vivo en la Web**: [https://ecoagua-unr.netlify.app](https://ecoagua-unr.netlify.app)

---

## 📋 Tabla de Contenidos

- [Características Principales](#-características-principales)
- [Tecnologías y Shaders](#-tecnologías-y-shaders)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Controles y Navegación](#-controles-y-navegación)
- [Requisitos e Instalación Local](#-requisitos-e-instalación-local)
- [Despliegue a Producción](#-despliegue-a-producción)
- [Contexto Científico](#-contexto-científico)
- [Licencia y Créditos](#-licencia-y-créditos)

---

## 🌟 Características Principales

* 💧 **Shader de Agua de Alta Fidelidad (`watershader2.gdshader`)**:
  - Reflexión Fresnel dinámica combinada con iluminación de cielo **HDRI**.
  - Absorción de profundidad, refracción en pantalla, desplazamiento de cáusticas animadas y espuma procedimental.
* 🌿 **Simulación por Zonas de Degradación Ecológica (`WaterManager.gd`)**:
  - Transición fluida a lo largo de 4 zonas del río: desde aguas cristalinas de cabecera hasta zonas impactadas por carga orgánica, microplásticos y alta turbidez.
* 🎨 **Renderizado y Mapeo de Tonos AgX**:
  - Implementación del tonemapper **AgX** para preservar la fidelidad cromática sin sobreexposición ni saturación indeseada.
* 🥽 **Soporte Multiplataforma Integrado**:
  - **Modo VR**: Integración con **Godot XR Tools** y soporte nativo para visores (Meta Quest / OpenXR).
  - **Modo Web / Desktop**: Cámara interactiva de navegación libre (`FreeLookCamera.gd`).

---

## 🛠️ Tecnologías y Shaders

| Componente | Tecnología / Módulo | Descripción |
| :--- | :--- | :--- |
| **Motor 3D** | Godot Engine 4.6 (GL Compatibility) | Backend liviano optimizado para VR standalone y WebGL |
| **Shader de Agua** | Custom GLSL Shader (`watershader2`) | Normal maps duales, cáusticas triplanares y profundidad |
| **VR Framework** | Godot XR Tools | Manejo de trackers, manos y movimiento en visor |
| **Tonemapping** | AgX + HDRI Environment | Iluminación por imagen y gestión de rango dinámico |
| **Hosting Web** | Netlify + Cross-Origin Isolation | Soporte `SharedArrayBuffer` para WebGL |

---

## 📂 Estructura del Proyecto

```text
EcoAgua/
├── assets/
│   ├── hdris/              # Mapas de iluminación HDRI (4K / 2K)
│   ├── models/             # Geometría y texturas del terreno pampeano
│   └── textures/water/     # Texturas de cáusticas, espuma y mapas de normales
├── resources/
│   ├── environments/       # Recursos de ambiente (WorldEnvironment .tres)
│   └── shaders/            # watershader2.gdshader y shaders ambientales
├── scenes/
│   └── main.tscn           # Escena principal de la simulación
├── scripts/
│   ├── FreeLookCamera.gd   # Control de cámara libre para Web / Desktop
│   ├── main.gd             # Controlador principal del mapa y entorno
│   ├── WaterManager.gd     # Gestor central de métricas y zonas ecológicas
│   └── WaterVisualController.gd # Actualizador de parámetros visuales del agua
├── deploy.sh               # Script de compilación y despliegue automático a Netlify
├── export_presets.cfg      # Configuración de exportación a Web
└── project.godot           # Configuración general del proyecto Godot 4
```

---

## 🎮 Controles y Navegación

### Modo Web / Desktop (Cámara Libre)
* **`W / A / S / D`**: Desplazar la cámara por el escenario.
* **`Shift`**: Aumentar la velocidad de movimiento.
* **`Clic Derecho + Arrastrar`**: Orientar la vista de la cámara en 360°.
* **`Q / E`**: Subir o bajar la altura de la cámara.

### Modo Realidad Virtual (Meta Quest / OpenXR)
* **Head Tracker**: Orientación nativa de la mirada.
* **Joysticks**: Avance y rotación continua a lo largo de la trayectoria del río (`RiverPath`).

---

## 💻 Requisitos e Instalación Local

### Prerrequisitos
* **Godot Engine 4.3+** o **4.6** ([Descargar Godot Engine](https://godotengine.org/))

### Pasos de Configuración
1. Clonar el repositorio:
   ```bash
   git clone https://github.com/ticilicarzze/EcoAgua.git
   ```
2. Abrir Godot Engine y seleccionar la opción **Importar (Import)**.
3. Apuntar a la carpeta `EcoAgua/EcoAgua/project.godot`.
4. Ejecutar la escena principal presionando **`F5`** o desde `scenes/main.tscn`.

---

## 🚀 Despliegue a Producción

El proyecto cuenta con automatización completa para la exportación y despliegue directo a Netlify:

```bash
cd EcoAgua/EcoAgua
./deploy.sh
```

El script ejecuta de forma transparente:
1. Compilación WebGL sin interfaz (`--headless`).
2. Generación automática del archivo `_headers` para `Cross-Origin-Opener-Policy`.
3. Despliegue inmediato a la red de producción de Netlify.

---

## 🔬 Contexto Científico

La simulación calibra visualmente el estado del agua a lo largo de las 4 zonas del recorrido basándose en parámetros fisicoquímicos reales:
* **Zona 1 (Cabecera)**: Agua transparente, alta penetración de luz, bajo contenido orgánico.
* **Zona 2 (Transición)**: Leve presencia de sedimentos en suspensión.
* **Zona 3 (Agrícola / Periurbana)**: Incremento de turbidez y nutrientes en suspensión.
* **Zona 4 (Impacto Urbano)**: Reducción drástica de visibilidad subacuática, cambios de coloración y alta presencia de microplásticos.

---

## 📄 Licencia y Créditos

Este proyecto está bajo la Licencia **MIT**. Consulta el archivo `LICENSE` para más información.

**Desarrollado para**: Universidad Nacional de Rosario (**UNR**) & **ICASFAS**.

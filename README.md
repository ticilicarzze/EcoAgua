# 🌊 EcoAgua UNR — Simulación VR del Arroyo Luduña

[![Godot Engine](https://img.shields.io/badge/Godot_Engine-v4.6_GL_Compatibility-blue?logo=godotengine)](https://godotengine.org/)
[![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20VR%20(Meta%20Quest)-brightgreen)](https://ecoagua-unr.netlify.app)
[![Deployment](https://img.shields.io/badge/Demo_Web-Live_en_Netlify-success?logo=netlify)](https://ecoagua-unr.netlify.app)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)

**EcoAgua UNR** es una simulación interactiva 3D en Realidad Virtual y WebGL desarrollada en **Godot Engine 4** que recrea el ecosistema del arroyo Luduña en la llanura pampeana argentina. El proyecto integra modelado de terreno procedimental, shaders de agua de alta fidelidad e indicadores ecológicos de degradación del agua basados en estudios de laboratorio de la **Universidad Nacional de Rosario (UNR)** y el instituto **ICASFAS**.

🌐 **Demo en vivo (Web/Desktop):** [https://ecoagua-unr.netlify.app](https://ecoagua-unr.netlify.app)

---

## 📋 Tabla de Contenidos

- [Estado del Prototipo](#-estado-del-prototipo)
- [Características Implementadas](#-características-implementadas)
- [Tecnologías](#-tecnologías)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Controles y Navegación](#-controles-y-navegación)
- [Instalación Local](#-instalación-local)
- [Despliegue a Producción](#-despliegue-a-producción)
- [Contexto Científico](#-contexto-científico)
- [Licencia y Créditos](#-licencia-y-créditos)

---

## 🚦 Estado del Prototipo

> **Primera muestra semifuncional — 21 de agosto de 2026**

| Módulo | Estado |
|---|---|
| Entorno 3D del río (terreno + agua) | ✅ Implementado |
| Shader de agua (Fresnel, cáusticas, espuma) | ✅ Implementado |
| 4 zonas ecológicas diferenciadas | ✅ Implementado |
| `WaterManager.gd` — métricas por zona + interpolación | ✅ Implementado |
| `WaterVisualController.gd` — parámetros visuales reactivos | ✅ Implementado |
| `HUDController.gd` — ICA y O₂ disuelto en tiempo real | ✅ Implementado |
| Fauna acuática animada (Mojarra, Bagre, Dientudo) | ✅ Implementado |
| Cámara libre Web/Desktop (`FreeLookCamera.gd`) | ✅ Implementado |
| Soporte VR Meta Quest 3 (APK nativa) | ✅ Implementado |
| Deploy web automatizado (Netlify) | ✅ Implementado |
| Sistema de audio por zonas | 🔄 Pendiente |
| Assets de degradación Zonas 3 y 4 | 🔄 Pendiente |
| Secuencia de alerta crítica (Zona 4) | 🔄 Pendiente |

---

## 🌟 Características Implementadas

### 💧 Shader de Agua de Alta Fidelidad (`watershader2.gdshader`)
- Reflexión **Fresnel** dinámica combinada con iluminación de cielo **HDRI**.
- Absorción de profundidad, refracción en pantalla, desplazamiento de cáusticas animadas y espuma procedimental.
- Color y velocidad del agua actualizados en tiempo real según la zona ecológica activa.

### 🌿 Sistema de Zonas Ecológicas (`WaterManager.gd`)
Singleton centralizado que gestiona la progresión a lo largo del recorrido del arroyo:

```
Zona 1 ──────── Zona 2 ──────── Zona 3 ──────── Zona 4
Cabecera       Agrícola       Periurbano       Crítico
0.0            0.25            0.50            0.75     1.0
```

| Parámetro | Zona 1 | Zona 2 | Zona 3 | Zona 4 |
|---|---|---|---|---|
| **ICA (WQI)** | 85–90 | 60–70 | 35–45 | 5–20 |
| **O₂ Disuelto** | 8.0–8.5 mg/L | 6.0–8.0 mg/L | 3.0–5.0 mg/L | 0.5–2.0 mg/L |
| **Velocidad** | 2.0 m/s | 1.2 m/s | 0.6 m/s | 0.1 m/s |
| **Visibilidad** | 120–160 cm | 70–90 cm | 40–60 cm | 15–20 cm |

Las transiciones entre zonas se interpolan suavemente en una ventana del 5% del recorrido total, evitando saltos visuales abruptos.

### 🐟 Fauna Acuática Animada
Tres especies implementadas con comportamiento independiente, heredando de la clase base `PezAnimado`:

| Especie | Script | Velocidad | Comportamiento |
|---|---|---|---|
| **Mojarra** | `MojarraAnimada.gd` | 3.0× Bagre | Bancos en órbita elíptica, fase única por grupo |
| **Dientudo** | `DientudoAnimado.gd` | 1.3× Bagre | Nado elíptico individual, coletazo proporcional |
| **Bagre** | `BagreAnimado.gd` | Velocidad base | Fondo del río, brillo adaptativo por zona, 0.7× en Z3–Z4 |

Cada pez tiene:
- Escala aleatoria dentro de rangos naturales por especie.
- Fase de órbita escalonada (sin agrupamiento robótico).
- Micro-variaciones de amplitud y frecuencia de coletazo.
- Lógica de evasión de orillas con `wall_boost_multiplier`.

El **Bagre** ajusta automáticamente el brillo de su material según la zona (mayor emisión en zonas turbias para mantener visibilidad).

### 📊 HUD en Tiempo Real (`HUDController.gd`)
Panel flotante que muestra:
- **ICA** (Índice de Calidad de Agua) en barra con gradiente Verde → Amarillo → Rojo.
- **O₂ Disuelto** (mg/L) con barra de porcentaje.
- Efecto de bamboleo sutil para simular la corriente.
- Actualización reactiva conectada a señales del `WaterManager`.

### 🥽 Soporte Multiplataforma
- **Modo VR (Meta Quest 3):** integración con **Godot XR Tools**, trackers de manos y joysticks para navegación por el `RiverPath`.
- **Modo Web/Desktop:** cámara libre interactiva con mouse y teclado.
- Detección automática de plataforma en `main.gd`.

### 🎨 Renderizado AgX
Implementación del tonemapper **AgX** para preservar la fidelidad cromática sin sobreexposición ni saturación indeseada, optimizado para el backend de Compatibilidad GL.

---

## 🛠️ Tecnologías

| Componente | Tecnología | Descripción |
|---|---|---|
| **Motor 3D** | Godot Engine 4.6 (GL Compatibility) | Backend liviano optimizado para VR standalone y WebGL |
| **Lenguaje** | GDScript 4 | Scripting nativo de Godot |
| **Shader de Agua** | Custom GLSL (`watershader2.gdshader`) | Normal maps duales, cáusticas triplanares y profundidad |
| **VR Framework** | Godot XR Tools | Manejo de trackers, manos y movimiento en visor |
| **Tonemapping** | AgX + HDRI Environment | Iluminación por imagen y gestión de rango dinámico |
| **Hosting Web** | Netlify + Cross-Origin Isolation | Soporte `SharedArrayBuffer` para WebGL |
| **CI/Deploy** | `deploy.sh` | Compilación headless + `_headers` + Netlify CLI |

---

## 📂 Estructura del Proyecto

```text
EcoAgua/
├── assets/
│   ├── hdris/              # Mapas de iluminación HDRI (4K / 2K)
│   ├── models/             # Geometría 3D de fauna y entorno
│   └── textures/           # Cáusticas, espuma y mapas de normales del agua
├── resources/
│   ├── environments/       # Recursos de ambiente (WorldEnvironment .tres)
│   └── shaders/            # watershader2.gdshader y shaders de terreno
├── scenes/
│   └── main.tscn           # Escena principal de la simulación
├── scripts/
│   ├── PezAnimado.gd           # Clase base para toda la fauna acuática
│   ├── MojarraAnimada.gd       # Comportamiento de bancos de Mojarras
│   ├── DientudoAnimado.gd      # Comportamiento de Dientudos
│   ├── BagreAnimado.gd         # Comportamiento de Bagres (con brillo adaptativo)
│   ├── FreeLookCamera.gd       # Control de cámara libre para Web / Desktop
│   ├── HUDController.gd        # HUD reactivo de ICA y O₂ disuelto
│   ├── WaterManager.gd         # Gestor central de métricas y zonas ecológicas
│   ├── WaterVisualController.gd # Actualizador de parámetros visuales del shader
│   └── main.gd                 # Controlador principal y detección de plataforma
├── custom_shell.html       # Shell web personalizada para WebXR
├── deploy.sh               # Script de build y deploy automático a Netlify
├── export_presets.cfg      # Configuración de exportación (Web + Android)
└── project.godot           # Configuración general del proyecto Godot 4
```

---

## 🎮 Controles y Navegación

### Modo Web / Desktop (Cámara Libre)
| Tecla / Acción | Función |
|---|---|
| `W / A / S / D` | Desplazar la cámara por el escenario |
| `Shift` | Turbo de velocidad |
| `Clic Derecho + Arrastrar` | Orientar la vista en 360° |
| `Q / E` | Subir / bajar altura de la cámara |

### Modo VR (Meta Quest 3)
| Acción | Función |
|---|---|
| **Head Tracker** | Orientación nativa de la mirada |
| **Joystick Izquierdo** | Avance por el `RiverPath` |
| **Joystick Derecho** | Rotación continua (snap o suave) |

---

## 💻 Instalación Local

### Prerrequisitos
- **Godot Engine 4.3+** o **4.6** → [Descargar](https://godotengine.org/)

### Pasos

```bash
# 1. Clonar el repositorio
git clone https://github.com/ticilicarzze/EcoAgua.git

# 2. Abrir Godot Engine → Importar → seleccionar:
#    EcoAgua/EcoAgua/project.godot

# 3. Ejecutar la escena principal
#    Presionar F5 o abrir scenes/main.tscn → Run
```

---

## 🚀 Despliegue a Producción

El proyecto incluye automatización completa para build y deploy a Netlify:

```bash
cd EcoAgua/EcoAgua
./deploy.sh
```

El script ejecuta transparentemente:
1. Compilación WebGL sin interfaz (`godot --headless --export-release`).
2. Generación del archivo `_headers` con `Cross-Origin-Opener-Policy` y `Cross-Origin-Embedder-Policy`.
3. Deploy inmediato a la red de producción de Netlify.

---

## 🔬 Contexto Científico

La simulación calibra visualmente el estado del agua a lo largo del recorrido del **Arroyo Luduña** (Rosario, Santa Fe) basándose en parámetros fisicoquímicos reales del **ICASFAS (UNR)**:

| Zona | Descripción | Características |
|---|---|---|
| **Zona 1 — Cabecera** | Estado basal / baja contaminación | Agua transparente, alta penetración de luz, fauna diversa |
| **Zona 2 — Agrícola / Ganadero** | Impacto agropecuario | Leve turbidez, presencia de sedimentos y nitratos |
| **Zona 3 — Periurbano / Agroindustrial** | Impacto agroindustrial | Turbidez alta, baja de oxígeno, presencia de efluentes |
| **Zona 4 — Crítico (Cierre)** | Impacto urbano e industrial severo | Oxígeno crítico (<2 mg/L), coloración oscura, microplásticos |

---

## 📄 Licencia y Créditos

Este proyecto está bajo la Licencia **MIT**. Consulta el archivo `LICENSE` para más información.

**Desarrollado para:** Universidad Nacional de Rosario (**UNR**) & **ICASFAS**  
**Motor:** Godot Engine 4.6 — GL Compatibility Backend

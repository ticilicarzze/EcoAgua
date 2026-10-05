# 🌊 EcoAgua UNR — Simulación VR del Arroyo Luduña

[![Godot Engine](https://img.shields.io/badge/Godot_Engine-v4.6_GL_Compatibility-blue?logo=godotengine)](https://godotengine.org/)
[![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20VR%20(Meta%20Quest)%20%7C%20Linux%20%7C%20Windows-brightgreen)](https://ecoagua-unr.netlify.app)
[![Deployment](https://img.shields.io/badge/Demo_Web-Live_en_Netlify-success?logo=netlify)](https://ecoagua-unr.netlify.app)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
[![Last Export](https://img.shields.io/badge/Última_exportación-03_oct_2026-informational)](https://github.com/ticilicarzze/EcoAgua)


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
- [📦 Descargas por Plataforma](#-descargas-por-plataforma)
- [Despliegue a Producción](#-despliegue-a-producción)
- [Contexto Científico](#-contexto-científico)
- [Licencia y Créditos](#-licencia-y-créditos)

---

## 🚦 Estado del Prototipo

> **Prototipo funcional completo — Octubre de 2026**

| Módulo | Estado |
|---|---|
| Entorno 3D del río (terreno procedural + lecho multi-textura pampeano) | ✅ Implementado |
| Shader de agua multi-zona (Fresnel, cáusticas, absorción, espuma) | ✅ Implementado |
| 4 zonas ecológicas diferenciadas (Cabecera, Agrícola, Periurbano, Crítico) | ✅ Implementado |
| `WaterManager.gd` — métricas por zona + interpolación en tiempo real | ✅ Implementado |
| `WaterVisualController.gd` — parámetros visuales reactivos | ✅ Implementado |
| `HUDController.gd` — Panel 2D para Web/Desktop (ICA, O₂, turbidez) | ✅ Implementado |
| `HUDControllerVR.gd` — HUD 3D estático anclado al carrito para Meta Quest 3 | ✅ Implementado |
| Fauna acuática animada (Mojarra, Bagre, Dientudo) | ✅ Implementado |
| Sistema de audio dinámico y locución por zonas (`AudioManager.gd`) | ✅ Implementado |
| Assets de degradación en Zonas 3 y 4 (industrias, caños, basura, barriles) | ✅ Implementado |
| Secuencia narrativa lineal (inmersión, tarjetas, emersión, créditos) | ✅ Implementado |
| Bloqueo de posición VR 6DOF al carrito con rotación libre 360° | ✅ Implementado |
| Detección temporal precisa de inmersión/emersión en VR | ✅ Implementado |
| Atajo de reinicio rápido de operador (Gatillo + Botón por 3 s / Tecla R) | ✅ Implementado |
| Cámara libre Web/Desktop (`FreeLookCamera.gd` y fallback integrado) | ✅ Implementado |
| Soporte VR nativo Meta Quest 3 (OpenXR / APK) | ✅ Implementado |
| Deploy web automatizado (Netlify) | ✅ Implementado |

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

### 📊 HUD Dual Reactivo (`HUDController.gd` / `HUDControllerVR.gd`)
- **Modo Web / Desktop (`HUDController.gd`):** Panel 2D con barras reactivas de **ICA** (Verde → Amarillo → Rojo), **Oxígeno Disuelto** (mg/L), turbidez y bamboleo sutil por corriente.
- **Modo VR Meta Quest 3 (`HUDControllerVR.gd`):** Panel 3D renderizado en textura `SubViewport` proyectado sobre un Quad frontal fijo al carro de transporte (`UserCart`). Permite lectura estática y cómoda independiente de la orientación de la cabeza, sin oclusiones ni mareos, con subtítulos desactivados en VR para evitar distracciones en el campo visual.

### 🥽 Soporte VR Standalone (Meta Quest 3)
- **Tracking 6DOF con cámara anclada:** La rotación 360° de la cabeza es totalmente libre, mientras que los desplazamientos físicos involuntarios (pararse, sentarse) son compensados respecto al carro para garantizar que la vista nunca quede desfasada o sumergida por error.
- **Transiciones temporizadas de inmersión/emersión:** La activación/desactivación de neblina y partículas subacuáticas se gestiona por sincronización temporal narrativa, asegurando transiciones impecables al emerger a superficie sin depender de umbrales espaciales imprecisos.
- **Atajo de reinicio con un solo mando:** Diseñado para operadores en eventos (mantener Gatillo + Botón por 3 segundos con respuesta háptica).

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
│   ├── audio/              # Locuciones, efectos de agua y ambientes sonoros
│   ├── hdris/              # Mapas de iluminación HDRI (4K / 2K)
│   ├── models/             # Geometría 3D de fauna, flora y entorno
│   └── textures/           # Cáusticas, espuma y mapas de suelo/normales
├── resources/
│   ├── environments/       # Recursos de ambiente (WorldEnvironment .tres)
│   └── shaders/            # watershader2.gdshader y shaders de terreno
├── scenes/
│   └── main.tscn           # Escena principal de la simulación
├── scripts/
│   ├── AudioManager.gd         # Gestor central de audio y locuciones narrativas
│   ├── PezAnimado.gd           # Clase base para toda la fauna acuática
│   ├── MojarraAnimada.gd       # Comportamiento de bancos de Mojarras
│   ├── DientudoAnimado.gd      # Comportamiento de Dientudos
│   ├── BagreAnimado.gd         # Comportamiento de Bagres (con brillo adaptativo)
│   ├── HUDController.gd        # HUD 2D reactivo de ICA y O₂ para Web/PC
│   ├── HUDControllerVR.gd      # HUD 3D en quad frontal para Meta Quest 3
│   ├── WaterManager.gd         # Gestor central de métricas y zonas ecológicas
│   ├── WaterVisualController.gd # Actualizador de parámetros visuales del shader
│   └── main.gd                 # Orquestador narrativo, control VR y atajo de reinicio
├── custom_shell.html       # Shell web personalizada para WebXR
├── deploy.sh               # Script de build y deploy automático a Netlify
├── export_presets.cfg      # Configuración de exportación (Web + Android)
└── project.godot           # Configuración general del proyecto Godot 4
```

---

## 🎮 Controles y Navegación

### Modo VR (Meta Quest 3 — Operable con 1 solo control)
| Control / Gesto | Función |
|---|---|
| **Head Tracking (Visor)** | Orientación natural libre en 360° (pitch, yaw, roll). La cámara se mantiene anclada al carro sin desfasarse por movimientos corporales. |
| **Cualquier Botón o Gatillo** | Iniciar inmersión (al estar en la pantalla inicial de bienvenida). |
| **Gatillo + Botón (Mantener 3 segundos)** | **Atajo de reinicio rápido para operador:** Mantener presionado cualquier gatillo (*Index Trigger* o *Hand Grip*) junto con cualquier botón (*A*, *B*, *X*, *Y*, *Menú* o *Joystick click*) en un único mando durante **3 segundos**.<br>• *Feedback háptico:* El mando vibra con pulsos que aumentan progresivamente hasta dar una vibración continua a los 3 s, reiniciando la simulación al estado inicial para el siguiente participante. |

### Modo Web / Desktop (Cámara Libre)
| Tecla / Acción | Función |
|---|---|
| `W / A / S / D` | Desplazar la cámara por el arroyo |
| `Shift` | Acelerar velocidad de desplazamiento |
| `Clic Izquierdo o Derecho + Arrastrar` | Orientar la vista libre en 360° |
| `Espacio / Enter` | Iniciar inmersión desde la pantalla inicial |
| `R` | **Atajo de reinicio rápido para operador** (recarga instantánea al inicio) |
| `Escape` | Liberar captura del cursor del mouse |

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

## 📦 Descargas por Plataforma

> **Última exportación:** Septiembre 2026

Los binarios se generan automáticamente con `export_multiplatform.sh`. Los exports se guardan junto al repositorio en:

| Plataforma | Archivo | Instrucciones |
|---|---|---|
| 📱 **Meta Quest 3 (APK)** | `EcoAgua_Quest3HUD.apk` | Instalar vía [SideQuest](https://sidequestvr.com) o `adb install EcoAgua_Quest3HUD.apk` |
| 🐧 **Linux x86_64** | `EcoAgua_PC_Linux/EcoAgua.x86_64` | `chmod +x EcoAgua.x86_64 && ./EcoAgua.x86_64` |
| 🪟 **Windows x86_64** | `EcoAgua_PC_Windows/EcoAgua.exe` | Ejecutar `EcoAgua.exe` directamente |

### Instalar APK en Meta Quest 3 (sin tienda)

```bash
# Con el Quest conectado por USB y modo desarrollador activado:
adb install ../EcoAgua_Quest3HUD.apk
```

O bien, arrastrar el `.apk` a la sección **Unknown Sources** de SideQuest.

---

## 🚀 Despliegue a Producción

El proyecto incluye automatización completa para build y deploy:

### 🌐 Deploy Web (Netlify)

```bash
cd EcoAgua/EcoAgua
./deploy.sh
```

El script ejecuta transparentemente:
1. Compilación WebGL sin interfaz (`godot --headless --export-release`).
2. Generación del archivo `_headers` con `Cross-Origin-Opener-Policy` y `Cross-Origin-Embedder-Policy`.
3. Deploy inmediato a la red de producción de Netlify.

### 📦 Export Multi-Plataforma (APK + Linux + Windows + GitHub)

```bash
cd EcoAgua/EcoAgua
./export_multiplatform.sh
```

El script ejecuta automáticamente:
1. Commit de todos los cambios pendientes.
2. Exportación APK para **Meta Quest 3** → `../EcoAgua_Quest3HUD.apk`.
3. Exportación **Linux x86_64** → `../EcoAgua_PC_Linux/EcoAgua.x86_64`.
4. Exportación **Windows x86_64** → `../EcoAgua_PC_Windows/EcoAgua.exe`.
5. Actualización del README con fecha de exportación.
6. Push automático a GitHub (`origin main`).

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

## 👥 Equipo y Créditos

### Equipo 5
- **Promotoras:** Agustina Ferraro & Ana Paula Martin
- **Gestor:** Jose Luis Gaitan
- **Desarrollador:** Ticiano Licarzze
- **Diseño:** Virginia Sofia Guido

---

## 📄 Licencia e Instituciones

Este proyecto está bajo la Licencia **MIT**. Consulta el archivo `LICENSE` para más información.

- **Iniciativa:** **#XperienciaUNR** (Tercera edición)
- **Desarrollado para:** Universidad Nacional de Rosario (**UNR**) & **ICASFAS**  
- **Motor:** Godot Engine 4.6 — GL Compatibility Backend

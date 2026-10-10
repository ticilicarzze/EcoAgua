# 🌊 EcoAgua UNR — Simulación VR del Arroyo Luduña

[![Godot Engine](https://img.shields.io/badge/Godot_Engine-v4.6_GL_Compatibility-blue?logo=godotengine)](https://godotengine.org/)
[![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20VR%20(Meta%20Quest%203)%20%7C%20Linux%20%7C%20Windows-brightgreen)](https://ecoagua-unr.netlify.app)
[![Deployment](https://img.shields.io/badge/Demo_Web-Live_en_Netlify-success?logo=netlify)](https://ecoagua-unr.netlify.app)
[![License](https://img.shields.io/badge/License-MIT-orange.svg)](LICENSE)
[![Last Export](https://img.shields.io/badge/Última_exportación-10_oct_2026-informational)](https://github.com/ticilicarzze/EcoAgua)

**EcoAgua UNR** es una simulación interactiva 3D en Realidad Virtual y WebGL desarrollada en **Godot Engine 4** que recrea el ecosistema del arroyo Luduña en la llanura pampeana argentina. El proyecto integra modelado de terreno procedimental, shaders de agua de alta fidelidad e indicadores ecológicos de degradación del agua basados en estudios de laboratorio de la **Universidad Nacional de Rosario (UNR)**.

🌐 **Demo en vivo (Web/Desktop):** [https://ecoagua-unr.netlify.app](https://ecoagua-unr.netlify.app)

---

## 📋 Tabla de Contenidos

- [Estado del Prototipo](#-estado-del-prototipo)
- [Características Implementadas](#-características-implementadas)
  - [Pipeline de Shaders GLSL](#-pipeline-de-shaders-glsl)
  - [Tonemapping Filmic e Iluminación HDRI](#-tonemapping-filmic-e-iluminación-hdri)
  - [Sistema de Zonas Ecológicas y Telemetría](#-sistema-de-zonas-ecológicas-y-telemetría)
  - [Generación Procedural de Flora (MultiMesh)](#-generación-procedural-de-flora-multimesh)
  - [Fauna Acuática y Ribereña Animada](#-fauna-acuática-y-ribereña-animada)
  - [Paisaje Sonoro y Audio Narrativo](#-paisaje-sonoro-y-audio-narrativo)
  - [HUD Dual Reactivo (Desktop & VR)](#-hud-dual-reactivo-desktop--vr)
  - [Ergonomía e Inmersión VR en Meta Quest 3](#-ergonomía-e-inmersión-vr-en-meta-quest-3)
- [Tecnologías y Stack Técnico](#️-tecnologías-y-stack-técnico)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Controles y Navegación](#-controles-y-navegación)
- [Instalación Local](#-instalación-local)
- [Descargas por Plataforma](#-descargas-por-plataforma)
- [Despliegue y Automatización](#-despliegue-y-automatización)
- [Contexto Científico y Datos](#-contexto-científico-y-datos)
- [Equipo y Créditos](#-equipo-y-créditos)

---

## 🚦 Estado del Prototipo

> **Prototipo funcional completo — Octubre de 2026**

| Módulo | Estado | Descripción técnica |
|---|:---:|---|
| **Canal y Terreno 3D** | ✅ | Lecho del río con deformación por `FastNoiseLite` y texturas multizona con shader procedural. |
| **Shader de Agua (`watershader2.gdshader`)** | ✅ | Normal maps duales, refracción en pantalla, cáusticas y absorción por ley de Beer. |
| **Parches de Espuma (`foam_patch.gdshader`)** | ✅ | Espuma contaminante generada procedimentalmente en zonas 3 y 4 (`FoamPatches.tscn`). |
| **4 Zonas Ecológicas** | ✅ | Cabecera, Agrícola, Periurbano y Crítico interpoladas dinámicamente (`WaterManager.gd`). |
| **Flora Ribereña Optimizada** | ✅ | Instanciación por `MultiMeshInstance3D` en `FloraGenerator.gd` para sostener 72–90 FPS en VR. |
| **Fauna Acuática (3 especies)** | ✅ | Comportamiento procedural de Mojarras, Dientudos y Bagres con autoiluminación adaptativa. |
| **Fauna Terrestre de Ribera** | ✅ | Modelos 3D de fauna nativa pampeana (Tero, Rana Criolla) distribuidos por el cauce. |
| **Sistema de Audio (`AudioManager.gd`)** | ✅ | Máquina de estados narrativos (21 fases), audio 3D posicional y filtrado subacuático. |
| **HUD 2D para Web/Desktop** | ✅ | Interfaz CanvasLayer reactiva con barras de ICA, O₂ y bamboleo por corriente (`HUDController.gd`). |
| **HUD 3D para Meta Quest 3** | ✅ | Proyección en `SubViewport` sobre quad estático anclado al `UserCart` (`HUDControllerVR.gd`). |
| **Soporte VR Standalone (Quest 3)** | ✅ | OpenXR nativo vía `godotopenxrvendors`, 6DOF con bloqueo antivértigo y atajo háptico de reinicio. |
| **Cámara Libre Web/Desktop** | ✅ | Control WASD + mouse con captura de cursor y cambio dinámico (`FreeLookCamera.gd`). |
| **Render y Tonemapping** | ✅ | Backend **GL Compatibility** calibrado con tonemapper **Filmic** para WebGL2 y Android VR. |
| **Deploy Multi-Plataforma** | ✅ | Scripts automatizados para Netlify (Web), itch.io (<200MB) y exportación PC / APK. |

---

## 🌟 Características Implementadas

### 💧 Pipeline de Shaders GLSL

El apartado visual del agua y el entorno prescinde de texturas pesadas estáticas y se basa en shaders GLSL escritos a medida:

1. **Agua Superficial (`resources/shaders/watershader2.gdshader`):**
   - **Flujo dinámico:** Fusión de dos mapas de normales (`normal_A.png`, `normal_B.png`) que se desplazan a contracorriente con factores de escala independientes.
   - **Absorción de luz (Ley de Beer):** Atenuación exponencial de la luz según la profundidad calculada con la textura de profundidad del búfer (`depth_texture`).
   - **Cáusticas triplanares animadas:** Proyección de mapa de cáusticas sobre el lecho del río modulado por la profundidad del agua.
   - **Reflexión Fresnel calibrada:** Transición gradual entre el color de base del río y el reflejo del cielo HDRI según el ángulo de visión.
   - **Perfiles visuales por zona (`WaterVisualController.gd`):** Las propiedades del material (rugosidad, atenuación Beer, colores superficiales y profundos) se actualizan dinámicamente:
     - *Zona 1:* Color café con leche muy claro traslúcido, atenuación baja (`beers_law = 0.35`), oleaje vivo.
     - *Zona 2:* Marrón orgánico con sedimentos en suspensión (`beers_law = 0.65`).
     - *Zona 3:* Chocolate espeso (`beers_law = 1.10`), velocidad reducida.
     - *Zona 4:* Lodo oscuro / fango crítico (`beers_law = 1.80`), oleaje estancado.

2. **Parches de Espuma Contaminante (`resources/shaders/foam_patch.gdshader`):**
   - Shaders dedicados para recrear espuma superficial por surfactantes, detergentes y efluentes industriales en los tramos críticos (Zonas 3 y 4).

3. **Vegetación con Movimiento de Viento (`resources/shaders/foliage.gdshader`):**
   - Deformación de vértices en GPU para simular la brisa ribereña pampeana sobre juncos, cortaderas y totoras sin costo de CPU.

---

### 🎨 Tonemapping Filmic e Iluminación HDRI

A diferencia de configuraciones convencionales o backends pesados (Vulkan Forward+), el proyecto implementa una calibración cromática específica para el backend **GL Compatibility**:

```gdscript
# Configuración en scripts/main.gd y resources/environments/env_op1.tres:
env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
env.tonemap_exposure = 0.88
env.tonemap_white = 4.0
```

* **¿Por qué Filmic en lugar de AgX o Linear?**
  - **Compatibilidad 100% garantizada:** Es completamente estable tanto en navegadores (WebGL2) como en los visores Meta Quest 3 standalone (Android / OpenGL ES 3.0), evitando artefactos y shaders no soportados.
  - **Fidelidad del agua pampeana:** Proporciona una curva de compresión de altas luces cinematográfica que evita que los brillos especulares del sol o las cáusticas "quemen" los blancos, preservando la saturación de los verdes y marrones arcillosos característicos del Luduña.

---

### 🌿 Sistema de Zonas Ecológicas y Telemetría

La simulación divide el curso de agua en 4 estaciones basadas en datos del **ICASFAS (UNR)** y publicaciones científicas sobre la cuenca del Arroyo Luduña (Amaya, 2018):

```
Zona 1 (0.00 – 0.25) ─── Zona 2 (0.25 – 0.50) ─── Zona 3 (0.50 – 0.75) ─── Zona 4 (0.75 – 1.00)
    Cabecera                Agrícola               Periurbano               Crítico
(Transparente / Vida)    (Sedimentos / Agro)     (Residuos / Urbano)     (Anoxia / Toxicidad)
```

| Parámetro | Zona 1 (Cabecera) | Zona 2 (Agrícola) | Zona 3 (Periurbana) | Zona 4 (Crítica) |
|---|:---:|:---:|:---:|:---:|
| **Índice ICA (WQI)** | 85 – 95 *(Excelente)* | 70 – 75 *(Bueno)* | 40 – 45 *(Regular)* | 10 – 20 *(Crítico)* |
| **Oxígeno Disuelto (OD)** | 8.0 – 8.5 mg/L | 6.0 – 8.0 mg/L | 3.0 – 5.0 mg/L | 0.5 – 2.0 mg/L |
| **Nitratos ($NO_3^-$)** | < 10 mg/L | 25 – 45 mg/L | 30 – 50 mg/L | > 50 mg/L |
| **Fosfatos ($PO_4^{3-}$)** | < 0.1 mg/L | 0.5 – 1.5 mg/L | 1.0 – 2.5 mg/L | > 3.0 mg/L |
| **DBO₅** | < 3 mg/L | 3 – 8 mg/L | 15 – 35 mg/L | > 50 mg/L |
| **Coliformes Fecales** | < 200 UFC/100mL | 500 – 2.000 UFC | 10.000 – 50.000 UFC | > 100.000 UFC |
| **Metales Pesados (Cromo)** | No detectado | Trazas | Detectable | Elevado (Curtiembres) |
| **Visibilidad bajo agua** | 120 – 160 cm | 70 – 90 cm | 40 – 60 cm | 15 – 20 cm |

El singleton `WaterManager.gd` interpola continuamente las métricas a lo largo del progreso (`progress_ratio`), notificando a la interfaz y al shader mediante señales de Godot.

---

### 🌾 Generación Procedural de Flora (MultiMesh)

Para poblar las riberas con vegetación densa (ceibos, sauces criollos, cortaderas, pastizales, juncos y totoras) sin comprometer la tasa de cuadros en Realidad Virtual:
- `FloraGenerator.gd` analiza la curvatura matemática del río (`RiverPath / Curve3D`).
- Distribuye especies por estratos ecológicos de ribera y por zonas.
- Empaqueta las instancias en nodos **`MultiMeshInstance3D`** agrupados, reduciendo cientos de llamadas de dibujado (*draw calls*) a un puñado de batches en la GPU.

---

### 🐟 Fauna Acuática y Ribereña Animada

La fauna acuática hereda de una arquitectura común orientada a objetos (`PezAnimado.gd`):

1. **Mojarra (`MojarraAnimada.gd`):** Bancos que nadan en órbitas elípticas sincronizadas con offsets de fase únicos, reaccionando a la corriente.
2. **Dientudo (`DientudoAnimado.gd`):** Depredador ágil con nado individual, aceleraciones repentinas y mayor frecuencia de aleteo.
3. **Bagre (`BagreAnimado.gd`):** Pez de fondo que patrulla el lecho del río. Incorpora un **sistema de iluminación emisiva adaptativa**: a medida que el agua se torna turbia en las Zonas 3 y 4, eleva su canal de emisión para permanecer visible para el usuario.
4. **Fauna Terrestre:** Modelos animados de especies autóctonas en las costas: el **Tero** pampeano y la **Rana Criolla**.

---

### 🔊 Paisaje Sonoro y Audio Narrativo

El script central `AudioManager.gd` orquesta la experiencia sonora con una máquina de **21 estados narrativos** (`NarrativeState`):
- **Locuciones sincronizadas:** Narración guiada que explica cada sección del arroyo y presenta los carteles de métricas de calidad de agua.
- **Audio 3D espacializado:** Sonidos de ribera, viento en los pajonales y cantos de aves distribuidos geográficamente a lo largo de las orillas.
- **Transición subacuática dinámica:** Al cruzar la línea de flotación (`WATER_SURFACE_Y`), el motor conmuta instantáneamente entre el ambiente aéreo y el búfer subacuático con filtrado sordo de bajas frecuencias y partículas de inmersión.

---

### 📊 HUD Dual Reactivo (Desktop & VR)

Diseñado en colaboración con el área de diseño visual para traducir las especificaciones químicas a un sistema accesible:

* **Modo Web / Desktop (`HUDController.gd`):**
  - Panel 2D responsive implementado con nodos `Control` y texturas **9-Slice** (`NinePatchRect`).
  - Barras animadas de ICA y Oxígeno Disuelto con gradiente dinámico (Verde ➔ Amarillo ➔ Naranja ➔ Rojo).
  - Micro-movimiento sutil (*sway*) que acompaña la inercia del río.
* **Modo VR Meta Quest 3 (`HUDControllerVR.gd`):**
  - Para evitar mareos por movimiento (*motion sickness*), la interfaz 2D se proyecta dentro de un **`SubViewport`** sobre una malla Quad 3D fijada al frente del carro (`UserCart`).
  - Mantiene una distancia focal y ángulo ergonómicos constantes respecto a los ojos, permitiendo girar la cabeza libremente en 360° sin perder de vista la información ni sufrir superposiciones molestas.

---

### 🥽 Ergonomía e Inmersión VR en Meta Quest 3

* **OpenXR & Godot XR Tools:** Integración estándar con soporte para mandos Touch Plus de Meta Quest 3.
* **Compensación de postura 6DOF:** El usuario puede girar la cabeza libremente en 360°, pero las variaciones de altura corporal involuntarias (pararse o sentarse) se compensan para garantizar que la vista nunca quede hundida por debajo del lecho del río ni fuera del carro.
* **Transiciones de emersión suaves:** Algoritmo de subida/bajada pausada (2.5 s de descenso y 2.6 s de ascenso) con cruce temporal exacto de la línea de flotación a los 1.25 segundos.
* **Atajo de reinicio para operadores:** Diseñado para exposiciones y ferias académicas donde participan muchas personas sucesivamente:
  - Mantener presionado cualquier gatillo (*Index Trigger* o *Hand Grip*) junto con cualquier botón frontal (*A*, *B*, *X*, *Y*, *Menú*) en un solo mando durante **3 segundos**.
  - El mando emite pulsos hápticos (vibración) incrementales hasta vibrar de forma continua al tercer segundo, recargando la experiencia desde el inicio sin necesidad de reiniciar la app o sacarle el visor al participante.

---

## 🛠️ Tecnologías y Stack Técnico

| Componente | Tecnología | Propósito en el proyecto |
|---|---|---|
| **Motor 3D** | **Godot Engine 4.6** | Motor principal optimizado para compatibilidad multiplataforma y bajo consumo de recursos. |
| **Backend de Render** | **GL Compatibility (OpenGL ES 3.0 / WebGL2)** | Backend ligero y universal requerido para compatibilidad simultánea en navegadores y Meta Quest 3. |
| **Lenguaje de Programación** | **GDScript 4** | Lógica de simulación, máquina de estados narrativos, telemetría y matemáticas de interpolación. |
| **Motor de Física** | **Jolt Physics 3D** | Integración nativa de física rápida y estable. |
| **Pipeline de Shaders** | **Custom GLSL Shaders** | `watershader2` (agua fluida), `foam_patch` (espuma contaminante), `terrain_zones` y `foliage` (vegetación). |
| **Framework de Realidad Virtual** | **OpenXR + Godot XR Tools + Meta XR Vendor Plugin** | Control de rastreo 6DOF, controladores, háptica, mapa de acciones (`openxr_action_map.tres`) y soporte Quest 3. |
| **Iluminación y Color** | **Panorama HDRI (2K) + Tonemapping Filmic** | Rango dinámico y compresión de luminancia cinematográfica sin recorte de blancos. |
| **Optimización de Escena** | **MultiMeshInstance3D** | Batching por hardware para miles de plantas ribereñas, sosteniendo 72–90 FPS en standalone. |
| **Diseño y Sistema UI** | **Godot Control Nodes + 9-Slice Panels** | Interfaz modular reactiva basada en especificaciones gráficas en canal Alpha y tipografías dinámicas. |
| **Despliegue Web** | **Netlify + Cross-Origin Isolation** | Configuración de cabeceras COOP/COEP para habilitar `SharedArrayBuffer` en WebGL multihilo. |
| **Empaquetado Web Alternativo** | **itch.io Package Optimizer (`package_itch.sh`)** | Compresión y ensamblado de paquete WebGL reduciendo el `.pck` a ~137 MB (<200 MB límite). |
| **Pipeline Multi-Build** | **Bash (`export_multiplatform.sh`)** | Exportación desatendida en un solo comando para Meta Quest 3 APK, Linux x86_64 y Windows x86_64. |

---

## 📂 Estructura del Proyecto

```text
EcoAgua/
├── assets/
│   ├── fonts/              # Tipografías del proyecto (Cousine TTF)
│   ├── hdris/              # Mapas de entorno panorámico HDR (grasslands_sunset_2k.hdr)
│   ├── models/             # Modelos 3D (.glb) organizados por zona (ZONA1 a ZONA4):
│   │   ├── Fauna acuática/ # Mojarra, Bagre y Dientudo con animaciones de natación
│   │   ├── Fauna terrestre/# Rana Criolla y Tero
│   │   ├── Flora/          # Árboles secos, ceibos, sauces, pastizales pampeanos
│   │   ├── Infraestructura/# Granjas, postes, fábricas, semáforos, chimeneas
│   │   └── Vegetacion Acuática/# Ceratophyllum, lentejas de agua, algas filamentosas
│   ├── sounds/             # Locuciones narrativas, cantos de aves, río y efectos de inmersión
│   └── textures/           # Mapas de normales A/B, cáusticas triplanares, espuma y créditos
├── docs/                   # Documentación técnica, diseño e investigación (con .gdignore)
│   ├── planning/           # Backlog de sprints y mapa de navegación
│   ├── research/           # Contexto científico, reglas de flora y distribución de zonas
│   └── specifications/     # Especificaciones técnicas de HUD UI/UX (HTML, DOCX, MD)
├── resources/
│   ├── environments/       # Recurso WorldEnvironment con Filmic tonemapping (env_op1.tres)
│   ├── materials/          # Materiales preconfigurados (foam_patch_material.tres)
│   └── shaders/            # watershader2.gdshader, foam_patch.gdshader, foliage.gdshader
├── scenes/
│   ├── FoamPatches.tscn    # Malla distribuida de parches de espuma contaminante (Z3 y Z4)
│   ├── main.tscn           # Escena principal con RiverPath, UserCart, luces y controladores
│   └── preview_peces.tscn  # Entorno de pruebas aislado para validar natación de peces
├── scripts/
│   ├── AudioManager.gd         # Gestor central de paisaje sonoro y máquina de 21 estados
│   ├── BagreAnimado.gd         # Comportamiento de fondo del Bagre con brillo adaptativo
│   ├── DientudoAnimado.gd      # Comportamiento del pez Dientudo (depredador rápido)
│   ├── FloraConfig.gd          # Recurso de configuración de densidad de flora
│   ├── FloraGenerator.gd       # Generador procedural ribereño con MultiMeshInstance3D
│   ├── FreeLookCamera.gd       # Controlador de cámara libre para depuración en Desktop
│   ├── HUDController.gd        # Controlador 2D de interfaz para Web y Desktop
│   ├── HUDControllerVR.gd      # Controlador 3D en SubViewport Quad para Meta Quest 3
│   ├── MojarraAnimada.gd       # Comportamiento de bancos en órbita de Mojarras
│   ├── PezAnimado.gd           # Clase base con matemáticas de natación y evasión de orillas
│   ├── WaterManager.gd         # Singleton de telemetría e interpolación de métricas ICA/OD
│   ├── WaterVisualController.gd# Enlace en tiempo real entre WaterManager y watershader2
│   └── main.gd                 # Orquestador maestro del recorrido, VR, estados y reinicio
├── tools/                  # Utilidades y herramientas de desarrollo (con .gdignore)
│   └── generate_scene.py   # Script de generación auxiliar de nodos
├── custom_shell.html       # Plantilla HTML personalizada para WebGL y WebXR
├── deploy.sh               # Script de compilación headless y despliegue continuo a Netlify
├── export_multiplatform.sh # Compilación desatendida: Quest 3 APK + Linux + Windows + Push
├── export_presets.cfg      # Presets de exportación para Godot (Web, Android, PC)
├── openxr_action_map.tres  # Asignación estándar de botones, gatillos y háptica OpenXR
├── package_itch.sh         # Script de empaquetado optimizado para itch.io
└── project.godot           # Configuración central del motor Godot 4.6
```

---

## 🎮 Controles y Navegación

### Modo VR (Meta Quest 3 — Operable con 1 solo control)

Diseñado para facilitar la operación en ferias y eventos donde el usuario o el operador maneja un único mando:

| Control / Gesto | Acción |
|---|---|
| **Visor (Head Tracking 6DOF)** | Giro natural de cabeza en 360°. La posición permanece bloqueada ergonómicamente al carro. |
| **Cualquier Gatillo o Botón** | Iniciar la inmersión al comenzar la experiencia. |
| **Gatillo + Botón (Mantener 3 s)** | **Reinicio rápido de operador:** Mantener presionado cualquier gatillo (*Index* o *Grip*) + cualquier botón (*A*, *B*, *X*, *Y*, *Menú* o *Stick*) durante 3 segundos.<br>• *Vibración progresiva:* Pulsos táctiles que se intensifican hasta reiniciar la simulación a la pantalla inicial. |

### Modo Web / Desktop (Cámara Libre)

| Tecla / Acción | Acción |
|---|---|
| `W / A / S / D` | Desplazar la cámara a lo largo y ancho del cauce del río. |
| `Shift` | Acelerar el desplazamiento de cámara libre. |
| `Clic + Arrastrar Mouse` | Rotar la orientación de la cámara en 360°. |
| `Espacio / Enter` | Comenzar el recorrido desde la pantalla de bienvenida. |
| `R` | **Reinicio rápido:** Recarga instantáneamente la escena al estado inicial. |
| `Escape` | Liberar el cursor capturado por la ventana. |

---

## 💻 Instalación Local

### Prerrequisitos
* **Godot Engine 4.3+** o **4.6** (Standard Edition) → [godotengine.org](https://godotengine.org/)
* Opcional para compilar Android VR: Android SDK & NDK + Java OpenJDK 17.

### Pasos

```bash
# 1. Clonar el repositorio
git clone https://github.com/ticilicarzze/EcoAgua.git

# 2. Abrir Godot Engine
#    Hacer clic en "Importar" y seleccionar el archivo project.godot dentro de la carpeta clonada.

# 3. Ejecutar el proyecto
#    Presionar F5 para lanzar la simulación desde scenes/main.tscn.
```

---

## 📦 Descargas por Plataforma

> **Última exportación:** 10-10-2026 16:42

Los binarios se compilan automáticamente mediante `export_multiplatform.sh`:

| Plataforma | Binario generado | Modo de ejecución |
|---|---|---|
| 🥽 **Meta Quest 3 (APK)** | `EcoAgua_Quest3HUD.apk` | Instalar mediante [SideQuest](https://sidequestvr.com) o `adb install EcoAgua_Quest3HUD.apk` con modo desarrollador. |
| 🐧 **Linux x86_64** | `EcoAgua_PC_Linux/EcoAgua.x86_64` | `chmod +x EcoAgua.x86_64 && ./EcoAgua.x86_64` |
| 🪟 **Windows x86_64** | `EcoAgua_PC_Windows/EcoAgua.exe` | Ejecutar `EcoAgua.exe` directamente. |

---

## 🚀 Despliegue y Automatización

El repositorio incluye automatización completa mediante scripts Bash:

### 1. Despliegue Web a Netlify (`./deploy.sh`)
```bash
./deploy.sh
```
Compila Godot de forma desatendida en modo headless (`--export-release "Web"`), inyecta el archivo `_headers` con las políticas de aislamiento de orígenes cruzados (`Cross-Origin-Opener-Policy: same-origin` y `Cross-Origin-Embedder-Policy: require-corp`) requeridas por `SharedArrayBuffer` en WebGL2 multihilo, y publica automáticamente a Netlify mediante su CLI.

### 2. Empaquetado para itch.io (`./package_itch.sh`)
```bash
./package_itch.sh
```
Exporta la versión Web optimizada, reduce el archivo `index.pck` a ~137 MB para respetar el límite de subida rápida de 200 MB de itch.io y empaqueta un archivo listo `web_export.zip`.

### 3. Compilación Multiplataforma Total (`./export_multiplatform.sh`)
```bash
./export_multiplatform.sh
```
Realiza auto-commit en git, compila en paralelo el APK de Meta Quest 3, el binario de Linux y el ejecutable de Windows, renueva la fecha de exportación en la documentación y sube los cambios al repositorio remoto en GitHub.

---

## 🔬 Contexto Científico y Datos

La degradación ecológica simulada en EcoAgua reproduce fielmente los diagnósticos limnológicos realizados sobre la cuenca del **Arroyo Luduña** (Santa Fe, Argentina):

* **Zona 1 — Cabecera:** Zona con mínima intervención antrópica relativa. Alta saturación de oxígeno disuelto (>8 mg/L), aguas transparentes con penetración lumínica y presencia de macrófitas y peces autóctonos.
* **Zona 2 — Tramo Agrícola/Ganadero:** Introducción de escorrentía difusa rica en fertilizantes nitrogenados y fosforados. Comienzo del incremento de turbidez por sedimentos finos arcillosos.
* **Zona 3 — Periurbano e Industrial:** Presencia de descargas cloacales e industriales no tratadas. Caída pronunciada del oxígeno disuelto, incremento de DBO₅ y proliferación bacteriana (coliformes fecales).
* **Zona 4 — Desembocadura / Tramo Crítico:** Impacto urbano masivo. Condiciones de hipoxia severa o anoxia (<2 mg/L), acumulación de metales pesados (Cromo), desechos sólidos y formación de espumas surfactantes estables.

**Referencias:**
* *ICASFAS (Instituto de Ciencias Ambientales, de la Sustentabilidad y Formación Ambiental del Sur)* — Universidad Nacional de Rosario (**UNR**).
* *Amaya, E. et al. (2018):* Índices de calidad de agua y evaluación ambiental de cuencas de llanura pampeana.

---

## 👥 Equipo y Créditos

### Equipo 5
* **Promotoras:** Agustina Ferraro & Ana Paula Martin
* **Gestor:** Jose Luis Gaitan
* **Desarrollador:** Ticiano Licarzze
* **Diseño Visual & UI/UX:** Virginia Sofia Guido

---

## 📄 Licencia e Instituciones

Este proyecto se distribuye bajo la Licencia **MIT**. Consulta el archivo `LICENSE` para más información.

* **Iniciativa:** **#XperienciaUNR** (Tercera edición)
* **Institución:** Universidad Nacional de Rosario (**UNR**)  
* **Motor:** Godot Engine 4.6 (GL Compatibility Backend)

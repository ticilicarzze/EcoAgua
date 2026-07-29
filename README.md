# 🌊 EcoAgua UNR - VR & Web River Environment Simulation

![Godot Engine](https://img.shields.io/badge/Godot_Engine-v4.6_GL_Compatibility-blue?logo=godotengine)
![Platform](https://img.shields.io/badge/Platform-Web%20%7C%20VR%20(Meta%20Quest)-brightgreen)
![Netlify](https://img.shields.io/badge/Deployment-Live%20on%20Netlify-success?logo=netlify)

**EcoAgua UNR** es una simulación interactiva en Realidad Virtual y WebGL desarrollada en **Godot Engine 4** que recrea la cuenca de un río de la llanura pampeana argentina. La experiencia combina modelado ambiental, shaders de agua personalizados e indicadores de degradación ecológica basados en reportes científicos de laboratorio (ICASFAS / UNR).

🌐 **Demostración en vivo en la Web**: [https://ecoagua-unr.netlify.app](https://ecoagua-unr.netlify.app)

---

## 🌟 Características Principales

* 💧 **Shader de Agua Personalizado (`watershader2.gdshader`)**:
  - Reflexión Fresnel en tiempo real con mapeo de cielo HDRI.
  - Absorción de profundidad, refracción en pantalla, desplazamiento de cáusticas animadas y espuma procedimental.
* 🌿 **Simulación por Zonas de Degradación Ecológica (`WaterManager.gd`)**:
  - Transición progresiva a lo largo de 4 zonas del río (desde aguas cristalinas hasta zonas con alta carga orgánica, microplásticos y turbidez).
* 🎨 **Renderizado y Atmósfera Optimizado**:
  - Mapeo de tonos **AgX** para preservar la fidelidad de color sin sobreexposición.
  - Iluminación ambiental basada en imágenes (**HDRI**) y terreno con mapeo triplanar.
* 🥽 **Soporte Multiplataforma**:
  - **Modo VR**: Integración con **Godot XR Tools** y soporte nativo para visores (Meta Quest / OpenXR).
  - **Modo Web / Flat**: Navegación libre con cámara interactiva (`FreeLookCamera.gd`) en cualquier navegador moderno.

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

## 🛠️ Requisitos e Instalación Local

1. **Godot Engine**: Descargar **Godot 4.3+** o **Godot 4.6** (Standard Edition).
2. Clonar el repositorio:
   ```bash
   git clone https://github.com/ticilicarzze/EcoAgua.git
   cd EcoAgua/EcoAgua
   ```
3. Abrir el proyecto en Godot Engine y ejecutar la escena principal (`scenes/main.tscn` o presionar `F5`).

---

## 🚀 Despliegue Automático a Netlify

El proyecto cuenta con un script de automatización para exportar el build WebGL y desplegarlo en producción con las cabeceras `SharedArrayBuffer` requeridas:

```bash
cd EcoAgua
./deploy.sh
```

---

## 📜 Créditos y Licencia

Desarrollado como proyecto de simulación ambiental e interactiva para la **Universidad Nacional de Rosario (UNR)**.

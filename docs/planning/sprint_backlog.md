# EcoAguaUNR - Technical Sprint Backlog

This document structures the technical tasks required to implement the "EcoAguaUNR" immersive VR experience in Godot 4, using the **Compatibility backend** targeting standalone VR (such as Meta Quest 2/3). 

---

## 1. Core Architecture & State Management

### Task 1.1: Implement Centralized State Manager (`WaterManager.gd`)
* **Description**: Create a centralized singleton/autoload script `WaterManager.gd` that tracks user progression along the river. It references the `progress_ratio` of the `UserCart` (`PathFollow3D`) and calculates environmental metrics representing the state of the Ludueña Stream.
* **Suggested Tags**: `[Dev]` `[Priority: High]`
* **Technical Details**:
  * Define thresholds for the 4 zones:
    * **Zone 1 (Baseline)**: $0.0 \le \text{ratio} < 0.25$
    * **Zone 2 (Agricultural)**: $0.25 \le \text{ratio} < 0.50$
    * **Zone 3 (Peri-urban)**: $0.50 \le \text{ratio} < 0.75$
    * **Zone 4 (Critical)**: $0.75 \le \text{ratio} \le 1.0$
  * Expose global reactive properties: `current_zone: int`, `water_quality_index: float`, `dissolved_oxygen: float`, `water_flow_speed: float`, and `turbidity_visibility: float`.
  * Emit signals: `zone_changed(new_zone: int)` and `metrics_updated(wqi: float, do: float)`.
* **Technical Acceptance Criteria**:
  1. Script successfully tracks `progress_ratio` of the main cart node.
  2. Transition signals are triggered only once per zone boundary crossing.
  3. Global variables return correct values matching the current zone specifications:
     * **Zone 1**: WQI = 90, DO = 8.0 mg/L, Flow Speed = 2.0 m/s, Visibility = 0.6m
     * **Zone 2**: WQI = 60, DO = 5.5 mg/L, Flow Speed = 1.2 m/s, Visibility = 0.4m
     * **Zone 3**: WQI = 30, DO = 2.0 mg/L, Flow Speed = 0.6 m/s, Visibility = 0.15m
     * **Zone 4**: WQI = 5, DO = 0.5 mg/L, Flow Speed = 0.1 m/s, Visibility = 0.0m

### Task 1.2: Smooth Parameter Interpolation Engine
* **Description**: Implement transition interpolation logic inside `WaterManager.gd` to prevent visual and auditory jumps when crossing zone thresholds, ensuring a comfortable VR experience.
* **Suggested Tags**: `[Dev]` `[Priority: Medium]`
* **Technical Details**:
  * Define a transition window (e.g., 5% of total path length before and after a zone boundary).
  * Use `clampf` and `lerp` or Godot `Tween` instances to smoothly blend values between adjacent zones.
* **Technical Acceptance Criteria**:
  1. Parameters like WQI, Dissolved Oxygen, and water flow speed interpolate linearly or via a smooth-step function over the transition windows.
  2. No frame-rate drops or stuttering are detected during tweening operations in VR.

---

## 2. Shaders & Visuals

### Task 2.1: Custom Water Shader for Compatibility Backend (`water_shader.gdshader`)
* **Description**: Develop a high-performance custom water shader tailored for the OpenGL ES 3.0 Compatibility backend.
* **Suggested Tags**: `[Dev]` `[Design]` `[Priority: High]`
* **Technical Details**:
  * Avoid heavy features like screen-space reflections (SSR) and dense vertex displacements.
  * Use dual-panning normal maps to simulate water surface ripples.
  * Expose shader parameters (uniforms) to control:
    * `flow_speed` and `flow_direction` (linked to `WaterManager.gd`'s current speed).
    * `albedo_color` (blending from natural light-brown to algae-green, turbid grey, and stagnant black).
    * `roughness` and `metallic` constants (Zone 4 will use high metallic/low roughness to simulate chemical sheen).
* **Technical Acceptance Criteria**:
  1. Water shader compiles successfully without errors under the Compatibility backend.
  2. Panning speed changes dynamically in response to `WaterManager.gd` updates.
  3. Color transitions match the visual profile of each zone without sharp visual seams.

### Task 2.2: Depth-Based Water Extinction (Turbidity)
* **Description**: Since Godot 4's Compatibility backend lacks support for standard volumetric fog, implement turbidity directly within the water shader using depth testing.
* **Suggested Tags**: `[Dev]` `[Priority: High]`
* **Technical Details**:
  * Enable screen and depth textures in the shader code (`hint_screen_texture`, `hint_depth_texture`).
  * Calculate the vertical distance between the water surface plane and the underlying terrain geometry using screen depth:
    $$\text{water\_depth} = \text{depth} - \text{SCREEN\_UV}$$
  * Apply an exponential extinction formula:
    $$\text{factor} = 1.0 - e^{-\text{water\_depth} \cdot \text{turbidity}}$$
  * Interpolate the water's base color with the background color based on this factor.
* **Technical Acceptance Criteria**:
  1. Water transparency fades with depth, rendering objects underwater invisible beyond the specified visibility limit per zone (e.g., visible down to 60cm in Zone 1, opaque immediately in Zone 4).
  2. The shader handles camera proximity smoothly without rendering glitches or screen-door artifacts.

### Task 2.3: Camera Submersion Environment Fog Workaround
* **Description**: Create a controller that detects when the VR headset/camera goes underwater and adjusts the global environment fog to simulate turbidity.
* **Suggested Tags**: `[Dev]` `[VR Testing]` `[Priority: Medium]`
* **Technical Details**:
  * Compare `XRCamera3D.global_position.y` with the Y-coordinate of the water mesh.
  * When underwater, toggle `Environment.fog_enabled = true` on the active `WorldEnvironment`.
  * Map the environment fog density and color to the current zone's water properties (e.g. dense grey-green fog in Zone 3, thick brown-black fog in Zone 4).
  * Activate a subtle screen-space distortion shader on a camera-attached QuadMesh to simulate water drops or refraction when emerging.
* **Technical Acceptance Criteria**:
  1. Underwater transition triggers accurately and instantaneously when the camera submerges.
  2. Environment fog changes values smoothly based on the current zone index.
  3. Transition does not trigger rendering artifacts (e.g., viewport clipping or skybox showing through).

---

## 3. VR HUD & User Interface

### Task 3.1: Reactive 3D VR Dashboard (Spatial UI)
* **Description**: Implement a floating 3D dashboard inside the User Cart using `Viewport2DIn3D` to display real-time sensor metrics.
* **Suggested Tags**: `[Interface & HUD]` `[Dev]` `[Priority: High]`
* **Technical Details**:
  * Place a physical panel mesh ahead of the passenger seat in `main.tscn`.
  * Render a 2D control node hierarchy into a `SubViewport` and project it onto the mesh.
  * The interface must show:
    * Current Zone name and safety advisory.
    * Real-time Water Quality Index (WQI) gauge.
    * Dissolved Oxygen (DO) indicator (mg/L).
  * Update indicators reactively by subscribing to `WaterManager.metrics_updated`.
* **Technical Acceptance Criteria**:
  1. HUD elements are perfectly legible from the player seat (appropriate font sizes and contrasting colors, optimized subviewport resolution).
  2. The panel moves statically with the cart, avoiding headset-locked projection (which causes motion sickness).
  3. Metrics update dynamically in response to cart travel.

### Task 3.2: Critical Evacuation Alert & Scenario Exit System
* **Description**: Implement the visual/auditory panic UI and exit sequence for Zone 4.
* **Suggested Tags**: `[Interface & HUD]` `[Dev]` `[Priority: High]`
* **Technical Details**:
  * Upon entering Zone 4, trigger a flashing hazard indicator on the HUD: *"PELIGRO: Niveles de Oxígeno Críticos - Evacuar Escenario"*.
  * Play a warning klaxon loop.
  * Initiate a 15-second countdown timer.
  * At 0 seconds, trigger a VR-safe black fade out (using a fade screen overlay) and gracefully exit to the main menu or close the application.
* **Technical Acceptance Criteria**:
  1. Evacuation sequence initiates immediately when `current_zone == 4`.
  2. Screen fade is completely black, blocking all visual tracking to prevent immersion breaking.
  3. The scene transitions to the main menu or terminates clean without crashing.

---

## 4. Spatial Audio System

### Task 4.1: Spatial Audio Manager & Dynamic Crossfader
* **Description**: Create an `AudioManager.gd` script to coordinate soundscape transitions along the stream.
* **Suggested Tags**: `[Dev]` `[Priority: Medium]`
* **Technical Details**:
  * Set up dedicated audio buses in Godot: `Master`, `Fauna`, `Industrial`, and `SFX`.
  * Instantiate two stereo background streams: one for nature ambient sounds (Zone 1-2) and one for industrial decay/drone (Zone 3-4).
  * Use tween logic to crossfade bus volumes using `AudioServer.set_bus_volume_db()` as the user advances.
* **Technical Acceptance Criteria**:
  1. Audio buses are properly routed.
  2. Ambient fauna sounds fade out completely, and industrial hums fade in as the cart approaches Zone 3.
  3. Transition is smooth, silent, and free of clicks or audibly discrete steps.

### Task 4.2: Positional Audio Emitters (3D Soundscapes)
* **Description**: Integrate positional `AudioStreamPlayer3D` nodes along the stream bank to ground the user in the environment.
* **Suggested Tags**: `[Content]` `[Priority: Medium]`
* **Technical Details**:
  * Place spatial audio emitters at key landmarks:
    * Birds/insects in Zone 1-2 trees.
    * Splashing rapids in Zone 1.
    * Gurgling agricultural pipes in Zone 2.
    * Sludgy slaughterhouse drains and metallic clangs in Zone 3.
    * Low, heavy machinery rumbles in Zone 4.
  * Set appropriate attenuation curves (linear or logarithmic) for all 3D sound nodes.
* **Technical Acceptance Criteria**:
  1. Sounds are directionally trackable through VR stereo headphones (HRTF rendering).
  2. Attenuation parameters prevent sounds from leaking abruptly into unrelated zones.

---

## 5. Environment & Content Integration

### Task 5.1: Baseline & Agricultural Scene Assembly (Zones 1 & 2)
* **Description**: Build the environmental assets and layout for the first half of the experience.
* **Suggested Tags**: `[Content]` `[Design]` `[Priority: Medium]`
* **Technical Details**:
  * Zone 1: Set up dense native foliage (willows, reeds) and place fauna nodes (animated birds, jumping fish). Use clear, sandy-brown water colors.
  * Zone 2: Spawn green algal patches (eutrophication) on the water surface. Replace dense forest with crop fields, rural fences, and livestock models.
  * Use `MultiMeshInstance3D` for grass and algae to optimize render performance.
* **Technical Acceptance Criteria**:
  1. Visual progression clearly conveys the transition from a pristine river to agricultural run-off.
  2. Foliage and algal patches use GPU-instanced multi-meshes, keeping draw calls low.

### Task 5.2: Agro-Industrial & Chemical Scene Assembly (Zones 3 & 4)
* **Description**: Set up the environment assets for the heavily degraded second half.
* **Suggested Tags**: `[Content]` `[Design]` `[Priority: High]`
* **Technical Details**:
  * Zone 3: Place floating garbage (plastic bottles, barrels, tires) trapped on shores. Set up slaughterhouse drainage pipes emitting red/brown effluents with bubble particle streams.
  * Zone 4: Replace all living flora with dead trees, scorched earth, and industrial ruins. The water surface becomes stagnant and dark.
* **Technical Acceptance Criteria**:
  1. Debris is clustered naturally along shorelines.
  2. The overall scene conveys severe environmental neglect.
  3. Textures and geometry budgets are strictly checked to avoid exceeding VR limits.

---

## 6. VR Testing & Performance Optimization

### Task 6.1: Standalone VR Rendering Optimization (Compatibility Backend)
* **Description**: Optimize performance parameters to meet standalone VR hardware limitations.
* **Suggested Tags**: `[VR Testing]` `[Dev]` `[Priority: High]`
* **Technical Details**:
  * Bake lighting for static meshes; disable real-time shadows for small objects.
  * Run "Overdraw" debug draw mode to identify and limit transparent materials.
  * Merge static props (e.g., rocks, dead trees) into combined meshes.
  * Use alpha-testing/clip threshold (Alpha Scissors) for leaves and trash instead of alpha-blending.
* **Technical Acceptance Criteria**:
  1. Draw calls remain below **150** per frame on target hardware.
  2. Vertex count does not exceed **150,000** visible polygons.
  3. No significant performance hits are caused by transparency overdraw.

### Task 6.2: Framerate Profiling & Motion Sickness Prevention
* **Description**: Profile performance on a physical standalone headset to ensure stable framerates during heavy particle/fog zones.
* **Suggested Tags**: `[VR Testing]` `[Priority: High]`
* **Technical Details**:
  * Test target framerate (e.g., Quest 2: stable 72 FPS, Quest 3: stable 90 FPS).
  * Use Godot's built-in Profiler and Quest Developer Hub (if applicable) to monitor CPU/GPU frame times.
  * Tune particle systems dynamically (e.g., reduce effluent bubbles or industrial fumes) if framerate dips.
* **Technical Acceptance Criteria**:
  1. Game runs at target FPS (minimum 72 FPS) consistently across all 4 zones.
  2. Frame times remain below **13.8 ms** (for 72 Hz) or **11.1 ms** (for 90 Hz).
  3. Headset tracking remains smooth, preventing VR-induced motion sickness.

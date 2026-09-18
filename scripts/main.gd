@tool
extends Node3D

@onready var cart = $RiverPath/UserCart
@export var speed: float = 2.97           # m/s — 294m activos / 99s de rodaje bajo el agua
@export var surface_height_offset: float = 3.5  # Altura vertical de la cámara al emerger

# =========================================================
# PALETA VISUAL POR ZONA (EcoAgua / Amaya 2018)
# El agua SIEMPRE es marrón pampeana, nunca azul.
# Índice 0 sin usar — base 1.
# =========================================================
# Paleta de colores: degradé marrón pampeano, de claro a oscuro.
# Zona 4 usa marrón oscuro (no negro) — densidad alta acorta el campo, no blanquea.
const ZONE_UW_FOG_COLOR: Array[Color] = [
	Color(0.00, 0.00, 0.00, 1.0),
	Color(0.38, 0.26, 0.13, 1.0), # Z1: marrón oscuro pampeano / barro claro
	Color(0.30, 0.19, 0.09, 1.0), # Z2: marrón sedimento oscuro
	Color(0.22, 0.13, 0.05, 1.0), # Z3: marrón fango
	Color(0.15, 0.08, 0.03, 1.0), # Z4: marrón muy oscuro / lodo cargado
]

const ZONE_UW_AMBIENT_COLOR: Array[Color] = [
	Color(0.00, 0.00, 0.00, 1.0),
	Color(0.62, 0.46, 0.28, 1.0), # Z1: iluminación marrón cálida para objetos
	Color(0.50, 0.34, 0.18, 1.0), # Z2
	Color(0.38, 0.22, 0.09, 1.0), # Z3
	Color(0.26, 0.13, 0.05, 1.0), # Z4
]
const ZONE_UW_AMBIENT_ENERGY: Array[float] = [
	0.0,
	0.90, # Z1: reducido para no saturar el canal rojo y mantener el tono marrón visible
	0.85, # Z2: similar — el color marrón cálido domina sin blanquearse
	0.95, # Z3: iluminación equilibrada
	0.75, # Z4: ambientalmente sombría pero suficiente para distinguir modelos
]
const ZONE_UW_BG_COLOR: Array[Color] = [
	Color(0.00, 0.00, 0.00, 1.0),
	Color(0.38, 0.26, 0.13, 1.0), # Z1
	Color(0.30, 0.19, 0.09, 1.0), # Z2
	Color(0.22, 0.13, 0.05, 1.0), # Z3
	Color(0.15, 0.08, 0.03, 1.0), # Z4 — fondo lodo muy oscuro
]

# Densidad de neblina WorldEnvironment subacuática por zona
# Calibrada para mostrar la degradación progresiva manteniendo visible la flora, fauna y el lecho.
const ZONE_UW_FOG_DENSITY: Array[float] = [
	0.0,
	0.018, # Z1: cristalina / muy clara (~160m visibilidad)
	0.032, # Z2: leve bruma / transición (~90m visibilidad)
	0.050, # Z3: turbia moderada / flora y fauna claramente visibles (~60m visibilidad)
	0.075, # Z4: degradada y cargada / visibilidad de 15-20m garantizada
]

# =========================================================
# MÁQUINA DE ESTADOS NARRATIVA — Guión EcoAgua
# Cada estado corresponde a una fase exacta del guión.
# =========================================================
enum NarrativeState {
	WAITING_START,      # Pantalla de inicio — botón "Sumergirse"
	Z1_SURFACE_INTRO,   # Z1: Afuera, pájaros/agua (2-3 s), luego Arroyo (15 s)
	Z1_DIVING,          # Z1: Inmersión (1 s)
	Z1_CARD,            # Z1: Cartel grande parámetros (3 s)
	Z1_UNDERWATER,      # Z1: Rodaje bajo el agua — Arroyo 7 s + Intérprete 12 s = 19 s
	Z2_SURFACE,         # Z2: Emersión cabeza, ambiente (2-3 s) + Arroyo (10 s) = 13 s
	Z2_DIVING,          # Z2: Inmersión (1 s)
	Z2_CARD,            # Z2: Cartel grande parámetros (3 s)
	Z2_UNDERWATER,      # Z2: Rodaje bajo el agua — Intérprete 17 s + 10 s = 27 s
	Z3_SURFACE,         # Z3: Emersión cabeza, ambiente (2-3 s) + Arroyo (15 s) = 18 s
	Z3_DIVING,          # Z3: Inmersión (1 s)
	Z3_CARD,            # Z3: Cartel grande parámetros (3 s)
	Z3_UNDERWATER,      # Z3: Rodaje bajo el agua — Intérprete 20 s + 8 s = 28 s
	Z4_SURFACE,         # Z4: Emersión cabeza, silencio (2-3 s) + Arroyo (20 s) = 23 s
	Z4_DIVING,          # Z4: Inmersión (1 s)
	Z4_CARD,            # Z4: Cartel grande parámetros (3 s)
	Z4_UNDERWATER,      # Z4: Rodaje bajo el agua — Intérprete (25 s)
	Z4_EMERGE,          # Z4: Saca cabeza, sale a tierra (2 s)
	Z4_CLOSING,         # Z4: Intérprete cierre (9.75 s) + Arroyo cierre (6.75 s) = 16.5 s
	CREDITS,            # Créditos (8 s)
	DONE
}

# Duraciones exactas de cada estado (en segundos), extraídas del guión
const NARRATIVE_DURATIONS: Dictionary = {
	NarrativeState.WAITING_START:    0.0,   # Sin timer — espera interacción del usuario
	NarrativeState.Z1_SURFACE_INTRO: 18.0,  # 3 s ambiente + 15 s locución Arroyo
	NarrativeState.Z1_DIVING:        1.0,
	NarrativeState.Z1_CARD:          5.0,
	NarrativeState.Z1_UNDERWATER:   19.0,   # 7 s Arroyo + 12 s Intérprete
	NarrativeState.Z2_SURFACE:       13.0,  # 3 s ambiente + 10 s locución Arroyo
	NarrativeState.Z2_DIVING:        1.0,
	NarrativeState.Z2_CARD:          5.0,
	NarrativeState.Z2_UNDERWATER:   27.0,   # 17 s Intérprete + 10 s Intérprete
	NarrativeState.Z3_SURFACE:       18.0,  # 3 s ambiente + 15 s locución Arroyo
	NarrativeState.Z3_DIVING:        1.0,
	NarrativeState.Z3_CARD:          5.0,
	NarrativeState.Z3_UNDERWATER:   28.0,   # 20 s Intérprete + 8 s Intérprete
	NarrativeState.Z4_SURFACE:       23.0,  # 3 s ambiente + 20 s locución Arroyo
	NarrativeState.Z4_DIVING:        1.0,
	NarrativeState.Z4_CARD:          5.0,
	NarrativeState.Z4_UNDERWATER:   25.0,   # 25 s Intérprete
	NarrativeState.Z4_EMERGE:        2.0,
	NarrativeState.Z4_CLOSING:      16.5,   # 9.75 s Intérprete + 6.75 s Arroyo
	NarrativeState.CREDITS:          8.0,
	NarrativeState.DONE:             0.0,
}

# Zona activa para cada estado (usada para actualizar WaterManager y visuales)
const NARRATIVE_ZONE: Dictionary = {
	NarrativeState.WAITING_START:   1,
	NarrativeState.Z1_SURFACE_INTRO:1,
	NarrativeState.Z1_DIVING:       1,
	NarrativeState.Z1_CARD:         1,
	NarrativeState.Z1_UNDERWATER:   1,
	NarrativeState.Z2_SURFACE:      2,
	NarrativeState.Z2_DIVING:       2,
	NarrativeState.Z2_CARD:         2,
	NarrativeState.Z2_UNDERWATER:   2,
	NarrativeState.Z3_SURFACE:      3,
	NarrativeState.Z3_DIVING:       3,
	NarrativeState.Z3_CARD:         3,
	NarrativeState.Z3_UNDERWATER:   3,
	NarrativeState.Z4_SURFACE:      4,
	NarrativeState.Z4_DIVING:       4,
	NarrativeState.Z4_CARD:         4,
	NarrativeState.Z4_UNDERWATER:   4,
	NarrativeState.Z4_EMERGE:       4,
	NarrativeState.Z4_CLOSING:      4,
	NarrativeState.CREDITS:         4,
	NarrativeState.DONE:            4,
}

# Secuencia lineal de estados (para avanzar con next_state())
const NARRATIVE_SEQUENCE: Array = [
	NarrativeState.WAITING_START,
	NarrativeState.Z1_SURFACE_INTRO,
	NarrativeState.Z1_DIVING,
	NarrativeState.Z1_CARD,
	NarrativeState.Z1_UNDERWATER,
	NarrativeState.Z2_SURFACE,
	NarrativeState.Z2_DIVING,
	NarrativeState.Z2_CARD,
	NarrativeState.Z2_UNDERWATER,
	NarrativeState.Z3_SURFACE,
	NarrativeState.Z3_DIVING,
	NarrativeState.Z3_CARD,
	NarrativeState.Z3_UNDERWATER,
	NarrativeState.Z4_SURFACE,
	NarrativeState.Z4_DIVING,
	NarrativeState.Z4_CARD,
	NarrativeState.Z4_UNDERWATER,
	NarrativeState.Z4_EMERGE,
	NarrativeState.Z4_CLOSING,
	NarrativeState.CREDITS,
	NarrativeState.DONE,
]

# Estado interno de la máquina narrativa
var _narrative_state: NarrativeState = NarrativeState.WAITING_START
var _state_timer: float = 0.0

# Referencia al HUDController para comunicar fases narrativas
var _hud: Node = null

# =========================================================
# CONSTANTES VISUALES DE SUPERFICIE / AGUA
# =========================================================
const SF_AMBIENT_ENERGY: float = 1.2
const SF_AMBIENT_COLOR: Color = Color(0.72, 0.72, 0.68, 1.0)
const WATER_SURFACE_Y: float = 0.25   # Umbral: coincide con la cresta de las olas del shader
const LERP_SPEED: float = 2.5

# =========================================================
# ESTADO VISUAL INTERPOLADO
# =========================================================
var _current_ambient: float = 1.1
var _current_ambient_col: Color = Color(0.62, 0.50, 0.34, 1.0)
var _current_fog_density: float = 0.035
var _current_fog_col: Color = Color(0.58, 0.46, 0.32, 1.0)
var _is_underwater: bool = false    # Arranca en superficie (estado WAITING_START)
var _was_underwater: bool = false
var _base_fov: float = 75.0
var _current_fov: float = 75.0
var _current_v_offset: float = 0.0

# =========================================================
# CONTROL DE CÁMARA LIBRE (FreeLook)
# =========================================================
var _fl_yaw: float = 0.0
var _fl_pitch: float = 0.0
var _fl_dragging: bool = false
const FL_MOUSE_SENS: float = 0.003
const FL_KEY_SPEED: float = 1.8
const FL_PITCH_LIMIT: float = 80.0
var _fl_camera: Camera3D = null

# =========================================================
# REFERENCIAS A OBJETOS EN TIEMPO DE EJECUCIÓN
# =========================================================
var _particles: GPUParticles3D = null
var _particle_nodes: Array[GPUParticles3D] = []
var _particle_proc: ParticleProcessMaterial = null
var _particle_mat: StandardMaterial3D = null
var _water_mat: ShaderMaterial = null # ShaderMaterial del nodo TopWater
var _water_mats: Array[ShaderMaterial] = [] # alias array para _update_water_zone

func _get_active_camera_y() -> float:
	var vp_cam := get_viewport().get_camera_3d()
	if vp_cam:
		return vp_cam.global_position.y
	if has_node("RiverPath/UserCart/XROrigin3D/XRCamera3D"):
		return $RiverPath/UserCart/XROrigin3D/XRCamera3D.global_position.y
	return 0.0


# =========================================================
# _ready
# =========================================================
func _ready() -> void:
	if has_node("DirectionalLight3D"):
		# Afternoon sun parameters (la rotación se ajusta libremente desde el Inspector o el Gizmo)
		$DirectionalLight3D.light_color = Color(1.0, 0.96, 0.82) # warm yellow-white
		$DirectionalLight3D.light_energy = 0.6
		$DirectionalLight3D.light_specular = 0.05
		$DirectionalLight3D.shadow_enabled = false

	var env = $WorldEnvironment.environment
	if env:
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
		env.background_mode = Environment.BG_SKY
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = ZONE_UW_AMBIENT_COLOR[1]
		env.ambient_light_energy = ZONE_UW_AMBIENT_ENERGY[1]
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC # Filmic: Totalmente compatible con WebGL2 / GL Compatibility
		env.glow_enabled = false
		env.background_energy_multiplier = 0.7 # Ajuste fino de brillo del cielo

	_alinear_mvp()
	_build_environment()
	_setup_foliage_shaders()
	_create_surface_checkpoint_visualizers()

	if has_node("FlatCamera"):
		_base_fov = $FlatCamera.fov
		_current_fov = _base_fov


	if Engine.is_editor_hint():
		return

	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface:
		if xr_interface.is_initialized() or xr_interface.initialize():
			get_viewport().use_xr = true
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			print("XR Mode: Visor OpenXR detectado e inicializado con éxito (Meta Quest).")
			# Activar HUD VR — desactivar HUD de pantalla plana
			if has_node("CanvasLayer"):    $CanvasLayer.visible   = false
			if has_node("CanvasLayerVR"): $CanvasLayerVR.visible  = true
		else:
			push_error("XR Mode: OpenXR detectado pero falló al inicializarse.")
			_setup_fallback_mode()
	else:
		_setup_fallback_mode()

	WaterManager.zone_changed.connect(_on_zone_changed)
	WaterManager.metrics_updated.connect(_on_metrics_updated)
	_setup_camera_fx()
	_setup_aquatic_fauna()

	# Posicionar el carrito en Z=0 y ARRIBA del agua (estado WAITING_START)
	cart.progress = 200.0
	cart.v_offset = surface_height_offset  # Empieza en superficie
	_current_v_offset = surface_height_offset
	WaterManager.progress_ratio = 0.0

	# Buscar referencia al HUD para comunicar eventos narrativos
	if has_node("CanvasLayer"):
		_hud = $CanvasLayer
	elif has_node("CanvasLayerVR"):
		_hud = $CanvasLayerVR

	# Entrar al primer estado narrativo
	_enter_narrative_state(NarrativeState.WAITING_START)
	print("Narrativa: estado WAITING_START — esperando botón 'Sumergirse'. Velocidad de riel: %.2f m/s" % speed)


# =========================================================
# _setup_fallback_mode — Pantalla Plana fallback
# =========================================================
func _setup_fallback_mode() -> void:
	print("XR Mode: Modo Pantalla / Fallback (FreeLook) activado.")
	_setup_free_look()

# =========================================================
# _setup_free_look — Control de cámara para modo web/flat
# =========================================================
func _setup_free_look() -> void:
	if not has_node("FlatCamera"):
		push_warning("FreeLook: No se encontró FlatCamera en la raíz de la escena.")
		return
	_fl_camera = $FlatCamera
	_fl_yaw = 0.0
	_fl_pitch = 0.0
	print("FreeLook integrado: mouse (izq/der) + WASD + flechas.")

# =========================================================
# _setup_camera_fx — Partículas subacuáticas
# =========================================================
func _setup_camera_fx() -> void:
	# --- Partículas de sedimento submerso ---
	var sphere := SphereMesh.new()
	sphere.radius = 0.012
	sphere.height = 0.024

	_particle_mat = StandardMaterial3D.new()
	_particle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_particle_mat.albedo_color = Color(0.72, 0.56, 0.36, 0.55)
	_particle_mat.roughness = 0.9
	_particle_mat.metallic = 0.0
	sphere.material = _particle_mat

	_particle_proc = ParticleProcessMaterial.new()
	_particle_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_particle_proc.emission_box_extents = Vector3(2.5, 1.2, 2.5)
	_particle_proc.gravity = Vector3(0.0, 0.08, 0.0)
	_particle_proc.initial_velocity_min = 0.02
	_particle_proc.initial_velocity_max = 0.08
	_particle_proc.spread = 20.0
	_particle_proc.lifetime_randomness = 0.4

	# Adjuntar efectos a ambas cámaras (XRCamera3D y FlatCamera)
	var target_cameras: Array[Node] = []
	if has_node("RiverPath/UserCart/XROrigin3D/XRCamera3D"):
		target_cameras.append($RiverPath/UserCart/XROrigin3D/XRCamera3D)
	if has_node("FlatCamera"):
		target_cameras.append($FlatCamera)

	_particle_nodes.clear()

	for cam in target_cameras:
		# Partículas
		var particles := GPUParticles3D.new()
		particles.name = "UnderwaterParticles"
		particles.amount = 80
		particles.lifetime = 5.0
		particles.process_material = _particle_proc
		particles.draw_pass_1 = sphere
		particles.emitting = false # Empieza desactivado hasta estar en el agua
		particles.visible = false
		particles.local_coords = false
		cam.add_child(particles)
		_particle_nodes.append(particles)

	print("Camera FX: partículas subacuáticas configuradas en las cámaras.")


# =========================================================
# _enter_tree

# =========================================================
# _setup_aquatic_fauna — Asigna automáticamente nado y animación a todos los peces según especie
# =========================================================
func _setup_aquatic_fauna() -> void:
	var mojarra_script = preload("res://scripts/MojarraAnimada.gd")
	var bagre_script = preload("res://scripts/BagreAnimado.gd")
	var dientudo_script = preload("res://scripts/DientudoAnimado.gd")

	_apply_fish_scripts_recursive(self, mojarra_script, bagre_script, dientudo_script)

func _apply_fish_scripts_recursive(node: Node, mojarra_script: Script, bagre_script: Script, dientudo_script: Script) -> void:
	if node is PezAnimado:
		return

	var node_name := node.name.to_lower()
	var is_container := (node_name == "mojarras" or node_name == "bagres" or node_name == "dientudos" or node_name == "faunaacuatica" or node_name.contains("banco"))

	if node is Node3D and node != self and not is_container:
		var target_script: Script = null
		if node_name.contains("bagre"):
			target_script = bagre_script
		elif node_name.contains("dientudo"):
			target_script = dientudo_script
		elif node_name.contains("mojarra"):
			target_script = mojarra_script

		if target_script != null:
			if node.get_script() != target_script:
				node.set_script(target_script)
				if node.has_method("_ready"):
					node._ready()
			return

	for child in node.get_children():
		_apply_fish_scripts_recursive(child, mojarra_script, bagre_script, dientudo_script)

# =========================================================
# _setup_foliage_shaders — Aplica shader de vegetación y desactiva sombras en plantas de superficie
# =========================================================
func _setup_foliage_shaders() -> void:
	var foliage_shader: Shader = load("res://resources/shaders/foliage.gdshader")
	if not foliage_shader:
		push_error("Foliage: No se pudo cargar res://resources/shaders/foliage.gdshader")
		return

	var plant_categories: Array[String] = ["Ceibos", "Cortaderas", "Gramineas", "Juncos", "Pastizales", "Totoras", "Sauces"]
	var total_plants: int = 0

	for zone_idx in range(1, 5):
		var zone_vege := get_node_or_null("Zona%d/VegetacionRiberena" % zone_idx)
		if not zone_vege:
			continue
		
		# Limpiar explícitamente Piedras para que conserven sus sombras y material PBR original
		var piedras_node := zone_vege.get_node_or_null("Piedras")
		if piedras_node:
			_clear_material_override_recursive(piedras_node)
		
		# Aplicar shader ÚNICAMENTE a las categorías de plantas
		for cat_name in plant_categories:
			var cat_node := zone_vege.get_node_or_null(cat_name)
			if cat_node:
				_apply_foliage_shader_recursive(cat_node, foliage_shader)
				total_plants += 1

	print("Foliage Shader: Aplicado correctamente a las plantas (excluyendo rocas).")

func _clear_material_override_recursive(node: Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if node is MeshInstance3D:
			(node as MeshInstance3D).material_override = null
	for child in node.get_children():
		_clear_material_override_recursive(child)

func _apply_foliage_shader_recursive(node: Node, shader_res: Shader) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
		if node is MeshInstance3D:
			var mesh_inst := node as MeshInstance3D
			var orig_mat: Material = mesh_inst.get_active_material(0)
			var tex: Texture2D = null
			
			if orig_mat is StandardMaterial3D:
				tex = (orig_mat as StandardMaterial3D).albedo_texture
			elif orig_mat is ShaderMaterial:
				tex = (orig_mat as ShaderMaterial).get_shader_parameter("texture_albedo")
			
			if tex:
				var new_shader_mat := ShaderMaterial.new()
				new_shader_mat.shader = shader_res
				new_shader_mat.set_shader_parameter("texture_albedo", tex)
				new_shader_mat.set_shader_parameter("alpha_scissor_threshold", 0.3)
				new_shader_mat.set_shader_parameter("transmission_strength", 0.65)
				new_shader_mat.set_shader_parameter("normal_up_blend", 0.75)
				mesh_inst.material_override = new_shader_mat
	
	for child in node.get_children():
		_apply_foliage_shader_recursive(child, shader_res)


# =========================================================
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		await get_tree().process_frame
		if has_node("RiverPath"):
			_alinear_mvp()
			_update_water_zone(1)
			_setup_foliage_shaders()
			_create_surface_checkpoint_visualizers()

# =========================================================
# _create_surface_checkpoint_visualizers — Marcadores 3D flotantes en el editor
# Muestra los puntos exactos (Z y altura) donde la cámara emerge a la superficie.
# =========================================================
func _create_surface_checkpoint_visualizers() -> void:
	var container_name := "SurfaceCheckpointsVisualizer"
	var existing = get_node_or_null(container_name)
	if existing:
		existing.queue_free()

	# Solo se muestran mientras se trabaja en el Editor 3D. Al ejecutar el juego, no existen.
	if not Engine.is_editor_hint():
		return

	var container := Node3D.new()
	container.name = container_name
	add_child(container)

	var curve: Curve3D = null
	if has_node("RiverPath"):
		curve = $RiverPath.curve

	if not curve:
		return

	var p1: float = 200.0
	var p2: float = p1 + (19.0 * 2.97) # Final Z1_UNDERWATER
	var p3: float = p2 + (27.0 * 2.97) # Final Z2_UNDERWATER
	var p4: float = p3 + (28.0 * 2.97) # Final Z3_UNDERWATER

	var checkpoints_info: Array[Dictionary] = [
		{"progress": p2, "name": "Zona 2 (Transición)", "color": Color(0.2, 0.85, 1.0)},
		{"progress": p3, "name": "Zona 3 (Turbia)", "color": Color(1.0, 0.85, 0.2)},
		{"progress": p4, "name": "Zona 4 (Degradada)", "color": Color(1.0, 0.4, 0.3)}
	]

	for item in checkpoints_info:
		var prog: float = item["progress"]
		var best_pt: Vector3 = curve.sample_baked(prog)

		# 1. Label3D flotante visible en el viewport 3D del editor
		var label := Label3D.new()
		label.text = "📍 EMERSIÓN %s" % [item["name"]]
		label.position = Vector3(best_pt.x, 3.8, best_pt.z)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 46
		label.outline_size = 12
		label.modulate = item["color"]
		label.no_depth_test = true
		container.add_child(label)

		# 2. Anillo translúcido en la superficie del agua (Y=0.25)
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 2.5
		ring_mesh.bottom_radius = 2.5
		ring_mesh.height = 0.05

		var ring_mat := StandardMaterial3D.new()
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var col: Color = item["color"]
		col.a = 0.5
		ring_mat.albedo_color = col
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mesh.material = ring_mat

		var ring_inst := MeshInstance3D.new()
		ring_inst.mesh = ring_mesh
		ring_inst.position = Vector3(best_pt.x, 0.25, best_pt.z)
		container.add_child(ring_inst)

	print("Surface Checkpoints: Marcadores de emersión 3D agregados en el editor.")

# =========================================================
# _alinear_mvp
# =========================================================
func _alinear_mvp() -> void:
	var curve = $RiverPath.curve
	if curve:
		curve.clear_points()
		# Ruta con meandros suaves en X para dar apariencia de río natural pampeano.
		# Los puntos intermedios oscilan ±6 m en X con curvas Bézier suaves.
		# La emersión a la superficie se maneja mediante v_offset en PathFollow3D.
		# Y=-1.25: cámara a media columna de agua (lecho Ludueña Y=-2.5, superficie Y=0)
		# Canal Ludueña: 18m de base, 2.5m de profundidad, talud 1:1
		var river_points: Array[Vector3] = [
			Vector3(0.0, -1.25, 200.0), # cola trasera
			Vector3(3.0, -1.25, 140.0), # meandro suave
			Vector3(-4.0, -1.25, 80.0),
			Vector3(5.0, -1.25, 20.0),
			Vector3(0.0, -1.25, 0.0), # inicio activo
			Vector3(-5.0, -1.25, -60.0),
			Vector3(4.0, -1.25, -120.0),
			Vector3(-3.0, -1.25, -185.0),
			Vector3(5.0, -1.25, -250.0),
			Vector3(-2.0, -1.25, -294.0), # final activo
			Vector3(3.0, -1.25, -380.0),
			Vector3(0.0, -1.25, -494.0), # extensión visual frontal
		]
		for pt in river_points:
			# Calcular tangentes suaves para Bézier (escala 0.4 del intervalo promedio)
			curve.add_point(pt)
		# Ajustar tangentes para que las curvas sean suaves (not angular)
		for i in range(1, curve.point_count - 1):
			var prev: Vector3 = curve.get_point_position(i - 1)
			var next: Vector3 = curve.get_point_position(i + 1)
			var tangent: Vector3 = (next - prev).normalized() * 18.0
			curve.set_point_in(i, -tangent)
			curve.set_point_out(i, tangent)
		# Saltamos la cola trasera: la cámara empieza en Z=0 (200 m desde el inicio de la curva).
		cart.progress = 200.0

# =========================================================
# _build_environment
# =========================================================
func _build_environment() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# --- Valle continuo (CSGPolygon3D a lo largo del RiverPath) ---
	# Reemplaza el suelo plano y las barrancas de cajas primitivas.
	# El perfil transversal se define en _build_valley_terrain().
	var valley_node := _build_valley_terrain()

	print("Valley: CSGPolygon3D con textura de suelo pampeano creado.")

	# --- Cielo (Preserva el HDRI del Inspector si fue configurado) ---
	var env: Environment = $WorldEnvironment.environment
	if env:
		if env.sky == null:
			var sky_mat := ProceduralSkyMaterial.new()
			sky_mat.sky_top_color = Color(0.28, 0.45, 0.68, 1.0) # azul tarde desaturado
			sky_mat.sky_horizon_color = Color(0.80, 0.65, 0.48, 1.0) # crema / naranja horizonte
			sky_mat.sky_curve = 0.12
			sky_mat.ground_bottom_color = Color(0.10, 0.07, 0.03, 1.0) # tierra oscura (no blanco)
			sky_mat.ground_horizon_color = Color(0.48, 0.36, 0.22, 1.0) # marrón pampeano abajo
			sky_mat.ground_curve = 0.10
			sky_mat.sun_angle_max = 30.0

			var sky := Sky.new()
			sky.sky_material = sky_mat
			env.sky = sky
			print("Sky: cielo procedural de respaldo creado.")
		else:
			print("Sky: HDRI / Cielo del Inspector detectado y preservado.")

	# ─── Water: superficie del agua sobre el río completo ─────────────
	# $Water es el MeshInstance3D creado en la escena (80×420 m, Y=0).
	# Le aplicamos watershader2.gdshader en runtime.
	_water_mats.clear()
	var water_node := get_node_or_null("Water") as MeshInstance3D
	if water_node == null:
		push_error("Water: no se encontró el nodo $Water en la escena.")
	else:
		# Plano de agua extendido: cubre desde Z=+200 (cola trasera) hasta Z=-494 (cierre frontal).
		# Largo total = 694 m, centro en Z = (200 + -494) / 2 = -147.
		water_node.position = Vector3(0.0, 0.0, -147.0)
		water_node.rotation = Vector3.ZERO
		water_node.scale = Vector3.ONE
		water_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# Malla PlaneMesh de 80×694 m con 300×480 subdivisiones
		var plane := PlaneMesh.new()
		plane.size = Vector2(80.0, 694.0)
		plane.subdivide_width = 300
		plane.subdivide_depth = 480
		water_node.mesh = plane

		# Cargar ShaderMaterial con watershader2.gdshader si no lo tiene asignado
		if water_node.material_override is ShaderMaterial:
			_water_mat = water_node.material_override as ShaderMaterial
		else:
			var shader_res: Shader = load("res://resources/shaders/watershader2.gdshader")
			if shader_res:
				_water_mat = ShaderMaterial.new()
				_water_mat.shader = shader_res
				water_node.material_override = _water_mat

		if _water_mat:
			_water_mats = [_water_mat]
			_update_water_zone(1)
			print("Water: watershader2.gdshader aplicado y posicionado correctamente (80×820 m).")

	print("Environment: listo.")


# =========================================================
# _build_valley_terrain — CSGPolygon3D valley cross-section
# =========================================================
# Genera el terreno continuo del valle extrusionando un polígono 2D
# a lo largo del RiverPath.
#
# Perfil transversal (mirando hacia abajo del río, eje X = ancho, Y = altura):
#
#   -55     -18    -9.5  -8      8   9.5     18       55    ← X (m)
#    ●────────●                              ●────────●      ← Llanura (Y= 2.0)
#              \                            /
#               ●──────────────────────────●               ← Barranca base (Y=-1.0)
#                  ●──────────────────────●                ← Lecho del río (Y=-1.5)
#
# Se cierra en Y=-6.0 para crear un sólido opaco.
# =========================================================
func _build_valley_terrain() -> CSGPolygon3D:
	# ---- Polygon cross-section — Arroyo Ludueña (datos reales) ----
	# Canal canalizado: base 18 m de ancho, profundidad 2.5 m, taludes 1:1.
	# Superficie del agua: Y=0  |  Lecho: Y=-2.5  |  Cámara: Y=-1.25
	# Talud 1:1: por cada 1m de profundidad → 1m horizontal.
	#   Cima del talud izq: X = -9 - 2.5 = -11.5, Y=0
	#   Sobre el talud hay una llanura suave hasta el borde del encuadre.
	#
	#  -55  -35  -25  -16  -11.5   -9          9   11.5  16   25   35   55  ← X (m)
	#   ●────●────●────●                              ●────●────●────●        ← Llanura (Y≈2.0)
	#                   \                            /
	#                    ● (Y=0) talud 1:1          ● (Y=0)
	#                     \                        /
	#                      ●──────────────────────●                           ← Lecho (Y=-2.5, 18m base)
	#
	# X = river width axis, Y = vertical elevation.
	var profile := PackedVector2Array([
		# Llanura amplia izquierda (planicie pampeana) — más alta y pronunciada
		Vector2(-100.0, 3.0), # borde exterior lejano
		Vector2(-35.0, 3.0),
		Vector2(-25.0, 3.0),
		Vector2(-16.0, 2.5), # inicio descenso suave hacia el canal
		# Cima del talud 1:1 al nivel del agua (Y=0)
		Vector2(-11.5, 0.0), # borde superior del talud izq. (agua surface)
		# Talud 1:1 izquierdo: -2.5m en 2.5m horizontal
		Vector2(-9.0, -2.5), # borde izquierdo del lecho
		# Lecho subdividido: 7 puntos intermedios para vertex displacement
		Vector2(-6.75, -2.5),
		Vector2(-4.5, -2.5),
		Vector2(-2.25, -2.5),
		Vector2(0.0, -2.5), # centro del lecho
		Vector2(2.25, -2.5),
		Vector2(4.5, -2.5),
		Vector2(6.75, -2.5),
		Vector2(9.0, -2.5), # borde derecho del lecho
		# Talud 1:1 derecho (espejo)
		Vector2(11.5, 0.0), # borde superior del talud der.
		Vector2(16.0, 2.5), # suave transición a llanura
		Vector2(25.0, 3.0),
		Vector2(35.0, 3.0),
		Vector2(100.0, 3.0), # borde exterior lejano
		# Cierra el sólido bajo tierra
		Vector2(100.0, -8.0),
		Vector2(-100.0, -8.0),
	])

	# ---- Material: ShaderMaterial multi-zona con transición gradual entre suelos ----
	# terrain_zones.gdshader mezcla 4 texturas según WORLD_POSITION.z con smoothstep.
	# Zona1 (Z=0→-70): sandy gravel | Zona2 (Z=-70→-140): forest ground
	# Zona3 (Z=-140→-210): brown mud | Zona4 (Z=-210→-294): mismo que Zona3
	# Transición gradual de ±12 m en los bordes de zona (invisible al usuario).
	var terrain_shader: Shader = load("res://resources/shaders/terrain_zones.gdshader")
	var terrain_mat := ShaderMaterial.new()
	terrain_mat.shader = terrain_shader

	# Texturas de suelo por zona (triplanar con anti-tiling en todas las zonas)
	var tex1: Texture2D = load("res://assets/models/Suelo_Zona1_sandy_gravel_02_diff_2k.jpg")
	var tex2: Texture2D = load("res://assets/models/Suelo_Zona2_forest_ground_06_diff_2k.jpg")
	var tex3: Texture2D = load("res://assets/models/Suelo_Zona3_brown_mud_03_diff_2k.jpg")
	var tex_bank: Texture2D = load("res://assets/models/BordeDelRio_coast_sand_rocks_02_diff_2k.jpg")
	var tex_top: Texture2D = load("res://assets/models/Suelo_Zona_diff_2k.jpg")
	if tex1: terrain_mat.set_shader_parameter("tex_zona1", tex1)
	if tex2: terrain_mat.set_shader_parameter("tex_zona2", tex2)
	if tex3: terrain_mat.set_shader_parameter("tex_zona3", tex3)
	if tex_bank: terrain_mat.set_shader_parameter("tex_bank", tex_bank)
	if tex_top: terrain_mat.set_shader_parameter("tex_top", tex_top)

	# Generar un normal map procedural para darle volumen y relieve a la tierra
	var noise_normal = NoiseTexture2D.new()
	var noise_lite = FastNoiseLite.new()
	noise_lite.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_lite.frequency = 0.02
	noise_normal.noise = noise_lite
	noise_normal.as_normal_map = true
	noise_normal.bump_strength = 1.5
	terrain_mat.set_shader_parameter("normal_map", noise_normal)

	# Normal map activado para que la iluminación le de volumen a la tierra.
	terrain_mat.set_shader_parameter("normal_scale", 0.5)
	# Parámetros de mezcla
	terrain_mat.set_shader_parameter("uv_scale", 0.2)
	terrain_mat.set_shader_parameter("z_blend_z1z2", -70.0) # centro transición Z1→Z2
	terrain_mat.set_shader_parameter("z_blend_z2z3", -140.0) # centro transición Z2→Z3
	terrain_mat.set_shader_parameter("z_blend_z3z4", -210.0) # centro transición Z3→Z4
	terrain_mat.set_shader_parameter("blend_half_width", 12.0) # ±12 m de transición suave
	terrain_mat.set_shader_parameter("roughness", 0.95)
	# Vertex displacement del lecho (hundimientos y elevaciones procedurales)
	terrain_mat.set_shader_parameter("displacement_strength", 0.8) # ±0.8 m de relieve visible
	terrain_mat.set_shader_parameter("displacement_frequency", 0.10) # frecuencia espacial
	terrain_mat.set_shader_parameter("bank_height_strength", 1.2) # ±1.2 m variación de barranca por zona
	print("Terrain: ShaderMaterial multi-zona cargado (Z1=sandy, Z2=forest, Z3/Z4=mud).")

	# ---- CSGPolygon3D in PATH mode ----
	var valley := CSGPolygon3D.new()
	valley.name = "ValleyTerrain"
	valley.polygon = profile
	valley.mode = CSGPolygon3D.MODE_PATH
	valley.path_rotation = CSGPolygon3D.PATH_ROTATION_POLYGON
	valley.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	valley.path_interval = 2.0 # mayor resolución longitudinal para vertex displacement
	valley.smooth_faces = true
	valley.path_continuous_u = true
	valley.path_u_distance = 10.0
	valley.material = terrain_mat
	valley.use_collision = true # Habilita Snap to Floor (Shift+Fin) en el editor
	valley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(valley)
	valley.path_node = valley.get_path_to($RiverPath)
	print("Valley: CSGPolygon3D terrain creado a lo largo del RiverPath.")

	return valley


# =========================================================
# _input — CONTROL DE CÁMARA LIBRE (integrado en Main)
# =========================================================
func _input(event: InputEvent) -> void:
	if not _fl_camera:
		return
	if Engine.is_editor_hint():
		return

	# Activar arrastre con clic izquierdo o derecho del mouse
	if event is InputEventMouseButton:
		var btn := (event as InputEventMouseButton).button_index
		if btn == MOUSE_BUTTON_LEFT or btn == MOUSE_BUTTON_RIGHT:
			_fl_dragging = (event as InputEventMouseButton).pressed

	# Rotar cámara con movimiento del mouse
	if event is InputEventMouseMotion and _fl_dragging:
		var rel := (event as InputEventMouseMotion).relative
		_fl_yaw -= rel.x * FL_MOUSE_SENS
		_fl_pitch -= rel.y * FL_MOUSE_SENS
		_fl_pitch = clamp(_fl_pitch, deg_to_rad(-FL_PITCH_LIMIT), deg_to_rad(FL_PITCH_LIMIT))

	# Escape: soltar el arrastre
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			_fl_dragging = false

# =========================================================
# _process — MÁQUINA DE ESTADOS NARRATIVA
# =========================================================
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _narrative_state == NarrativeState.DONE:
		return
	if _narrative_state == NarrativeState.WAITING_START:
		# No hacer nada; el usuario debe presionar el botón "Sumergirse"
		_apply_visual_state(delta)
		_apply_freelook(delta)
		return

	# ── Avanzar timer del estado actual ──────────────────────────────────────
	var duration: float = NARRATIVE_DURATIONS.get(_narrative_state, 0.0)
	if duration > 0.0:
		_state_timer += delta
		if _state_timer >= duration:
			_advance_narrative_state()
			return

	# ── Mover el carro solo en estados UNDERWATER ─────────────────────────────
	var is_moving_state: bool = (
		_narrative_state == NarrativeState.Z1_UNDERWATER or
		_narrative_state == NarrativeState.Z2_UNDERWATER or
		_narrative_state == NarrativeState.Z3_UNDERWATER or
		_narrative_state == NarrativeState.Z4_UNDERWATER
	)
	if is_moving_state:
		cart.progress += speed * delta
		var active_progress: float = max(0.0, cart.progress - 200.0)
		var ratio: float = clamp(active_progress / 294.0, 0.0, 1.0)
		WaterManager.progress_ratio = ratio

	# ── Target de v_offset según si estamos en superficie o bajo el agua ─────
	var want_surface: bool = (
		_narrative_state == NarrativeState.WAITING_START or
		_narrative_state == NarrativeState.Z1_SURFACE_INTRO or
		_narrative_state == NarrativeState.Z2_SURFACE or
		_narrative_state == NarrativeState.Z3_SURFACE or
		_narrative_state == NarrativeState.Z4_SURFACE or
		_narrative_state == NarrativeState.Z4_EMERGE or
		_narrative_state == NarrativeState.Z4_CLOSING or
		_narrative_state == NarrativeState.CREDITS
	)
	var target_v: float = surface_height_offset if want_surface else 0.0
	_current_v_offset = lerp(_current_v_offset, target_v, LERP_SPEED * delta)
	cart.v_offset = _current_v_offset

	# ── Aplicar visuales (fog, ambient, partículas) ───────────────────────────
	_apply_visual_state(delta)
	_apply_freelook(delta)


# =========================================================
# _apply_visual_state — Efectos visuales de agua/superficie
# Se separa de _process para poder llamarlo también en WAITING_START
# =========================================================
func _apply_visual_state(delta: float) -> void:
	var cur_zone: int = NARRATIVE_ZONE.get(_narrative_state, 1)

	# Detectar posición respecto al agua usando la cámara activa
	var cam_y: float = _get_active_camera_y()
	_is_underwater = cam_y < WATER_SURFACE_Y

	# Transición instantánea al cruzar la superficie del agua
	if _is_underwater != _was_underwater:
		_was_underwater = _is_underwater
		if _is_underwater:
			_current_ambient     = ZONE_UW_AMBIENT_ENERGY[cur_zone]
			_current_ambient_col = ZONE_UW_AMBIENT_COLOR[cur_zone]
			for p in _particle_nodes:
				p.emitting = true
				p.visible  = true
		else:
			_current_ambient     = SF_AMBIENT_ENERGY
			_current_ambient_col = SF_AMBIENT_COLOR
			for p in _particle_nodes:
				p.emitting = false
				p.visible  = false
				p.restart()

	# Targets visuales
	var target_fog_density: float = ZONE_UW_FOG_DENSITY[cur_zone]
	var target_fog_col: Color     = ZONE_UW_FOG_COLOR[cur_zone]
	var t_amb: float
	var t_amb_col: Color
	if _is_underwater:
		t_amb     = ZONE_UW_AMBIENT_ENERGY[cur_zone]
		t_amb_col = ZONE_UW_AMBIENT_COLOR[cur_zone]
	else:
		t_amb     = SF_AMBIENT_ENERGY
		t_amb_col = SF_AMBIENT_COLOR

	_current_ambient     = lerp(_current_ambient, t_amb, LERP_SPEED * delta)
	_current_ambient_col = _current_ambient_col.lerp(t_amb_col, LERP_SPEED * delta)
	_current_fog_density = lerp(_current_fog_density, target_fog_density, LERP_SPEED * delta)
	_current_fog_col     = _current_fog_col.lerp(target_fog_col, LERP_SPEED * delta)

	# Aplicar Environment
	var env = $WorldEnvironment.environment
	if env:
		env.ambient_light_color  = _current_ambient_col
		env.ambient_light_energy = _current_ambient
		if _is_underwater:
			env.background_mode  = Environment.BG_COLOR
			env.background_color = _current_fog_col
			env.fog_enabled      = true
			env.fog_mode         = Environment.FOG_MODE_EXPONENTIAL
			env.fog_light_color  = _current_fog_col
			env.fog_density      = _current_fog_density
		else:
			env.background_mode = Environment.BG_SKY
			env.fog_enabled     = false

	# Luz direccional
	if has_node("DirectionalLight3D"):
		var lt: Array[float] = [0.0, 0.35, 0.24, 0.14, 0.08]
		var target_light: float = lt[cur_zone] if _is_underwater else 0.6
		$DirectionalLight3D.light_energy = lerp(
			$DirectionalLight3D.light_energy, target_light, LERP_SPEED * delta)

	# Partículas
	if _particle_proc and _particle_mat:
		if _is_underwater:
			_particle_proc.gravity = Vector3(0.0, 0.04, 0.0)
			_particle_proc.emission_box_extents = Vector3(2.5, 1.2, 2.5)
			var mc: Color = ZONE_UW_FOG_COLOR[cur_zone].lightened(0.1)
			mc.a = 0.45
			_particle_mat.albedo_color = mc
			_particle_mat.roughness    = 0.95
			for p in _particle_nodes:
				if not p.emitting: p.emitting = true
				if not p.visible:  p.visible  = true
		else:
			for p in _particle_nodes:
				if p.emitting: p.emitting = false
				if p.visible:
					p.visible = false
					p.restart()

	# Restaurar FOV fijo de la cámara (solo en modo pantalla, no en VR)
	if not get_viewport().use_xr and has_node("RiverPath/UserCart/XROrigin3D/XRCamera3D"):
		$RiverPath/UserCart/XROrigin3D/XRCamera3D.fov = _base_fov


# =========================================================
# _apply_freelook — Control de cámara libre (extraído de _process)
# =========================================================
func _apply_freelook(delta: float) -> void:
	if not _fl_camera:
		return
	var fl_turn: float = 0.0
	var fl_pitch_d: float = 0.0
	if Input.is_key_pressed(KEY_LEFT)  or Input.is_key_pressed(KEY_A): fl_turn  += FL_KEY_SPEED * delta
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): fl_turn  -= FL_KEY_SPEED * delta
	if Input.is_key_pressed(KEY_UP)    or Input.is_key_pressed(KEY_W): fl_pitch_d += FL_KEY_SPEED * delta
	if Input.is_key_pressed(KEY_DOWN)  or Input.is_key_pressed(KEY_S): fl_pitch_d -= FL_KEY_SPEED * delta
	_fl_yaw   += fl_turn
	_fl_pitch = clamp(_fl_pitch + fl_pitch_d, deg_to_rad(-FL_PITCH_LIMIT), deg_to_rad(FL_PITCH_LIMIT))
	_fl_camera.global_position = cart.global_position
	_fl_camera.rotation = Vector3(_fl_pitch, _fl_yaw, 0.0)




# =========================================================
# CONTROL DE LA MÁQUINA NARRATIVA
# =========================================================

## Avanza al siguiente estado de la secuencia narrativa
func _advance_narrative_state() -> void:
	var idx: int = NARRATIVE_SEQUENCE.find(_narrative_state)
	if idx < 0 or idx >= NARRATIVE_SEQUENCE.size() - 1:
		return
	var next: NarrativeState = NARRATIVE_SEQUENCE[idx + 1]
	_enter_narrative_state(next)

## Entra en el estado dado y notifica al HUD
func _enter_narrative_state(new_state: NarrativeState) -> void:
	_narrative_state = new_state
	_state_timer     = 0.0

	var zone: int = NARRATIVE_ZONE.get(new_state, 1)
	WaterManager.progress_ratio = _narrative_ratio_for_zone(zone)

	# Actualizar el shader de agua al entrar en cada zona nueva
	_update_water_zone(zone)

	# Notificar al HUD si existe y tiene el método
	if _hud and _hud.has_method("on_narrative_state_changed"):
		_hud.on_narrative_state_changed(new_state, zone)

	print("Narrativa → %s (zona %d, dur: %.1f s)" % [
		NarrativeState.keys()[new_state], zone,
		NARRATIVE_DURATIONS.get(new_state, 0.0)
	])

## Botón "Sumergirse" del HUD llama a esto para iniciar la experiencia
func on_dive_button_pressed() -> void:
	if _narrative_state != NarrativeState.WAITING_START:
		return
	_enter_narrative_state(NarrativeState.Z1_SURFACE_INTRO)

## Ratio de WaterManager por zona (para inicializar métricas en cada emersión)
func _narrative_ratio_for_zone(zone: int) -> float:
	match zone:
		1: return 0.0
		2: return 0.30
		3: return 0.55
		4: return 0.80
	return 0.0

# =========================================================
# Helpers
# =========================================================
func _zone_from_ratio(r: float) -> int:
	if r < 0.25: return 1
	elif r < 0.50: return 2
	elif r < 0.75: return 3
	else: return 4

func _on_zone_changed(new_zone: int) -> void:
	var density: float = ZONE_UW_FOG_DENSITY[new_zone]
	var vis_dist: float = 3.0 / density if density > 0.0 else 0.0
	print("→ ZONA %d: %s | Neblina Densidad: %.3f | Visibilidad Alcance: ~%.0f metros" % [new_zone, WaterManager.get_zone_name(), density, vis_dist])
	_update_water_zone(new_zone)

# Paleta de superficie del agua por zona (marrón pampeano para watershader2.gdshader)
const WATER_SHALLOW_COLOR: Array[Color] = [
	Color(0.0, 0.0, 0.0, 1.0),
	Color(0.55, 0.44, 0.28, 1.0), # Z1: té con leche claro
	Color(0.47, 0.33, 0.15, 1.0), # Z2: café con leche
	Color(0.36, 0.22, 0.08, 1.0), # Z3: chocolate líquido
	Color(0.28, 0.15, 0.04, 1.0), # Z4: marrón lodo oscuro
]
const WATER_DEEP_COLOR: Array[Color] = [
	Color(0.0, 0.0, 0.0, 1.0),
	Color(0.30, 0.20, 0.08, 1.0), # Z1
	Color(0.24, 0.14, 0.05, 1.0), # Z2
	Color(0.16, 0.09, 0.03, 1.0), # Z3
	Color(0.10, 0.05, 0.01, 1.0), # Z4
]
const WATER_BASE_COLOR: Array[Color] = [
	Color(0.0, 0.0, 0.0, 1.0),
	Color(0.45, 0.35, 0.22, 1.0), # Z1: superficie templada
	Color(0.38, 0.26, 0.12, 1.0), # Z2: tono orgánico
	Color(0.28, 0.16, 0.06, 1.0), # Z3: sedimento espeso
	Color(0.20, 0.10, 0.02, 1.0), # Z4: lodo degradado
]
const WATER_FRESNEL_COLOR: Array[Color] = [
	Color(0.0, 0.0, 0.0, 1.0),
	Color(0.48, 0.46, 0.42, 1.0), # Z1: reflejo tenue desaturado
	Color(0.42, 0.44, 0.40, 1.0), # Z2: reflejo mate verdoso
	Color(0.35, 0.35, 0.33, 1.0), # Z3: reflejo opaco grisáceo
	Color(0.28, 0.26, 0.24, 1.0), # Z4: reflejo opaco apagado
]
const WATER_BEERS_LAW: Array[float] = [
	0.0, 0.35, 0.65, 1.10, 1.80
]
# Velocidad de corriente del agua por zona:
# Zona 1 & 2: 1.20 (100%)
# Zona 3: 0.90 (3/4 de Zona 1)
# Zona 4: 0.60 (1/2 de Zona 1)
const WATER_FLOW_SPEED: Array[float] = [
	0.0, 1.20, 1.20, 0.90, 0.60
]

func _update_water_zone(zone: int) -> void:
	if _water_mats.is_empty():
		return
	var z: int = clamp(zone, 1, 4)
	var roughness_by_zone: Array[float] = [0.0, 0.22, 0.28, 0.35, 0.45]
	var wave_amp_by_zone: Array[float] = [0.0, 1.00, 0.85, 0.30, 0.15]
	var flow_speed_by_zone: Array[float] = [0.0, 1.80, 1.20, 0.35, 0.18]
	var normal_strength_by_zone: Array[float] = [0.0, 1.00, 0.85, 0.50, 0.38]
	for mat in _water_mats:
		mat.set_shader_parameter("metallic", 0.0)
		mat.set_shader_parameter("shallow_water_color", WATER_SHALLOW_COLOR[z])
		mat.set_shader_parameter("deep_water_color", WATER_DEEP_COLOR[z])
		var bc = WATER_BASE_COLOR[z]
		mat.set_shader_parameter("base_water_color", Vector3(bc.r, bc.g, bc.b))
		var fc = WATER_FRESNEL_COLOR[z]
		mat.set_shader_parameter("fresnel_water_color", Vector3(fc.r, fc.g, fc.b))
		mat.set_shader_parameter("beers_law", WATER_BEERS_LAW[z])
		mat.set_shader_parameter("roughness", roughness_by_zone[z])
		mat.set_shader_parameter("wave_amplitude_scale", 1.0)
		mat.set_shader_parameter("river_flow_speed", flow_speed_by_zone[z])
		mat.set_shader_parameter("normal_strength_scale", 1.0)
	print("Water: zona %d — superficie, olas y velocidad actualizadas en watershader2.gdshader." % z)

func _on_metrics_updated(wqi: float, do_val: float, _turb_val: float) -> void:
	var vis_m: float = WaterManager.get_metric_value("visibility", WaterManager.progress_ratio)
	print("ICA (WQI)=%.1f | OD=%.2f mg/L | Neblina Densidad=%.3f | Visibilidad Alcance=~%.0f m" % [wqi, do_val, _current_fog_density, vis_m])

# =========================================================
# _find_mesh_instance — busca recursivamente el primer MeshInstance3D
# =========================================================
func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var result: MeshInstance3D = _find_mesh_instance(child)
		if result:
			return result
	return null

# =========================================================
# _build_noisy_riverbed
# Genera un MeshInstance3D con la malla del lecho del río.
# Los vértices se desplazan en Y usando FastNoiseLite para
# simular pequeñas elevaciones de arena/grava.
#
# Dimensiones del canal: 16 m de ancho (X: -8 a +8),
#                        420 m de largo (Z: 0 a -420).
# El nodo se posiciona en Y=-1.5 (fondo del perfil del valle).
# =========================================================

@tool
extends Node3D

@onready var cart = $RiverPath/UserCart
@export var target_total_duration: float = 120.0 # Duración objetivo total: 120 segundos (2 minutos)
@export var speed: float = 6.89 # Calculado dinámicamente según la longitud de la ruta y las pausas
@export var surface_height_offset: float = 3.5 # Altura vertical de la cámara al emerger a la superficie

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

# Estado en superficie (mismo para todas las zonas)
const SF_AMBIENT_ENERGY: float = 1.2
const SF_AMBIENT_COLOR: Color = Color(0.72, 0.72, 0.68, 1.0)

# Umbral de superficie ajustado a +0.25 m para coincidir con la cresta de las olas en movimiento del shader
const WATER_SURFACE_Y: float = 0.25
const LERP_SPEED: float = 2.5
const SURFACE_PAUSE_DURATION: float = 10.0

# =========================================================
# MÁQUINA DE ESTADOS
# =========================================================
enum State {UNDERWATER, SURFACE_PAUSE, DONE}
var _state: State = State.UNDERWATER
var _pause_timer: float = 0.0
# Coordenadas Z exactas donde emerge a cada zona (Zona2, Zona3, Zona4) para recorrido activo de 294 m
const SURFACE_Z_CHECKPOINTS: Array[float] = [-105.0, -175.0, -245.0]
var _triggered_checkpoints: Dictionary = {} # z_checkpoint -> true si ya disparó

# =========================================================
# ESTADO VISUAL INTERPOLADO
# =========================================================
var _current_ambient: float = 1.1
var _current_ambient_col: Color = Color(0.62, 0.50, 0.34, 1.0)
var _current_fog_density: float = 0.035
var _current_fog_col: Color = Color(0.58, 0.46, 0.32, 1.0)
var _is_underwater: bool = true
var _was_underwater: bool = true
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
		env.tonemap_mode = Environment.TONE_MAPPER_AGX # AgX: Excelente compresión de rango dinámico sin distorsión de color
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
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		print("XR Mode: Headset detected.")
	else:
		print("XR Mode: Flat mode (no headset). FreeLook activado.")
		_setup_free_look()

	WaterManager.zone_changed.connect(_on_zone_changed)
	WaterManager.metrics_updated.connect(_on_metrics_updated)
	_setup_camera_fx()
	_setup_aquatic_fauna()

	# Posicionar el carrito en Z=0 (después de la extensión de 200m del telón visual trasero)
	cart.progress = 200.0
	WaterManager.progress_ratio = 0.0

	# Calcular velocidad para recorrer los 294 m activos (Z=0 a Z=-294) + 3 pausas de 10s en 2 minutos (120 s)
	var active_distance: float = 294.0 # metros reales de trayectoria activa (30% más lenta: 3.27 m/s)
	var total_pauses: float = SURFACE_Z_CHECKPOINTS.size() * SURFACE_PAUSE_DURATION # 30s
	var moving_time: float = max(10.0, target_total_duration - total_pauses) # 90s
	speed = active_distance / moving_time # 3.27 m/s
	print("Velocidad de riel calibrada: %.2f m/s (294m activos en 90s + 30s pausas = 120s / 2 min)" % speed)

# =========================================================
# _setup_free_look — Control de cámara para modo web/flat
# =========================================================
func _setup_free_look() -> void:
	if not has_node("FlatCamera"):
		push_warning("FreeLook: No se encontró FlatCamera en la raíz de la escena.")
		return
	_fl_camera = $FlatCamera
	_fl_yaw   = 0.0
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
	if has_node("RiverPath/UserCart/FlatCamera"):
		target_cameras.append($RiverPath/UserCart/FlatCamera)

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
# _setup_aquatic_fauna — Asigna automáticamente nado y animación a todos los peces
# =========================================================
func _setup_aquatic_fauna() -> void:
	var fauna_node := get_node_or_null("Zona1/FaunaAcuatica")
	if not fauna_node:
		return
	var fish_script = preload("res://scripts/MojarraAnimada.gd")
	_attach_fish_script_recursive(fauna_node, fish_script)

func _attach_fish_script_recursive(node: Node, fish_script: Script) -> void:
	for child in node.get_children():
		if child is Node3D and child.get_child_count() > 0 and child.get_script() == null:
			child.set_script(fish_script)
			if child.has_method("_ready"):
				child._ready()
		_attach_fish_script_recursive(child, fish_script)

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

	var checkpoints_info: Array[Dictionary] = [
		{"z": -105.0, "name": "Zona 2 (Transición)", "color": Color(0.2, 0.85, 1.0)},
		{"z": -175.0, "name": "Zona 3 (Turbia)", "color": Color(1.0, 0.85, 0.2)},
		{"z": -245.0, "name": "Zona 4 (Degradada)", "color": Color(1.0, 0.4, 0.3)}
	]

	var baked_points = curve.get_baked_points()
	if baked_points.is_empty():
		return

	for item in checkpoints_info:
		var target_z: float = item["z"]
		var best_pt: Vector3 = baked_points[0]
		var min_dist: float = 999999.0

		for pt in baked_points:
			var d: float = abs(pt.z - target_z)
			if d < min_dist:
				min_dist = d
				best_pt = pt

		# 1. Label3D flotante visible en el viewport 3D del editor
		var label := Label3D.new()
		label.text = "📍 EMERSIÓN %s\nZ = %.0fm" % [item["name"], target_z]
		label.position = Vector3(best_pt.x, 3.8, target_z)
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
		ring_inst.position = Vector3(best_pt.x, 0.25, target_z)
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
	if tex1: terrain_mat.set_shader_parameter("tex_zona1", tex1)
	if tex2: terrain_mat.set_shader_parameter("tex_zona2", tex2)
	if tex3: terrain_mat.set_shader_parameter("tex_zona3", tex3)
	if tex_bank: terrain_mat.set_shader_parameter("tex_bank", tex_bank)

	# Normal map desactivado — el bump_strength alto generaba sombras oscuras artificiales.
	# La rugosidad visual se logra únicamente con roughness=0.95 (material PBR mate).
	terrain_mat.set_shader_parameter("normal_scale", 0.0)

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
	valley.path_interval = 2.0  # mayor resolución longitudinal para vertex displacement
	valley.smooth_faces = true
	valley.path_continuous_u = true
	valley.path_u_distance = 10.0
	valley.material = terrain_mat
	valley.use_collision = true   # Habilita Snap to Floor (Shift+Fin) en el editor
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
		_fl_yaw   -= rel.x * FL_MOUSE_SENS
		_fl_pitch -= rel.y * FL_MOUSE_SENS
		_fl_pitch = clamp(_fl_pitch, deg_to_rad(-FL_PITCH_LIMIT), deg_to_rad(FL_PITCH_LIMIT))

	# Escape: soltar el arrastre
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			_fl_dragging = false

# =========================================================
# _process — STATE MACHINE
# =========================================================
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _state == State.DONE:
		return

	# Calcular ratio relativo al trayecto activo de navegación (Z=0 a Z=-294)
	# Ignorando los 200m del telón visual trasero (Z=+200 a Z=0)
	var active_progress: float = max(0.0, cart.progress - 200.0)
	var ratio: float = clamp(active_progress / 294.0, 0.0, 1.0)
	var cur_zone: int = _zone_from_ratio(ratio)

	# Movimiento (calibrado para 2 minutos totales de recorrido activo)
	if _state == State.UNDERWATER:
		cart.progress += speed * delta
		WaterManager.progress_ratio = ratio
		# Chequear checkpoints de emersión por posición Z exacta
		var cart_z: float = cart.global_position.z
		for z_target in SURFACE_Z_CHECKPOINTS:
			if not _triggered_checkpoints.has(z_target) and cart_z <= z_target:
				_triggered_checkpoints[z_target] = true
				_state = State.SURFACE_PAUSE
				_pause_timer = 0.0
				print("→ SURFACE_PAUSE en Z=%.0f (zona %d)" % [z_target, cur_zone])
				break # solo una pausa a la vez
		if ratio >= 1.0:
			_state = State.DONE
			set_process(false)
			print("Experiencia completada.")

	elif _state == State.SURFACE_PAUSE:
		_pause_timer += delta
		if _pause_timer >= SURFACE_PAUSE_DURATION:
			_state = State.UNDERWATER
			print("→ UNDERWATER")

	# Animación suave de elevación vertical a la superficie durante pausas (sin modificar el terreno)
	var target_v: float = surface_height_offset if _state == State.SURFACE_PAUSE else 0.0
	_current_v_offset = lerp(_current_v_offset, target_v, LERP_SPEED * delta)
	cart.v_offset = _current_v_offset

	# Detectar posición respecto al agua usando la cámara activa
	var cam_y: float = _get_active_camera_y()
	_is_underwater = cam_y < WATER_SURFACE_Y

	# Transición instantánea de estado al cruzar la superficie del agua (submerger/emerger)
	if _is_underwater != _was_underwater:
		_was_underwater = _is_underwater
		if _is_underwater:
			# AL SUMERGIRSE: Iluminación subacuática e inicio de partículas INSTANTÁNEO
			_current_ambient = ZONE_UW_AMBIENT_ENERGY[cur_zone]
			_current_ambient_col = ZONE_UW_AMBIENT_COLOR[cur_zone]
			for p in _particle_nodes:
				p.emitting = true
				p.visible = true
		else:
			# AL EMERGER: Restaurar iluminación de superficie y ocultar partículas
			_current_ambient = SF_AMBIENT_ENERGY
			_current_ambient_col = SF_AMBIENT_COLOR
			for p in _particle_nodes:
				p.emitting = false
				p.visible = false
				p.restart()

	# Targets visuales (ambient y neblina WorldEnvironment)
	var t_amb: float
	var t_amb_col: Color
	var target_fog_density: float = ZONE_UW_FOG_DENSITY[cur_zone]
	var target_fog_col: Color = ZONE_UW_FOG_COLOR[cur_zone]

	if _is_underwater:
		t_amb = ZONE_UW_AMBIENT_ENERGY[cur_zone]
		t_amb_col = ZONE_UW_AMBIENT_COLOR[cur_zone]
	else:
		t_amb = SF_AMBIENT_ENERGY
		t_amb_col = SF_AMBIENT_COLOR

	# Interpolar ambient y neblina
	_current_ambient = lerp(_current_ambient, t_amb, LERP_SPEED * delta)
	_current_ambient_col = _current_ambient_col.lerp(t_amb_col, LERP_SPEED * delta)
	_current_fog_density = lerp(_current_fog_density, target_fog_density, LERP_SPEED * delta)
	_current_fog_col = _current_fog_col.lerp(target_fog_col, LERP_SPEED * delta)

	# Aplicar Environment
	var env = $WorldEnvironment.environment
	if env:
		env.ambient_light_color = _current_ambient_col
		env.ambient_light_energy = _current_ambient
		if _is_underwater:
			env.background_mode = Environment.BG_COLOR
			env.background_color = _current_fog_col
			# Neblina subacuática de WorldEnvironment activa: densidad progresiva y color de agua turbia
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
			env.fog_light_color = _current_fog_col
			env.fog_density = _current_fog_density
		else:
			# En superficie: deshabilitar neblina por completo para no alterar la visión exterior
			env.background_mode = Environment.BG_SKY
			env.fog_enabled = false

	# Luz direccional
	if has_node("DirectionalLight3D"):
		var lt: Array[float] = [0.0, 0.35, 0.24, 0.14, 0.08]
		var target_light: float = lt[cur_zone] if _is_underwater else 0.6
		$DirectionalLight3D.light_energy = lerp(
			$DirectionalLight3D.light_energy, target_light, LERP_SPEED * delta)

	# Partículas (sedimento/burbujas subacuáticas)
	if _particle_proc and _particle_mat:
		if _is_underwater:
			_particle_proc.gravity = Vector3(0.0, 0.04, 0.0)
			_particle_proc.emission_box_extents = Vector3(2.5, 1.2, 2.5)
			var mc: Color = ZONE_UW_FOG_COLOR[cur_zone].lightened(0.1)
			mc.a = 0.45
			_particle_mat.albedo_color = mc
			_particle_mat.roughness = 0.95
			for p in _particle_nodes:
				if not p.emitting:
					p.emitting = true
				if not p.visible:
					p.visible = true
		else:
			for p in _particle_nodes:
				if p.emitting:
					p.emitting = false
				if p.visible:
					p.visible = false
					p.restart()

	# Restaurar FOV fijo de la cámara
	if has_node("RiverPath/UserCart/XROrigin3D/XRCamera3D"):
		$RiverPath/UserCart/XROrigin3D/XRCamera3D.fov = _base_fov

	# Teclado WASD / Flechas para rotar la cámara libre
	if _fl_camera:
		var fl_turn  := 0.0
		var fl_pitch := 0.0
		if Input.is_key_pressed(KEY_LEFT)  or Input.is_key_pressed(KEY_A):
			fl_turn += FL_KEY_SPEED * delta
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			fl_turn -= FL_KEY_SPEED * delta
		if Input.is_key_pressed(KEY_UP)    or Input.is_key_pressed(KEY_W):
			fl_pitch += FL_KEY_SPEED * delta
		if Input.is_key_pressed(KEY_DOWN)  or Input.is_key_pressed(KEY_S):
			fl_pitch -= FL_KEY_SPEED * delta
		_fl_yaw   += fl_turn
		_fl_pitch  = clamp(_fl_pitch + fl_pitch, deg_to_rad(-FL_PITCH_LIMIT), deg_to_rad(FL_PITCH_LIMIT))

	# La FlatCamera ahora está en la raíz de la escena (no es hija del PathFollow3D).
	# Copiamos SOLO la posición global del carro, y aplicamos nuestra propia rotación libre.
	if _fl_camera:
		_fl_camera.global_position = cart.global_position
		_fl_camera.rotation = Vector3(_fl_pitch, _fl_yaw, 0.0)


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

func _update_water_zone(zone: int) -> void:
	if _water_mats.is_empty():
		return
	var z: int = clamp(zone, 1, 4)
	var roughness_by_zone: Array[float] = [0.0, 0.22, 0.28, 0.35, 0.45]
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
	print("Water: zona %d — superficie actualizada en watershader2.gdshader." % z)

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

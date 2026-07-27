@tool
extends Node3D

@onready var cart = $RiverPath/UserCart
@export var speed: float = 2.0

# =========================================================
# PALETA VISUAL POR ZONA (EcoAgua / Amaya 2018)
# El agua SIEMPRE es marrón pampeana, nunca azul.
# Índice 0 sin usar — base 1.
# =========================================================
# Paleta de colores: degradé marrón pampeano, de claro a oscuro.
# Zona 4 usa marrón oscuro (no negro) — densidad alta acorta el campo, no blanquea.
const ZONE_UW_FOG_COLOR: Array[Color] = [
	Color(0.00, 0.00, 0.00, 1.0),
	Color(0.55, 0.42, 0.28, 1.0), # Z1: té con leche diluido   — visible claro
	Color(0.44, 0.30, 0.14, 1.0), # Z2: café con leche          — algo más denso
	Color(0.32, 0.18, 0.07, 1.0), # Z3: chocolate con leche     — turbio
	Color(0.22, 0.12, 0.05, 1.0), # Z4: marrón oscuro intenso   — muy turbio
]

const ZONE_UW_AMBIENT_COLOR: Array[Color] = [
	Color(0.00, 0.00, 0.00, 1.0),
	Color(0.62, 0.50, 0.34, 1.0), # Z1
	Color(0.50, 0.36, 0.18, 1.0), # Z2
	Color(0.38, 0.22, 0.09, 1.0), # Z3
	Color(0.28, 0.15, 0.06, 1.0), # Z4 — marrón oscuro, no negro
]
const ZONE_UW_AMBIENT_ENERGY: Array[float] = [
	0.0,
	1.10, # Z1: luz ambiente buena
	0.88, # Z2
	0.65, # Z3
	0.45, # Z4: reducida pero visible
]
const ZONE_UW_BG_COLOR: Array[Color] = [
	Color(0.00, 0.00, 0.00, 1.0),
	Color(0.48, 0.36, 0.22, 1.0), # Z1
	Color(0.36, 0.24, 0.11, 1.0), # Z2
	Color(0.26, 0.14, 0.05, 1.0), # Z3
	Color(0.18, 0.09, 0.03, 1.0), # Z4 — fondo marrón oscuro
]
# Opacidad del tinte por zona (esfera adherida a la cámara)
const ZONE_TINT_ALPHA: Array[float] = [
	0.0, 0.45, 0.58, 0.68, 0.76,
]

# Estado en superficie (mismo para todas las zonas)
const SF_AMBIENT_ENERGY: float = 1.2
const SF_AMBIENT_COLOR: Color = Color(0.72, 0.72, 0.68, 1.0)

const WATER_SURFACE_Y: float = 0.0
const LERP_SPEED: float = 2.5
const SURFACE_PAUSE_DURATION: float = 10.0

# =========================================================
# MÁQUINA DE ESTADOS
# =========================================================
enum State {UNDERWATER, SURFACE_PAUSE, DONE}
var _state: State = State.UNDERWATER
var _pause_timer: float = 0.0
# Coordenadas Z exactas donde emerge a cada zona (Zona2, Zona3, Zona4)
const SURFACE_Z_CHECKPOINTS: Array[float] = [-150.0, -250.0, -350.0]
var _triggered_checkpoints: Dictionary = {} # z_checkpoint -> true si ya disparó

# =========================================================
# ESTADO VISUAL INTERPOLADO
# =========================================================
var _current_ambient: float = 1.1
var _current_ambient_col: Color = Color(0.62, 0.50, 0.34, 1.0)
var _is_underwater: bool = true

# =========================================================
# REFERENCIAS A OBJETOS EN TIEMPO DE EJECUCIÓN
# =========================================================
var _particles: GPUParticles3D = null
var _particle_proc: ParticleProcessMaterial = null
var _particle_mat: StandardMaterial3D = null
var _tint_mat: StandardMaterial3D = null # esfera de tinte subacuático
var _water_mat: ShaderMaterial = null  # ShaderMaterial del nodo TopWater
var _water_mats: Array[ShaderMaterial] = []  # alias array para _update_water_zone

# =========================================================
# _ready
# =========================================================
func _ready() -> void:
	if has_node("DirectionalLight3D"):
		# Afternoon sun: 45° elevation from the south-west.
		$DirectionalLight3D.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(45.0), 0.0)
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
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	_alinear_mvp()
	_build_environment()


	if Engine.is_editor_hint():
		return

	var xr_interface = XRServer.find_interface("OpenXR")
	if xr_interface and xr_interface.is_initialized():
		get_viewport().use_xr = true
		print("XR Mode: Headset detected.")
	else:
		print("XR Mode: Flat mode (no headset).")

	WaterManager.zone_changed.connect(_on_zone_changed)
	WaterManager.metrics_updated.connect(_on_metrics_updated)
	_setup_camera_fx()

# =========================================================
# _setup_camera_fx — Esfera de tinte + partículas
# =========================================================
func _setup_camera_fx() -> void:
	var camera = $RiverPath/UserCart/XROrigin3D/XRCamera3D

	# --- Esfera de tinte subacuático ---
	# SphereMesh unlit, cull_front (visible desde adentro),
	# no_depth_test (siempre al frente), render_priority alto.
	_tint_mat = StandardMaterial3D.new()
	_tint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_tint_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_tint_mat.no_depth_test = true
	_tint_mat.render_priority = 127
	_tint_mat.albedo_color = Color(0.55, 0.42, 0.28, 0.0) # empieza transparente

	var tint_mesh := SphereMesh.new()
	tint_mesh.radius = 0.9
	tint_mesh.height = 1.8
	tint_mesh.radial_segments = 8
	tint_mesh.rings = 4
	tint_mesh.material = _tint_mat

	var tint_node := MeshInstance3D.new()
	tint_node.name = "UnderwaterTint"
	tint_node.mesh = tint_mesh
	tint_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(tint_node)

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

	_particles = GPUParticles3D.new()
	_particles.amount = 80
	_particles.lifetime = 5.0
	_particles.process_material = _particle_proc
	_particles.draw_pass_1 = sphere
	_particles.emitting = true
	_particles.local_coords = false
	camera.add_child(_particles)

	print("Camera FX: tinte subacuático y partículas creados.")

# =========================================================
# _enter_tree
# =========================================================
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		await get_tree().process_frame
		if has_node("RiverPath") and has_node("Zona1"):
			_alinear_mvp()
			_update_water_zone(1)

# =========================================================
# _alinear_mvp
# =========================================================
func _alinear_mvp() -> void:
	$Zona1.position = Vector3(0, 0, -50)
	$Zona2.position = Vector3(0, 0, -150)
	$Zona3.position = Vector3(0, 0, -250)
	$Zona4.position = Vector3(0, 0, -350)

	var curve = $RiverPath.curve
	if curve:
		curve.clear_points()
		# Y = -0.5 → bajo el agua (cámara está 0.5 m bajo la superficie en Y=0)
		# Y =  1.5 → sobre la superficie (orilla visible)
		curve.add_point(Vector3(0, -0.5, 0))
		curve.add_point(Vector3(0, -0.5, -140))
		curve.add_point(Vector3(0, 1.5, -150)) # emerge Zona2
		curve.add_point(Vector3(0, -0.5, -160))
		curve.add_point(Vector3(0, -0.5, -240))
		curve.add_point(Vector3(0, 1.5, -250)) # emerge Zona3
		curve.add_point(Vector3(0, -0.5, -260))
		curve.add_point(Vector3(0, -0.5, -340))
		curve.add_point(Vector3(0, 1.5, -350)) # emerge Zona4
		curve.add_point(Vector3(0, -0.5, -360))
		curve.add_point(Vector3(0, -0.5, -420))

	var mat1 = StandardMaterial3D.new(); mat1.albedo_color = Color(0.56, 0.93, 0.56)
	$Zona1.set_surface_override_material(0, mat1)
	var mat2 = StandardMaterial3D.new(); mat2.albedo_color = Color(0.48, 0.56, 0.15)
	$Zona2.set_surface_override_material(0, mat2)
	var mat3 = StandardMaterial3D.new(); mat3.albedo_color = Color(0.20, 0.20, 0.20)
	$Zona3.set_surface_override_material(0, mat3)
	var mat4 = StandardMaterial3D.new(); mat4.albedo_color = Color(0.05, 0.05, 0.05)
	$Zona4.set_surface_override_material(0, mat4)

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

	# --- Cielo procedural (necesario para que el shader de agua refleje algo) ---
	# El ProceduralSkyMaterial genera un cielo con gradiente: azul en la cúpula,
	# crema/naranja en el horizonte y tierra oscura abajo (evita el rebote blanco).
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

	var env: Environment = $WorldEnvironment.environment
	if env:
		env.sky = sky
	print("Sky: cielo procedural tarde creado.")

	# ─── Water: superficie del agua sobre el río completo ─────────────
	# $Water es el MeshInstance3D creado en la escena (80×420 m, Y=0).
	# Le aplicamos watershader2.gdshader en runtime.
	_water_mats.clear()
	var water_node := get_node_or_null("Water") as MeshInstance3D
	if water_node == null:
		push_error("Water: no se encontró el nodo $Water en la escena.")
	else:
		# Posición y tamaño correctos: plano horizontal en Y=0, centrado en Z=-210.
		water_node.position = Vector3(0.0, 0.0, -210.0)
		water_node.rotation = Vector3.ZERO
		water_node.scale    = Vector3.ONE
		water_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		# Malla PlaneMesh de 80×420 m con 300×300 subdivisiones
		var plane := PlaneMesh.new()
		plane.size             = Vector2(80.0, 420.0)
		plane.subdivide_width  = 300
		plane.subdivide_depth  = 300
		water_node.mesh = plane

		# Cargar ShaderMaterial con watershader2.gdshader si no lo tiene asignado
		if water_node.material_override is ShaderMaterial:
			_water_mat = water_node.material_override as ShaderMaterial
		else:
			var shader_res: Shader = load("res://watershader2.gdshader")
			if shader_res:
				_water_mat = ShaderMaterial.new()
				_water_mat.shader = shader_res
				water_node.material_override = _water_mat

		if _water_mat:
			_water_mats = [_water_mat]
			_update_water_zone(1)
			print("Water: watershader2.gdshader aplicado y posicionado correctamente (80×420 m).")



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
	# ---- Polygon cross-section ----
	# Points defined counter-clockwise so the top face is outward.
	# X = river width axis, Y = vertical elevation.
	var profile := PackedVector2Array([
		# Top surface — left to right
		Vector2(-55.0, 2.0), # llanura izquierda, borde exterior
		Vector2(-18.0, 2.0), # cima barranca izquierda
		Vector2(-9.5, -1.0), # pie barranca izquierda
		Vector2(-8.0, -1.5), # lecho izquierdo
		Vector2(8.0, -1.5), # lecho derecho
		Vector2(9.5, -1.0), # pie barranca derecha
		Vector2(18.0, 2.0), # cima barranca derecha
		Vector2(55.0, 2.0), # llanura derecha, borde exterior
		# Close the solid body below ground
		Vector2(55.0, -6.0),
		Vector2(-55.0, -6.0),
	])

	# ---- Material: pampa soil con textura triplanar ----
	var terrain_mat := StandardMaterial3D.new()
	var floor_tex: Texture2D = load("res://Assets/Models/Suelo_Zona1_sandy_gravel_02_diff_2k.jpg") as Texture2D
	if floor_tex:
		terrain_mat.albedo_texture = floor_tex
		terrain_mat.uv1_triplanar = true
		terrain_mat.uv1_triplanar_sharpness = 4.0
		terrain_mat.uv1_scale = Vector3(0.2, 0.2, 0.2)
	else:
		terrain_mat.albedo_color = Color(0.55, 0.42, 0.26, 1.0) # fallback tierra pampeana
	terrain_mat.roughness = 0.95
	terrain_mat.metallic = 0.0

	# ---- CSGPolygon3D in PATH mode ----
	var valley := CSGPolygon3D.new()
	valley.name = "ValleyTerrain"
	valley.polygon = profile
	valley.mode = CSGPolygon3D.MODE_PATH
	# PATH_ROTATION_POLYGON keeps the cross-section world-upright even
	# when the path dips above/below the waterline — correct for flat terrain.
	valley.path_rotation = CSGPolygon3D.PATH_ROTATION_POLYGON
	# Place a new cross-section every 3 m along the path for smooth curves.
	valley.path_interval_type = CSGPolygon3D.PATH_INTERVAL_DISTANCE
	valley.path_interval = 3.0
	valley.smooth_faces = true
	# Continuous U mapping so the texture tiles without seams.
	valley.path_continuous_u = true
	valley.path_u_distance = 10.0 # UV repeats every 10 m along the path
	valley.material = terrain_mat
	valley.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(valley)
	# path_node MUST be set after add_child() so get_path_to() resolves correctly.
	valley.path_node = valley.get_path_to($RiverPath)
	print("Valley: CSGPolygon3D terrain creado a lo largo del RiverPath.")
	return valley

# =========================================================
# _process — STATE MACHINE
# =========================================================
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _state == State.DONE:
		return

	var ratio: float = cart.progress_ratio
	var cur_zone: int = _zone_from_ratio(ratio)

	# Movimiento
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

	# Detectar posición respecto al agua
	var cam_y: float = $RiverPath/UserCart/XROrigin3D/XRCamera3D.global_position.y
	_is_underwater = cam_y < WATER_SURFACE_Y

	# Targets visuales (ambient)
	var t_amb: float
	var t_amb_col: Color

	if _is_underwater:
		t_amb = ZONE_UW_AMBIENT_ENERGY[cur_zone]
		t_amb_col = ZONE_UW_AMBIENT_COLOR[cur_zone]
	else:
		t_amb = SF_AMBIENT_ENERGY
		t_amb_col = SF_AMBIENT_COLOR

	# Interpolar ambient
	_current_ambient = lerp(_current_ambient, t_amb, LERP_SPEED * delta)
	_current_ambient_col = _current_ambient_col.lerp(t_amb_col, LERP_SPEED * delta)

	# Aplicar Environment
	var env = $WorldEnvironment.environment
	if env:
		env.ambient_light_color = _current_ambient_col
		env.ambient_light_energy = _current_ambient
		if _is_underwater:
			env.background_mode = Environment.BG_COLOR
			env.background_color = ZONE_UW_BG_COLOR[cur_zone]
		else:
			env.background_mode = Environment.BG_SKY

	# Luz direccional
	if has_node("DirectionalLight3D"):
		var lt: Array[float] = [0.0, 0.35, 0.24, 0.14, 0.08] # Z4 sube de 0.02→0.08 para no quedar negro
		var target_light: float = lt[cur_zone] if _is_underwater else 0.6
		$DirectionalLight3D.light_energy = lerp(
			$DirectionalLight3D.light_energy, target_light, LERP_SPEED * delta)

	# Tinte de pantalla (esfera unlit en la cámara)
	if _tint_mat:
		var target_alpha: float = ZONE_TINT_ALPHA[cur_zone] if _is_underwater else 0.0
		var uw_col: Color = ZONE_UW_FOG_COLOR[cur_zone]
		var cur: Color = _tint_mat.albedo_color
		_tint_mat.albedo_color = Color(
			lerp(cur.r, uw_col.r, LERP_SPEED * delta),
			lerp(cur.g, uw_col.g, LERP_SPEED * delta),
			lerp(cur.b, uw_col.b, LERP_SPEED * delta),
			lerp(cur.a, target_alpha, LERP_SPEED * delta)
		)

	# Partículas
	if _particle_proc and _particle_mat:
		if _is_underwater:
			_particle_proc.gravity = Vector3(0.0, 0.04, 0.0)
			_particle_proc.emission_box_extents = Vector3(2.5, 1.2, 2.5)
			var mc: Color = ZONE_UW_FOG_COLOR[cur_zone].lightened(0.1)
			mc.a = 0.45
			_particle_mat.albedo_color = mc
			_particle_mat.roughness = 0.95
		else:
			_particle_proc.gravity = Vector3(0.0, -0.2, 0.0)
			_particle_proc.emission_box_extents = Vector3(3.0, 0.8, 3.0)
			_particle_mat.albedo_color = Color(0.80, 0.78, 0.72, 0.18)
			_particle_mat.roughness = 1.0

# =========================================================
# Helpers
# =========================================================
func _zone_from_ratio(r: float) -> int:
	if r < 0.25: return 1
	elif r < 0.50: return 2
	elif r < 0.75: return 3
	else: return 4

func _on_zone_changed(new_zone: int) -> void:
	print("Zona: %d — %s" % [new_zone, WaterManager.get_zone_name()])
	_update_water_zone(new_zone)

# Paleta de superficie del agua por zona (marrón pampeano para watershader2.gdshader)
const WATER_SHALLOW_COLOR: Array[Color] = [
	Color(0.0,  0.0,  0.0,  1.0),
	Color(0.55, 0.44, 0.28, 1.0), # Z1: té con leche claro
	Color(0.47, 0.33, 0.15, 1.0), # Z2: café con leche
	Color(0.36, 0.22, 0.08, 1.0), # Z3: chocolate líquido
	Color(0.28, 0.15, 0.04, 1.0), # Z4: marrón lodo oscuro
]
const WATER_DEEP_COLOR: Array[Color] = [
	Color(0.0,  0.0,  0.0,  1.0),
	Color(0.30, 0.20, 0.08, 1.0), # Z1
	Color(0.24, 0.14, 0.05, 1.0), # Z2
	Color(0.16, 0.09, 0.03, 1.0), # Z3
	Color(0.10, 0.05, 0.01, 1.0), # Z4
]
const WATER_BASE_COLOR: Array[Color] = [
	Color(0.0,  0.0,  0.0,  1.0),
	Color(0.45, 0.35, 0.22, 1.0), # Z1: superficie templada
	Color(0.38, 0.26, 0.12, 1.0), # Z2: tono orgánico
	Color(0.28, 0.16, 0.06, 1.0), # Z3: sedimento espeso
	Color(0.20, 0.10, 0.02, 1.0), # Z4: lodo degradado
]
const WATER_FRESNEL_COLOR: Array[Color] = [
	Color(0.0,  0.0,  0.0,  1.0),
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

func _on_metrics_updated(wqi: float, do_val: float) -> void:
	print("WQI=%.1f  DO=%.2f mg/L" % [wqi, do_val])

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

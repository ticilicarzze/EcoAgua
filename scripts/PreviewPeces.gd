## PreviewPeces.gd
## Escena de previsualización de fauna acuática.
## Ejecutar con F6 (Run Current Scene) en Godot.
##
## CONTROLES DE CÁMARA:
##   Clic derecho + arrastrar   → rotar vista
##   W / S                      → avanzar / retroceder
##   A / D                      → mover izquierda / derecha
##   Q / E                      → bajar / subir
##   Rueda del mouse            → zoom (acercar/alejar)
##   Escape                     → liberar el mouse

extends Node3D

# ── Parámetros de cámara libre ────────────────────────────────────────────────
const MOUSE_SENSITIVITY := 0.003
const MOVE_SPEED := 8.0
const ZOOM_SPEED := 3.0

var _cam: Camera3D
var _yaw: float = 0.0
var _pitch: float = 0.0
var _dragging: bool = false

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_spawn_fish()

# ── Fondo y piso ───────────────────────────────────────────────────────────
func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.11, 0.20)
	env.ambient_light_color = Color(0.35, 0.55, 0.75)
	env.ambient_light_energy = 1.2
	world_env.environment = env
	add_child(world_env)

	# Plano de agua
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(60.0, 60.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.22, 0.38, 0.70)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	plane_mesh.material = mat
	var water := MeshInstance3D.new()
	water.mesh = plane_mesh
	water.position = Vector3.ZERO
	add_child(water)

# ── Iluminación ────────────────────────────────────────────────────────────
func _setup_lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.0
	sun.light_color = Color(0.9, 0.85, 0.7)
	sun.rotation_degrees = Vector3(-50, 20, 0)
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.35
	fill.light_color = Color(0.4, 0.6, 1.0)
	fill.rotation_degrees = Vector3(-15, -130, 0)
	add_child(fill)

# ── Cámara libre ───────────────────────────────────────────────────────────
func _setup_camera() -> void:
	_cam = Camera3D.new()
	_cam.name = "CamaraPreview"
	_cam.fov = 65.0
	_cam.position = Vector3(0, 8, 20)
	_yaw   = 0.0
	_pitch = deg_to_rad(-20.0)
	_cam.rotation = Vector3(_pitch, _yaw, 0.0)
	_cam.current = true
	add_child(_cam)

	# Instrucciones en pantalla
	var label := Label.new()
	label.text = "🖱 Clic derecho + arrastrar: rotar  |  WASD: mover  |  Q/E: bajar/subir  |  Rueda: zoom"
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(1, 1, 1, 0.75)
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.position = Vector2(10, -30)
	var canvas := CanvasLayer.new()
	canvas.add_child(label)
	add_child(canvas)

# ── Input: rotar cámara con clic derecho ──────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _dragging else Input.MOUSE_MODE_VISIBLE
		# Zoom con rueda del mouse
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.position -= _cam.basis.z * ZOOM_SPEED * 0.5
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.position += _cam.basis.z * ZOOM_SPEED * 0.5

	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_yaw   -= motion.relative.x * MOUSE_SENSITIVITY
		_pitch -= motion.relative.y * MOUSE_SENSITIVITY
		_pitch = clamp(_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
		_cam.rotation = Vector3(_pitch, _yaw, 0.0)

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			_dragging = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ── Process: mover cámara con WASD ────────────────────────────────────────
func _process(delta: float) -> void:
	if not _cam:
		return

	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W): dir -= _cam.basis.z
	if Input.is_key_pressed(KEY_S): dir += _cam.basis.z
	if Input.is_key_pressed(KEY_A): dir -= _cam.basis.x
	if Input.is_key_pressed(KEY_D): dir += _cam.basis.x
	if Input.is_key_pressed(KEY_Q): dir -= Vector3.UP
	if Input.is_key_pressed(KEY_E): dir += Vector3.UP

	if dir.length_squared() > 0.0:
		_cam.position += dir.normalized() * MOVE_SPEED * delta

# ── Instanciar peces ──────────────────────────────────────────────────────
func _spawn_fish() -> void:
	var mojarra_scene: PackedScene  = load("res://assets/models/ZONA1/Fauna acuática/Mojarra_animacion.glb")
	var bagre_scene: PackedScene    = load("res://assets/models/ZONA1/Fauna acuática/bagre_animacion.glb")
	var dientudo_scene: PackedScene = load("res://assets/models/ZONA1/Fauna acuática/dientudo_animacion.glb")

	var mojarra_script  = load("res://scripts/MojarraAnimada.gd")
	var bagre_script    = load("res://scripts/BagreAnimado.gd")
	var dientudo_script = load("res://scripts/DientudoAnimado.gd")

	# Mojarras
	for pos: Vector3 in [
		Vector3(-5.0, -1.5,  0.0), Vector3( 2.0, -1.8, -4.0),
		Vector3(-1.0, -1.3,  3.0), Vector3( 5.0, -1.6, -1.0),
	]:
		var fish: Node3D = mojarra_scene.instantiate()
		fish.name = "Mojarra"
		fish.position = pos
		var s: float = randf_range(3.6, 4.0)
		fish.scale = Vector3(s, s, s)
		fish.set_script(mojarra_script)
		add_child(fish)

	# Bagres
	for pos: Vector3 in [
		Vector3(-7.0, -2.2,  2.0), Vector3( 6.0, -2.0, -3.0),
	]:
		var fish: Node3D = bagre_scene.instantiate()
		fish.name = "Bagre"
		fish.position = pos
		var s: float = randf_range(11.0, 12.0)
		fish.scale = Vector3(s, s, s)
		fish.set_script(bagre_script)
		add_child(fish)

	# Dientudos
	for pos: Vector3 in [
		Vector3( 3.0, -2.0,  5.0), Vector3(-4.0, -1.8, -5.0),
	]:
		var fish: Node3D = dientudo_scene.instantiate()
		fish.name = "Dientudo"
		fish.position = pos
		var s: float = randf_range(9.5, 10.8)
		fish.scale = Vector3(s, s, s)
		fish.set_script(dientudo_script)
		add_child(fish)

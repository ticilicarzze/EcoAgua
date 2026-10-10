extends "res://scripts/HUDController.gd"
class_name HUDControllerVR

## HUDControllerVR — EcoAguaUNR
## HUD y pantalla de créditos finales optimizados y proyectados en 3D para Meta Quest 3 (OpenXR).
##
## En VR (OpenXR), Godot no dibuja los CanvasLayer 2D en los lentes del visor.
## Esta clase crea un SubViewport de 1920x1080 con MSAA 4X y un MeshInstance3D (QuadMesh 16:9)
## proyectado en el espacio 3D.
##
## ERGONOMÍA Y PREVENCIÓN DE CINETOSIS (MAREO EN VR):
##   • En HUD normal (Zonas 1-4): Anclado estáticamente al vehículo (UserCart) en CART_HUD_POSITION,
##     permitiendo ver los parámetros como un tablero de instrumentos sin seguir la cabeza.
##   • En Créditos Finales: Implementa la técnica "Lazy Horizon Follow" con Zona Muerta (28°):
##     1. Al iniciar créditos o pulsar un botón, la pantalla se orienta inmediatamente al frente
##        de la mirada actual del usuario a 2.0 m de distancia a la altura de sus ojos.
##     2. Mientras lee (movimientos de cabeza dentro de ±28°), la pantalla queda 100% INMÓVIL en el espacio.
##        Esto preserva el Reflejo Vestíbulo-Ocular (VOR) y evita completamente el mareo por desacople visual.
##     3. Si el usuario gira la cabeza más allá de 28°, la pantalla se desliza suavemente con amortiguamiento
##        exponencial (lerp suave) manteniendo el horizonte estrictamente nivelado (Roll = 0°).
##     4. Tipografía vectorial Saira renderizada en tiempo real con MSAA 4X para nitidez cristalina en Quest 3.

const CART_HUD_POSITION: Vector3    = Vector3(0.0, 0.95, -1.35) # Ubicado ergonómicamente sobre el frente del carrito
const NORMAL_QUAD_SIZE: Vector2     = Vector2(1.8, 1.01)        # Proporción 16:9 optimizada para campo visual
const NORMAL_QUAD_ROTATION: Vector3 = Vector3(-0.244346, 0.0, 0.0) # Inclinación de 14° hacia los ojos (perpendicular a la mirada)

# Parámetros ergonómicos de créditos en VR
const CREDITS_DISTANCE: float     = 2.0          # Distancia focal óptima para lectura relajada en visores
const CREDITS_DEADZONE_DEG: float = 28.0         # Zona muerta: pantalla fija para lectura natural sin mareos
const CREDITS_FOLLOW_SPEED: float = 2.2          # Velocidad de re-centrado suave fuera de la zona muerta
const CREDITS_QUAD_SIZE: Vector2  = Vector2(2.8, 1.575) # Proporción 16:9 cinematográfica a 2.0m

var _sub_viewport: SubViewport       = null
var _mesh_instance: MeshInstance3D   = null
var _is_in_credits_mode: bool        = false
var _credits_quad_yaw: float         = 0.0
var _xr_camera: Node3D               = null

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return

	_is_vr = true

	# ── Estándares ergonómicos y escala visual para VR (Meta Quest 3) ─────────────
	PARAM_FONT_SIZE          = 28   # Subtiende ~1.15° de ángulo visual (estándar de confort Meta)
	TITLE_FONT_SIZE          = 30   # Subtiende ~1.25° de ángulo visual
	ICA_NUM_FONT_SIZE        = 34   # Subtiende ~1.40° de ángulo visual
	PARAM_PANEL_WIDTH        = 540  # Ancho idéntico unificado para ambos paneles en VR
	PARAM_VAL_COL_WIDTH      = 210  # Ancho generoso para valores y unidades ("3.090 UFC/100mL")
	ICA_PANEL_HALF_W         = 270  # 540 px de ancho total (270 * 2), idéntico a ParamPanel
	ICA_BAR_HEIGHT           = 22
	BORDER_WIDTH             = 3
	CORNER_RADIUS            = 12
	MARGIN_BOTTOM            = 45
	VR_PANELS_GAP            = 14.0 # Separación vertical entre paneles apilados en VR

	# Subtítulos VR (deshabilitados en VR para mayor inmersión)
	SUBTITLE_ANCHOR_LEFT     = 0.18
	SUBTITLE_ANCHOR_RIGHT    = 0.82
	SUBTITLE_VOICE_FONT_SIZE = 18
	SUBTITLE_TEXT_FONT_SIZE  = 22
	SUBTITLE_BOTTOM_OFFSET   = 140

	# Botón de sumergirse VR
	DIVE_PANEL_HALF_W        = 260
	DIVE_PANEL_HALF_H        = 58
	DIVE_INTRO_FONT_SIZE     = 20
	DIVE_BTN_FONT_SIZE       = 28
	DIVE_HINT_FONT_SIZE      = 18

	# Cartel grande VR
	CARD_TITLE_FONT_SIZE     = 28
	CARD_PARAM_FONT_SIZE     = 22
	CARD_VAL_FONT_SIZE       = 24
	CARD_ICA_FONT_SIZE       = 22
	CARD_ICA_VAL_FONT_SIZE   = 26

	# ── Configurar SubViewport y MeshInstance3D en 3D ────────────────────────────
	_setup_vr_3d_display()

func _ready() -> void:
	super()
	print("HUDControllerVR: _ready() completado. SubViewport hijos: %d, HUDRoot hijos: %d" % [
		_sub_viewport.get_child_count() if _sub_viewport else 0,
		_root.get_child_count() if _root else 0
	])
	if _root:
		for c in _root.get_children():
			print("  - HUD VR Elemento: %s (visible: %s)" % [c.name, c.visible])

func _setup_vr_3d_display() -> void:
	# 1. Crear el SubViewport que renderizará la UI 2D en textura con Anti-Aliasing de alta calidad
	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "VRHUDViewport"
	_sub_viewport.size = Vector2i(1920, 1080)
	_sub_viewport.transparent_bg = true
	_sub_viewport.msaa_2d = Viewport.MSAA_4X
	if RenderingServer.get_rendering_device():
		_sub_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.handle_input_locally = false
	add_child(_sub_viewport)

	# 2. Crear el MeshInstance3D (Quad 2.4m x 1.35m = 16:9 a 1.6m de distancia para HUD normal)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "VRHUDQuad"
	var quad := QuadMesh.new()
	quad.size = NORMAL_QUAD_SIZE
	_mesh_instance.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	mat.albedo_texture = _sub_viewport.get_texture()
	mat.no_depth_test = true
	mat.render_priority = 10
	_mesh_instance.material_override = mat

	# 3. Conectar cambio de visibilidad del CanvasLayer
	if not visibility_changed.is_connected(_on_layer_visibility_changed):
		visibility_changed.connect(_on_layer_visibility_changed)

	# 4. Anclar el Quad estáticamente al carrito (UserCart / XROrigin3D)
	call_deferred("_attach_quad_to_cart")

func _attach_quad_to_cart() -> void:
	var cart_target: Node3D = get_tree().root.find_child("UserCart", true, false) as Node3D
	if not cart_target:
		cart_target = get_tree().root.find_child("XROrigin3D", true, false) as Node3D

	var should_be_visible: bool = visible or (get_viewport() != null and get_viewport().use_xr)

	if cart_target:
		if _mesh_instance.get_parent():
			_mesh_instance.get_parent().remove_child(_mesh_instance)
		cart_target.add_child(_mesh_instance)
		_mesh_instance.position = CART_HUD_POSITION
		_mesh_instance.rotation = NORMAL_QUAD_ROTATION
		_mesh_instance.visible = should_be_visible
		print("HUDControllerVR: Quad 3D anclado al carrito (%s) en %s (estático respecto al visor, mayor legibilidad)." % [
			cart_target.name, CART_HUD_POSITION
		])
	else:
		var xr_cam := _get_xr_camera()
		if xr_cam:
			if _mesh_instance.get_parent():
				_mesh_instance.get_parent().remove_child(_mesh_instance)
			xr_cam.add_child(_mesh_instance)
			_mesh_instance.position = Vector3(0.0, 0.0, -1.8)
			_mesh_instance.rotation = Vector3.ZERO
			_mesh_instance.visible = should_be_visible
			push_warning("HUDControllerVR: Carrito no encontrado. Anclado como fallback a XRCamera3D.")
		else:
			push_warning("HUDControllerVR: Ni el carrito ni XRCamera3D fueron encontrados para fijar el HUD 3D.")

func _on_layer_visibility_changed() -> void:
	if _mesh_instance:
		_mesh_instance.visible = visible or (get_viewport() != null and get_viewport().use_xr)

func _get_hud_parent() -> Node:
	return _sub_viewport if _sub_viewport else self

# ─── Control de Estados Narrativos en VR ─────────────────────────────────────
func on_narrative_state_changed(state_int: int, zone: int) -> void:
	super(state_int, zone)
	if state_int == 19: # CREDITS
		_enter_credits_mode()
	elif state_int == 0 or state_int == 20: # WAITING_START o DONE
		_exit_credits_mode()

## Inicia el modo de créditos con posicionamiento ergonómico y Lazy Horizon Follow
func _enter_credits_mode() -> void:
	_is_in_credits_mode = true
	if _mesh_instance:
		_mesh_instance.visible = true
		if _mesh_instance.mesh is QuadMesh:
			(_mesh_instance.mesh as QuadMesh).size = CREDITS_QUAD_SIZE
	_recenter_credits_immediately()
	print("HUDControllerVR: Créditos iniciados en modo cine VR (Lazy Horizon Follow). Pantalla re-centrada frente al usuario.")

## Finaliza el modo créditos y restaura la posición del tablero HUD
func _exit_credits_mode() -> void:
	_is_in_credits_mode = false
	if _mesh_instance:
		if _mesh_instance.mesh is QuadMesh:
			(_mesh_instance.mesh as QuadMesh).size = NORMAL_QUAD_SIZE
		_mesh_instance.position = CART_HUD_POSITION
		_mesh_instance.rotation = NORMAL_QUAD_ROTATION

## Re-centra inmediatamente el panel de créditos frente a la mirada actual del usuario
func _recenter_credits_immediately() -> void:
	if not _mesh_instance:
		return
	var cam := _get_xr_camera()
	if cam:
		_credits_quad_yaw = cam.rotation.y
	else:
		_credits_quad_yaw = 0.0

	var px: float = -sin(_credits_quad_yaw) * CREDITS_DISTANCE
	var pz: float = -cos(_credits_quad_yaw) * CREDITS_DISTANCE
	_mesh_instance.position = Vector3(px, 1.25, pz)
	_mesh_instance.rotation = Vector3(0.0, _credits_quad_yaw, 0.0)

## Al avanzar manualmente de diapositiva con el joystick/botón, re-centrar suavemente frente a la vista
func advance_credits_slide() -> void:
	super()
	if _is_in_credits_mode:
		_recenter_credits_immediately()

## Actualización continua en cada fotograma
func _process(delta: float) -> void:
	update_hud_floating(delta)
	if not _is_in_credits_mode or not is_instance_valid(_mesh_instance):
		return

	var cam := _get_xr_camera()
	if not cam:
		return

	# Ángulo yaw actual de la cabeza del usuario
	var head_yaw: float = cam.rotation.y
	var diff: float = wrapf(head_yaw - _credits_quad_yaw, -PI, PI)
	var deadzone_rad: float = deg_to_rad(CREDITS_DEADZONE_DEG)

	# ── ZONA MUERTA (Deadzone de ±28°): ──────────────────────────────────────
	# Dentro de este rango, la pantalla queda 100% INMÓVIL en el espacio 3D.
	# Esto permite que los ojos lean cómodamente y que el Reflejo Vestíbulo-Ocular
	# (VOR) funcione de manera 100% natural sin generar ningún mareo ni cinetosis.
	if abs(diff) > deadzone_rad:
		# Fuera de la zona muerta, la pantalla se desliza suavemente para mantenerse en el campo visual
		var target_yaw: float = head_yaw - sign(diff) * deadzone_rad
		_credits_quad_yaw = lerp_angle(_credits_quad_yaw, target_yaw, CREDITS_FOLLOW_SPEED * delta)
		var px: float = -sin(_credits_quad_yaw) * CREDITS_DISTANCE
		var pz: float = -cos(_credits_quad_yaw) * CREDITS_DISTANCE
		_mesh_instance.position = Vector3(px, 1.25, pz)
		_mesh_instance.rotation = Vector3(0.0, _credits_quad_yaw, 0.0)

func _get_xr_camera() -> Node3D:
	if not is_instance_valid(_xr_camera):
		_xr_camera = get_tree().root.find_child("XRCamera3D", true, false) as Node3D
	return _xr_camera

# ─── Subtítulos en VR ────────────────────────────────────────────────────────
func _build_subtitle_panel() -> void:
	pass

func _show_subtitle(_state_int: int) -> void:
	pass

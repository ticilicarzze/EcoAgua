extends "res://scripts/HUDController.gd"
class_name HUDControllerVR

## HUDControllerVR — EcoAguaUNR
## HUD optimizado y proyectado en 3D para visores de Realidad Virtual (Meta Quest / OpenXR).
##
## En VR (OpenXR), Godot no dibuja los CanvasLayer 2D en los lentes del visor.
## Esta clase crea un SubViewport transparente de 1920x1080 y un MeshInstance3D (QuadMesh 16:9)
## posicionado a 1.8 metros frente a la cámara XR (XRCamera3D), con material Unshaded y sin depth-test
## para que la interfaz flote nítida, sin ser ocluida por el agua ni por los peces.
##
## Además, sobreescribe las variables de tamaño con fuentes notablemente mayores y paneles
## anchos para garantizar una lectura perfectamente cómoda en los visores Quest.

var _sub_viewport: SubViewport = null
var _mesh_instance: MeshInstance3D = null

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_is_vr = true

	# ── Tamaños VR — fuentes ampliadas y paneles optimizados para visores ────────
	PARAM_FONT_SIZE          = 18
	TITLE_FONT_SIZE          = 20
	ICA_NUM_FONT_SIZE        = 22
	PARAM_PANEL_WIDTH        = 380
	PARAM_VAL_COL_WIDTH      = 130
	ICA_PANEL_HALF_W         = 240
	ICA_BAR_HEIGHT           = 14
	BORDER_WIDTH             = 3
	CORNER_RADIUS            = 14
	MARGIN_SCREEN            = 60
	MARGIN_BOTTOM            = 50

	# Subtítulos VR
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

	# Créditos VR
	CREDITS_TITLE_FONT_SIZE  = 36
	CREDITS_SUB_FONT_SIZE    = 22
	CREDITS_BODY_FONT_SIZE   = 18

	# ── Configurar SubViewport y MeshInstance3D en 3D ────────────────────────────
	_setup_vr_3d_display()

	# ── Construir la interfaz (los controles se agregarán a _sub_viewport) ───────
	super._ready()

func _setup_vr_3d_display() -> void:
	# 1. Crear el SubViewport que renderizará la UI 2D en textura
	_sub_viewport = SubViewport.new()
	_sub_viewport.name = "VRHUDViewport"
	_sub_viewport.size = Vector2i(1920, 1080)
	_sub_viewport.transparent_bg = true
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_sub_viewport.handle_input_locally = false
	add_child(_sub_viewport)

	# 2. Crear el MeshInstance3D (Quad 2.4m x 1.35m = 16:9 a 1.8m de distancia)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "VRHUDQuad"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 1.35)
	_mesh_instance.mesh = quad

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _sub_viewport.get_texture()
	mat.no_depth_test = true
	mat.render_priority = 10
	_mesh_instance.material_override = mat

	# 3. Conectar cambio de visibilidad del CanvasLayer
	if not visibility_changed.is_connected(_on_layer_visibility_changed):
		visibility_changed.connect(_on_layer_visibility_changed)

	# 4. Anclar el Quad a la XRCamera3D
	call_deferred("_attach_quad_to_xr_camera")

func _attach_quad_to_xr_camera() -> void:
	var xr_cam = get_tree().root.find_child("XRCamera3D", true, false)
	if xr_cam:
		if _mesh_instance.get_parent():
			_mesh_instance.get_parent().remove_child(_mesh_instance)
		xr_cam.add_child(_mesh_instance)
		_mesh_instance.position = Vector3(0.0, 0.0, -1.8)
		_mesh_instance.rotation = Vector3.ZERO
		_mesh_instance.visible = visible
		print("HUDControllerVR: Quad 3D anclado a XRCamera3D (distancia 1.8m, tamaño 2.4x1.35m).")
	else:
		push_warning("HUDControllerVR: XRCamera3D no encontrada para anclar el HUD 3D.")

func _on_layer_visibility_changed() -> void:
	if _mesh_instance:
		_mesh_instance.visible = visible

func _get_hud_parent() -> Node:
	return _sub_viewport if _sub_viewport else self

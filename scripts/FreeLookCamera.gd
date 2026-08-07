# FreeLookCamera.gd
# Control de cámara libre para modo flat/web (sin headset VR).
# Se agrega como hijo directo del nodo Main y apunta la cámara correctamente.
#
# CONTROLES:
#   Mouse izquierdo o derecho (mantener) + mover   → girar vista
#   Flechas / W A S D                              → girar vista con teclado
#   Escape                                          → liberar cursor
extends Node

@export var mouse_sensitivity: float = 0.003
@export var key_speed: float = 1.8
@export var pitch_limit: float = 80.0

var _yaw: float   = 0.0
var _pitch: float = 0.0
var _dragging: bool = false
var _camera: Camera3D = null

func setup(_origin: Node3D, camera: Camera3D) -> void:
	_camera = camera
	if not _camera:
		push_warning("FreeLookCamera: cámara no válida.")
		return
	# Inicializar yaw/pitch desde la rotación actual local de la cámara
	_yaw   = 0.0
	_pitch = 0.0
	print("FreeLookCamera: inicializada en '", _camera.name, "'.")

func _input(event: InputEvent) -> void:
	if not _camera:
		return

	# Activar arrastre con clic izquierdo o derecho
	if event is InputEventMouseButton:
		var btn := (event as InputEventMouseButton).button_index
		if btn == MOUSE_BUTTON_LEFT or btn == MOUSE_BUTTON_RIGHT:
			_dragging = (event as InputEventMouseButton).pressed
			if not _dragging:
				# Al soltar el mouse, dejar cursor visible
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Rotar con movimiento de mouse mientras se arrastra
	if event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_yaw   -= motion.relative.x * mouse_sensitivity
		_pitch -= motion.relative.y * mouse_sensitivity
		_apply_rotation()
		get_viewport().set_input_as_handled()

	# Escape: liberar cursor
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE:
			_dragging = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if not _camera:
		return

	var turning  := 0.0
	var pitching := 0.0

	if Input.is_key_pressed(KEY_LEFT)  or Input.is_key_pressed(KEY_A):
		turning += key_speed * delta
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		turning -= key_speed * delta
	if Input.is_key_pressed(KEY_UP)    or Input.is_key_pressed(KEY_W):
		pitching += key_speed * delta
	if Input.is_key_pressed(KEY_DOWN)  or Input.is_key_pressed(KEY_S):
		pitching -= key_speed * delta

	if turning != 0.0 or pitching != 0.0:
		_yaw   += turning
		_pitch += pitching
		_apply_rotation()

func _apply_rotation() -> void:
	_pitch = clamp(_pitch, deg_to_rad(-pitch_limit), deg_to_rad(pitch_limit))
	# Rotamos la cámara en coordenadas LOCALES para que respete la orientación del PathFollow3D
	_camera.rotation = Vector3(_pitch, _yaw, 0.0)

# FreeLookCamera.gd
# Controla la TestCamera en modo flat/web (sin headset VR).
# Permite girar la cámara como si fuera un visor usando:
#   - Arrastrar con botón DERECHO del mouse  → mirar a los costados / arriba-abajo
#   - Flechas izquierda/derecha              → girar horizontalmente (yaw)
#   - Flechas arriba/abajo                   → inclinar verticalmente (pitch)
extends Node

## Velocidad de giro con mouse (radianes por pixel)
@export var mouse_sensitivity: float = 0.003
## Velocidad de giro con teclado (radianes por segundo)
@export var key_speed: float = 1.5
## Límite vertical de inclinación (grados)
@export var pitch_limit: float = 80.0

var _yaw: float   = 0.0
var _pitch: float = 0.0
var _dragging: bool = false

# Referencia a la cámara activa en flat mode
var _camera: Camera3D = null

func setup(_origin: Node3D, camera: Camera3D) -> void:
	# _origin se ignora; rotamos solo la cámara con Euler acumulado
	_camera = camera
	# Tomamos la rotación actual de la cámara como punto de partida
	_yaw   = _camera.global_rotation.y
	_pitch = _camera.global_rotation.x

func _input(event: InputEvent) -> void:
	if not _camera:
		return

	# --- Botón derecho del mouse: activar/desactivar arrastre ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _dragging else Input.MOUSE_MODE_VISIBLE

	# --- Movimiento del mouse mientras se arrastra ---
	if event is InputEventMouseMotion and _dragging:
		_yaw   -= event.relative.x * mouse_sensitivity
		_pitch -= event.relative.y * mouse_sensitivity
		_apply_rotation()

func _process(delta: float) -> void:
	if not _camera:
		return

	var turning  := 0.0
	var pitching := 0.0

	if Input.is_key_pressed(KEY_LEFT):
		turning += key_speed * delta
	if Input.is_key_pressed(KEY_RIGHT):
		turning -= key_speed * delta
	if Input.is_key_pressed(KEY_UP):
		pitching += key_speed * delta
	if Input.is_key_pressed(KEY_DOWN):
		pitching -= key_speed * delta

	if turning != 0.0 or pitching != 0.0:
		_yaw   += turning
		_pitch += pitching
		_apply_rotation()

func _apply_rotation() -> void:
	_pitch = clamp(_pitch, deg_to_rad(-pitch_limit), deg_to_rad(pitch_limit))
	# Aplicamos la rotación directamente en coordenadas globales
	# para que no interfiera con el PathFollow3D
	_camera.global_rotation = Vector3(_pitch, _yaw, 0.0)

## PezAnimado.gd
## Clase base para el nado en óvalo continuo y fluido de la fauna acuática.

class_name PezAnimado
extends Node3D

# ── Óvalo de patrulla ────────────────────────────────────────────────────────
@export var patrol_range_x: float = 3.0    ## Semieje lateral del óvalo (m)
@export var patrol_range_z: float = 6.0    ## Semieje longitudinal del óvalo (m)
@export var patrol_speed:   float = 0.22   ## Velocidad de avance por el óvalo (rad/s)
@export var turn_speed:     float = 2.0    ## Suavidad de giro (menor = giro más amplio y fluido)

# ── Coletazo y flote ─────────────────────────────────────────────────────────
@export var swim_amplitude: float = 0.12   ## Amplitud del coletazo lateral (m)
@export var swim_frequency: float = 0.40   ## Frecuencia del coletazo (Hz)
@export var bob_amplitude:  float = 0.04   ## Amplitud del flote vertical (m)
@export var bob_frequency:  float = 0.60   ## Frecuencia del flote (Hz)

# ── Corrección del Modelo ───────────────────────────────────────────────────
@export var model_yaw_offset_deg: float = 0.0 ## Offset en grados para alinear la cabeza hacia adelante
@export var pivot_offset: Vector3 = Vector3.ZERO

# ── Estado interno ───────────────────────────────────────────────────────────
var _anim_player: AnimationPlayer = null
var _origin: Vector3
var _base_scale: Vector3 = Vector3.ONE
var _time: float = 0.0
var _phase: float = 0.0
var _is_initialized: bool = false

func _ready() -> void:
	if _is_initialized:
		return
	_is_initialized = true

	_base_scale = scale
	_phase = randf() * TAU
	_origin = global_position

	_setup_species_params()

	if pivot_offset != Vector3.ZERO:
		for child in get_children():
			child.position += pivot_offset

	_start_animation()

## Método virtual para configurar parámetros por especie
func _setup_species_params() -> void:
	pass

func _start_animation() -> void:
	_anim_player = _find_animation_player(self)
	if _anim_player:
		var anim_list := _anim_player.get_animation_list()
		var real_anims: Array[String] = []
		for a in anim_list:
			if a != "RESET":
				real_anims.append(a)
		var anim_name: String = real_anims[0] if real_anims.size() > 0 \
			else (anim_list[0] if anim_list.size() > 0 else "")
		if anim_name != "":
			_anim_player.play(anim_name)
			var anim := _anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
	else:
		push_warning("[%s]: AnimationPlayer no encontrado." % name)

func _process(delta: float) -> void:
	_time += delta

	# 1. Ángulo continuo sobre el óvalo (inicia exactamente en la posición del editor)
	var angle: float = _time * patrol_speed + _phase

	var px: float = patrol_range_x * (cos(angle) - cos(_phase))
	var pz: float = patrol_range_z * (sin(angle) - sin(_phase))

	# 2. Coletazo lateral + flote vertical
	var swim_phase: float = _time * swim_frequency * TAU + _phase
	var sx: float = sin(swim_phase) * swim_amplitude
	var sy: float = sin(_time * bob_frequency * TAU + _phase * 0.5) * bob_amplitude

	global_position = _origin + Vector3(px + sx, sy, pz)

	# 3. Tangente analítica del óvalo (avance hacia adelante)
	var vx: float = -patrol_range_x * sin(angle) * patrol_speed
	var vz: float =  patrol_range_z * cos(angle) * patrol_speed

	var base_yaw: float = atan2(vx, vz)
	var target_yaw: float = base_yaw + deg_to_rad(model_yaw_offset_deg)

	# 4. Giro fluido e interpolación angular continua solo en el eje Y
	var weight: float = 1.0 - exp(-turn_speed * delta)
	var current_scale: Vector3 = scale
	var new_yaw: float = lerp_angle(rotation.y, target_yaw, weight)
	rotation = Vector3(0.0, new_yaw, 0.0)
	scale = current_scale

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null

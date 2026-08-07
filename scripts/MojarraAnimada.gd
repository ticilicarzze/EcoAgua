## MojarraAnimada.gd
## Reproduce la animación de aleta del GLB y añade movimiento en dos capas:
##   1. Patrulla elíptica a velocidad angular constante → sin frenadas ni trabones.
##   2. Micro-oscilación de nado (coletazo lateral + flote vertical).
## La rotación se calcula desde la tangente analítica de la elipse,
## por lo que nunca hay jitter al cambiar de dirección.

extends Node3D

# ── Patrulla elíptica ────────────────────────────────────────────────────────
@export var patrol_range_x: float = 2.5   ## Semieje X de la elipse (m)
@export var patrol_range_z: float = 3.5   ## Semieje Z de la elipse (m, a lo largo del río)
@export var patrol_speed:   float = 0.28  ## Velocidad angular (rad/s) — ~22 s por vuelta
@export var turn_speed:     float = 4.0   ## Velocidad de rotación (mayor = más ágil)

# ── Micro-oscilación de nado ─────────────────────────────────────────────────
@export var swim_amplitude: float = 0.10  ## Amplitud del coletazo lateral (m)
@export var swim_frequency: float = 0.45  ## Frecuencia del coletazo (Hz)
@export var bob_amplitude:  float = 0.04  ## Amplitud del flote vertical (m)
@export var bob_frequency:  float = 0.80  ## Frecuencia del flote (Hz)

# ── Corrección de pivot del GLB ──────────────────────────────────────────────
@export var pivot_offset: Vector3 = Vector3.ZERO

# ── Estado interno ───────────────────────────────────────────────────────────
var _anim_player: AnimationPlayer = null
var _origin: Vector3
var _time: float = 0.0
var _phase: float = 0.0   # ángulo inicial único por instancia

func _ready() -> void:
	_phase = randf() * TAU   # cada pez arranca en un punto distinto de la elipse
	_origin = global_position

	if pivot_offset != Vector3.ZERO:
		for child in get_children():
			child.position += pivot_offset

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
			print("PezAnimado [%s]: animación '%s' en bucle." % [name, anim_name])
		else:
			push_warning("PezAnimado [%s]: GLB sin animaciones." % name)
	else:
		push_warning("PezAnimado [%s]: AnimationPlayer no encontrado." % name)

func _process(delta: float) -> void:
	_time += delta

	# ── 1. Patrulla elíptica ─────────────────────────────────────────────────
	# Ángulo avanza a velocidad constante → sin zonas de velocidad cero.
	var angle: float = _time * patrol_speed + _phase

	var px: float = patrol_range_x * cos(angle)
	var pz: float = patrol_range_z * sin(angle)

	# ── 2. Micro-oscilación de nado (se suma a la posición de patrulla) ───────
	var sx: float = sin(_time * swim_frequency * TAU + _phase) * swim_amplitude
	var sy: float = sin(_time * bob_frequency  * TAU + _phase * 0.5) * bob_amplitude

	global_position = _origin + Vector3(px + sx, sy, pz)

	# ── 3. Rotación por tangente analítica de la elipse ───────────────────────
	# d/dθ [Rx·cos(θ)] = -Rx·sin(θ)   d/dθ [Rz·sin(θ)] = Rz·cos(θ)
	# → tangente siempre definida, nunca ambigua ni con longitud cero.
	var tx: float = -patrol_range_x * sin(angle) * patrol_speed
	var tz: float =  patrol_range_z * cos(angle) * patrol_speed
	var target_yaw: float = atan2(tx, tz)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

# ── Búsqueda recursiva del AnimationPlayer ────────────────────────────────────
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null

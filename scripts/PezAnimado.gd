class_name PezAnimado
extends Node3D

# ── Óvalo de patrulla ────────────────────────────────────────────────────────
@export var patrol_range_x: float = 3.0 ## Semieje lateral del óvalo (m)
@export var patrol_range_z: float = 6.0 ## Semieje longitudinal del óvalo (m)
@export var patrol_speed: float = 0.22 ## Velocidad de avance por el óvalo (rad/s)
@export var turn_speed: float = 2.0 ## Suavidad de giro (menor = giro más amplio y fluido)

# ── Coletazo y flote ─────────────────────────────────────────────────────────
@export var swim_amplitude: float = 0.12 ## Amplitud del coletazo lateral (m)
@export var swim_frequency: float = 0.40 ## Frecuencia del coletazo (Hz)
@export var bob_amplitude: float = 0.04 ## Amplitud del flote vertical (m)
@export var bob_frequency: float = 0.60 ## Frecuencia del flote (Hz)

# ── Corrección del Modelo ───────────────────────────────────────────────────
@export var model_yaw_offset_deg: float = 0.0 ## Offset en grados para alinear la cabeza hacia adelante
@export var pivot_offset: Vector3 = Vector3.ZERO

# ── Evitación de Paredes / Cauce con Inclinación Real (Talud 1:1) ────────────
@export var surface_river_radius: float = 11.5 ## Radio del río en la superficie Y=0 (m)
@export var bed_river_radius: float = 9.0 ## Radio del río en el fondo Y<=-2.5 (m)
@export var wall_avoid_margin: float = 0.10 ## Inicia el giro exactamente a 10cm (0.10m) de la pared
@export var body_radius_offset: float = 0.0 ## Margen preventivo por tamaño del cuerpo del pez (m)
@export var wall_inward_bias: float = 0.55 ## Fuerza del ángulo de giro hacia el centro del río
@export var wall_deflection_strength: float = 0.85 ## Intensidad máxima de viraje en pared
@export var wall_boost_multiplier: float = 1.0 ## Impulso de velocidad tras girar en la pared (1.0 = normal/sin impulso)

# ── Estado interno ───────────────────────────────────────────────────────────
var _anim_player: AnimationPlayer = null
var _river_curve: Curve3D = null
var _origin: Vector3
var _base_scale: Vector3 = Vector3.ONE
var _time: float = 0.0
var _phase: float = 0.0
var _current_angle: float = 0.0
var _is_initialized: bool = false
var _boost_timer: float = 0.0

func _ready() -> void:
	if _is_initialized:
		return
	_is_initialized = true

	_phase = randf() * TAU
	_current_angle = _phase
	_origin = global_position

	_setup_species_params()

	var sx: float = abs(scale.x)
	var sy: float = abs(scale.y)
	var sz: float = abs(scale.z)
	_base_scale = Vector3(
		sx if sx > 0.001 else 1.0,
		sy if sy > 0.001 else 1.0,
		sz if sz > 0.001 else 1.0
	)
	scale = _base_scale

	if pivot_offset != Vector3.ZERO:
		for child in get_children():
			child.position += pivot_offset

	# Orientación inicial tangente
	var vx: float = - patrol_range_x * sin(_phase) * patrol_speed
	var vz: float = patrol_range_z * cos(_phase) * patrol_speed
	var base_yaw: float = atan2(vx, vz)
	var initial_yaw: float = base_yaw + deg_to_rad(model_yaw_offset_deg)
	rotation = Vector3(0.0, initial_yaw, 0.0)

	_start_animation()
	set_process(true)

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

func _find_river_curve() -> void:
	var path_node = get_node_or_null("/root/Main/RiverPath") as Path3D
	if path_node and path_node.curve:
		_river_curve = path_node.curve

func _process(delta: float) -> void:
	_time += delta

	# 1. Velocidad efectiva con impulso de giro suave y continuo
	var current_speed: float = patrol_speed
	if _boost_timer > 0.0:
		_boost_timer -= delta
		var boost_decay: float = clamp(_boost_timer / 2.0, 0.0, 1.0)
		current_speed += patrol_speed * (wall_boost_multiplier - 1.0) * boost_decay

	_current_angle += current_speed * delta

	# 2. Óvalo continuo sin saltos de centro
	var px: float = patrol_range_x * cos(_current_angle)
	var pz: float = patrol_range_z * sin(_current_angle)

	# 3. Coletazo lateral orgánico + flote vertical
	var swim_phase: float = _time * swim_frequency * TAU + _phase
	var sx: float = sin(swim_phase) * swim_amplitude
	var sy: float = sin(_time * bob_frequency * TAU + _phase * 0.5) * bob_amplitude

	var raw_pos: Vector3 = _origin + Vector3(px + sx, sy, pz)

	# 4. Tangente instantánea matemática
	var vx: float = - patrol_range_x * sin(_current_angle) * current_speed
	var vz: float = patrol_range_z * cos(_current_angle) * current_speed

	# 5. Deflexión orgánica en orillas guiada por la curvatura e inclinación real del río
	if _river_curve == null:
		_find_river_curve()

	var target_yaw_offset: float = 0.0
	var turn_rate: float = turn_speed

	if _river_curve != null:
		var closest_off: float = _river_curve.get_closest_offset(raw_pos)
		var center_pos: Vector3 = _river_curve.sample_baked(closest_off)
		
		var diff: Vector3 = raw_pos - center_pos
		var dist_2d: float = Vector2(diff.x, diff.z).length()

		# Cálculo del radio límite según la inclinación real del talud del río (Y=0 -> 11.5m, Y=-2.5 -> 9.0m)
		var current_depth_y: float = raw_pos.y
		var max_river_width_radius: float = clamp(surface_river_radius + current_depth_y, bed_river_radius, surface_river_radius)
		var effective_max_radius: float = max_river_width_radius - body_radius_offset
		var start_avoid: float = effective_max_radius - wall_avoid_margin

		if dist_2d > start_avoid:
			var factor: float = clamp((dist_2d - start_avoid) / max(wall_avoid_margin, 0.01), 0.0, 1.0)
			
			# Vector hacia el interior del cauce
			var inward_dir: Vector2 = Vector2(center_pos.x - raw_pos.x, center_pos.z - raw_pos.z).normalized()
			
			# Tangente local del río
			var p_ahead: Vector3 = _river_curve.sample_baked(closest_off + 1.0)
			var p_back: Vector3 = _river_curve.sample_baked(closest_off - 1.0)
			var river_tangent: Vector2 = Vector2(p_ahead.x - p_back.x, p_ahead.z - p_back.z).normalized()
			
			# Dirección de flujo concordante con el avance del pez
			var move_dir: Vector2 = Vector2(vx, vz).normalized()
			var flow_dir: Vector2 = river_tangent if move_dir.dot(river_tangent) >= 0.0 else -river_tangent
			
			# Trayectoria deseada: continúa a lo largo del río con viraje hacia el cauce central
			# Variación individual natural para que el cardumen mantenga dispersión orgánica
			var natural_scatter: float = sin(_current_angle * 2.0 + _phase) * 0.15
			var flow_weight: float = clamp(1.0 - wall_inward_bias * 0.4, 0.2, 1.0)
			var desired_dir: Vector2 = (flow_dir * flow_weight + inward_dir * (wall_inward_bias + natural_scatter)).normalized()
			var desired_yaw: float = atan2(desired_dir.x, desired_dir.y)
			
			var move_heading: float = atan2(vx, vz)
			var diff_yaw: float = wrapf(desired_yaw - move_heading, -PI, PI)
			target_yaw_offset = diff_yaw * clamp(factor * wall_deflection_strength, 0.0, 1.0)

			# Giro ágil y fluido al entrar en el margen
			turn_rate = lerp(turn_speed, turn_speed * 2.5, factor)

			# Activar impulso de velocidad si la especie lo tiene configurado
			if wall_boost_multiplier > 1.0 and factor > 0.35:
				_boost_timer = 2.0

			# Empuje suave de orilla respetando el límite exacto y el grosor del cuerpo del pez
			if dist_2d > effective_max_radius:
				var push: float = dist_2d - effective_max_radius
				raw_pos.x += inward_dir.x * push * 0.95
				raw_pos.z += inward_dir.y * push * 0.95
	else:
		var clamped_x: float = clamp(raw_pos.x, -5.0, 5.0)
		raw_pos.x = lerp(raw_pos.x, clamped_x, 0.5)

	global_position = raw_pos

	# 6. Rotación fluida y orientada
	var base_yaw: float = atan2(vx, vz)
	var target_yaw: float = base_yaw + deg_to_rad(model_yaw_offset_deg) + target_yaw_offset

	rotation.y = lerp_angle(rotation.y, target_yaw, clamp(delta * turn_rate, 0.0, 1.0))
	scale = _base_scale

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null

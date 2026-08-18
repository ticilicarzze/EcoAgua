## MojarraAnimada.gd
## Nado en óvalo para la Mojarra. La escala se configura directamente en el editor.

class_name MojarraAnimada
extends PezAnimado

func _setup_species_params() -> void:
	# 1. Identificador único por Banco (tomado del nodo contenedor 'Banco1', 'Banco2', etc.)
	var parent_node: Node = get_parent()
	var group_hash: int = parent_node.get_instance_id() if parent_node else 0

	var group_rng := RandomNumberGenerator.new()
	group_rng.seed = group_hash

	# 2. Trayectoria única del Banco (radio y velocidad propia de este grupo)
	var radius: float = group_rng.randf_range(1.8, 2.6)
	patrol_range_x = radius
	patrol_range_z = radius

	# Velocidad de nado por banco (3.0x la velocidad del bagre: 0.16 * 3.0 = 0.48 rad/s)
	var base_mojarra_speed: float = 0.16 * 3.0
	patrol_speed = base_mojarra_speed * group_rng.randf_range(0.95, 1.05)
	turn_speed = 4.0
	wall_boost_multiplier = 2.0 ## Aceleración rápida exclusiva tras virar en la pared

	# 3. Variación individual natural para los peces del MISMO banco
	# Fase escalonada individualmente alrededor de la órbita para evitar agrupamientos
	var base_group_phase: float = group_rng.randf() * TAU
	_phase = base_group_phase + randf_range(-0.85, 0.85)

	# Micro-variaciones individuales para que los coletazos no sean copias robóticas
	swim_amplitude = randf_range(0.07, 0.10)
	swim_frequency = randf_range(0.85, 1.00) ## Coletazo muy rápido y vibrante (~3x frecuencia del bagre)
	bob_amplitude = randf_range(0.02, 0.04)
	bob_frequency = randf_range(0.60, 0.80)
	model_yaw_offset_deg = 0.0

	# 4. Garantizar que cada mojarra mantenga una escala entre 3.6 y 4.0
	var avg_s: float = (abs(scale.x) + abs(scale.y) + abs(scale.z)) / 3.0
	if avg_s < 3.5 or avg_s > 4.1:
		var s: float = randf_range(3.6, 4.0)
		scale = Vector3(s, s, s)

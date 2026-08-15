## BagreAnimado.gd
## Nado en óvalo para el Bagre con escala aleatoria entre 11.0 y 12.0.

class_name BagreAnimado
extends PezAnimado

func _setup_species_params() -> void:
	patrol_range_x = 4.5
	patrol_range_z = 8.5
	patrol_speed   = 0.16
	turn_speed     = 1.2
	swim_amplitude = 0.14
	swim_frequency = 0.32
	bob_amplitude  = 0.05
	bob_frequency  = 0.45
	model_yaw_offset_deg = -90.0

	# Escala aleatoria para cada bagre entre 11.0 y 12.0
	var s: float = randf_range(11.0, 12.0)
	scale = Vector3(s, s, s)

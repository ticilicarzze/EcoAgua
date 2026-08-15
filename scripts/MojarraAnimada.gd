## MojarraAnimada.gd
## Nado en óvalo para la Mojarra. La escala se configura directamente en el editor.

class_name MojarraAnimada
extends PezAnimado

func _setup_species_params() -> void:
	patrol_range_x = 2.5
	patrol_range_z = 3.5
	patrol_speed   = 0.28
	turn_speed     = 3.5
	swim_amplitude = 0.10
	swim_frequency = 0.45
	bob_amplitude  = 0.04
	bob_frequency  = 0.80
	model_yaw_offset_deg = 0.0
	# La escala de cada individuo se respeta tal como está en la escena/editor.

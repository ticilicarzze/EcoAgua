## DientudoAnimado.gd
## Nado en óvalo para el Dientudo. La escala se configura directamente en el editor.

class_name DientudoAnimado
extends PezAnimado

func _setup_species_params() -> void:
	patrol_range_x = 4.0
	patrol_range_z = 9.5
	patrol_speed   = 0.16 * 1.3 ## 1.3x la velocidad de los bagres (0.208 rad/s)
	turn_speed     = 1.8
	swim_amplitude = 0.16
	swim_frequency = 0.32 * 1.3 ## Frecuencia de coletazo proporcional (0.416 Hz)
	bob_amplitude  = 0.05
	bob_frequency  = 0.55
	model_yaw_offset_deg = -90.0
	# La escala de cada individuo se respeta tal como está en la escena/editor.

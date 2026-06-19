extends Node3D

@onready var cart = $RiverPath/UserCart

@export var speed: float = 2.0

func _ready() -> void:
	# Buscamos si hay una interfaz de OpenXR disponible en la PC
	var xr_interface = XRServer.find_interface("OpenXR")
	
	if xr_interface and xr_interface.is_initialized():
		# Si el casco está conectado y andando, activamos el visor VR
		get_viewport().use_xr = true
		print("XR Mode: Headset detected and running!")
	else:
		# Si no hay casco, Godot corre en la pantalla de la compu normalmente
		print("XR Mode: No headset detected. Running in Flat Mode for testing.")
	
	# Connect to WaterManager signals for validation
	WaterManager.zone_changed.connect(_on_zone_changed)
	WaterManager.metrics_updated.connect(_on_metrics_updated)

func _process(delta: float) -> void:
	# El movimiento por los rieles sigue funcionando igual en PC o en VR
	cart.progress += speed * delta
	
	# Update the centralized manager with our current progress
	WaterManager.progress_ratio = cart.progress_ratio
	
	if cart.progress_ratio >= 1.0:
		set_process(false)
		print("Reached the end of the experience")

func _on_zone_changed(new_zone: int) -> void:
	print("Zone Changed to: ", new_zone, " - ", WaterManager.get_zone_name())

func _on_metrics_updated(wqi: float, do: float) -> void:
	# We can print updates to verify linear interpolation of metrics during testing
	print("Metrics Update: WQI = %.1f, DO = %.2f mg/L" % [wqi, do])


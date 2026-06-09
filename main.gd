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

func _process(delta: float) -> void:
	# El movimiento por los rieles sigue funcionando igual en PC o en VR
	cart.progress += speed * delta
	
	if cart.progress_ratio >= 1.0:
		set_process(false)
		print("Reached the end of the experience")

## BagreAnimado.gd
## Nado en óvalo para el Bagre con escala aleatoria entre 11.0 y 12.0.

class_name BagreAnimado
extends PezAnimado

## ── Visibilidad del Material ──────────────────────────────────────────────────
@export_group("Visibilidad del Material")
## Brillo propio del modelo para destacar bajo el agua (0 = normal, 0.25 = recomendado)
@export var auto_brillo: Color = Color(0.25, 0.25, 0.25)

## ── Comportamiento Zona 4 / Estático ──────────────────────────────────────────
@export_group("Zona 4 / Estático")
## Fuerza comportamiento estático manteniendo la posición y rotación 3D del editor
@export var forzar_estatico: bool = false
## Velocidad de reproducción de animación en Zona 4 (0.70 = aleteo suave y orgánico de cola)
@export var anim_speed_zona4: float = 0.70
## Oscilación vertical opcional en metros (0.0 = quieto absoluto respetando el editor 3D exacto)
@export var micro_flote: float = 0.0

## ── Aleteo de Cola (Zonas 3 y 4) ──────────────────────────────────────────────
@export_group("Aleteo de Cola")
## Activa el aleteo suave de cola para evitar que los bagres parezcan estáticos
@export var aleteo_activo: bool = true
## Amplitud del aleteo lateral de la cola en grados
@export var aleteo_amplitud_grados: float = 4.0
## Frecuencia del aleteo de cola en Hz (0.25 Hz = 1 aleteo cada 4 segundos)
@export var aleteo_frecuencia: float = 0.25
## Velocidad de la animación del modelo en Zona 3 (0.75 = aleteo pausado y natural)
@export var anim_speed_zona3: float = 0.75

var _es_estatico_zona4: bool = false
var _es_zona_3: bool = false
var _initial_transform: Transform3D

## Detecta si este bagre pertenece a la Zona 4 (por jerarquía de nodos o Z <= -210m)
func _detectar_zona_4() -> bool:
	if forzar_estatico:
		return true
	var curr: Node = self
	while curr != null:
		if curr.name.to_lower() == "zona4":
			return true
		curr = curr.get_parent()
	return global_position.z <= -210.0

## Detecta si este bagre pertenece a la Zona 3 (por jerarquía o Z entre -140m y -210m)
func _detectar_zona_3() -> bool:
	var curr: Node = self
	while curr != null:
		if curr.name.to_lower() == "zona3":
			return true
		curr = curr.get_parent()
	var z := global_position.z
	return z <= -140.0 and z > -210.0

func _setup_species_params() -> void:
	if _detectar_zona_4():
		patrol_range_x = 0.0
		patrol_range_z = 0.0
		patrol_speed = 0.0
		swim_amplitude = 0.0
		bob_amplitude = 0.0
		turn_speed = 0.0
		return

	patrol_range_x = 4.5
	patrol_range_z = 8.5
	patrol_speed = 0.16 ## Velocidad base (Bagre - 1.0x)
	turn_speed = 1.2
	swim_amplitude = 0.14
	swim_frequency = 0.32
	bob_amplitude = 0.05
	bob_frequency = 0.45
	model_yaw_offset_deg = -90.0
	body_radius_offset = 0.70 ## Compensación por el gran tamaño del cuerpo del bagre (evita que medio cuerpo entre a la pared)
	wall_avoid_margin = 0.85 ## Inicia el giro con anticipación
	wall_inward_bias = 0.85 ## Gira con mayor amplitud de grados hacia el centro del río
	wall_deflection_strength = 1.0 ## Viraje completo hacia el interior
	turn_speed = 1.6 ## Giro más ágil y fluido en virajes de orilla

	# Reducción a 0.7x de velocidad en Zona 3 (Z <= -140.0)
	if global_position.z <= -140.0:
		patrol_speed *= 0.7 ## 0.112 rad/s
		swim_frequency *= 0.7 ## 0.224 Hz

func _ready() -> void:
	_es_estatico_zona4 = _detectar_zona_4()
	if _es_estatico_zona4:
		if _is_initialized:
			return
		_is_initialized = true
		_initial_transform = transform
		_origin = global_position
		_phase = randf() * TAU
		_setup_species_params()
		_start_animation()
		if _anim_player:
			if anim_speed_zona4 <= 0.0:
				_anim_player.pause()
			else:
				_anim_player.speed_scale = anim_speed_zona4
				if _anim_player.current_animation_length > 0.0:
					_anim_player.seek(randf() * _anim_player.current_animation_length, true)
		_ajustar_brillo_material()
		transform = _initial_transform
		set_process(true)
		return

	_es_zona_3 = _detectar_zona_3()
	super._ready()
	_ajustar_brillo_material()

	if _es_zona_3 and _anim_player:
		_anim_player.speed_scale = anim_speed_zona3
		if _anim_player.current_animation_length > 0.0:
			_anim_player.seek(randf() * _anim_player.current_animation_length, true)

func _process(delta: float) -> void:
	if _es_estatico_zona4:
		_time += delta
		if aleteo_activo:
			var flutter := sin(_time * aleteo_frecuencia * TAU + _phase) * deg_to_rad(aleteo_amplitud_grados)
			transform.basis = _initial_transform.basis.rotated(_initial_transform.basis.y.normalized(), flutter)
		else:
			transform.basis = _initial_transform.basis

		if micro_flote > 0.0:
			var flote := Vector3(0.0, sin(_time * 0.8) * micro_flote, 0.0)
			transform.origin = _initial_transform.origin + flote
		else:
			transform.origin = _initial_transform.origin
		return

	super._process(delta)

	if _es_zona_3 and aleteo_activo:
		var flutter := sin(_time * aleteo_frecuencia * TAU + _phase) * deg_to_rad(aleteo_amplitud_grados)
		rotation.y += flutter

## Aplica brillo HDR y auto-emisión multiplicativa basada en la propia textura del bagre
## para mantener 100% sus colores y detalles originales sin verse gris plano.
func _ajustar_brillo_material() -> void:
	_aplicar_brillo_recursivo(self)

func _aplicar_brillo_recursivo(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst: MeshInstance3D = node as MeshInstance3D
		if mesh_inst.material_override is StandardMaterial3D or mesh_inst.material_override is ORMMaterial3D:
			mesh_inst.material_override = _realzar_material(mesh_inst.material_override)
		
		if mesh_inst.mesh:
			for i in range(mesh_inst.mesh.get_surface_count()):
				var orig_mat = mesh_inst.get_surface_override_material(i)
				if not orig_mat:
					orig_mat = mesh_inst.mesh.surface_get_material(i)
				
				if orig_mat:
					mesh_inst.set_surface_override_material(i, _realzar_material(orig_mat))

	for child in node.get_children():
		_aplicar_brillo_recursivo(child)

func _realzar_material(orig_mat: Material) -> Material:
	if orig_mat is StandardMaterial3D or orig_mat is ORMMaterial3D:
		var mat = orig_mat.duplicate()
		
		# Ajuste gradual según la zona
		var z_pos: float = global_position.z
		var is_dark_zone: bool = z_pos <= -140.0 # Zona 3 y Zona 4
		var is_mid_zone: bool = z_pos <= -70.0 and z_pos > -140.0 # Zona 2

		if is_dark_zone:
			# Zonas 3 y 4: Más claro y visible bajo agua turbia con emisión suave y textura original
			mat.albedo_color = Color(1.10, 1.10, 1.10, 1.0)
			if mat.albedo_texture != null:
				mat.emission_enabled = true
				mat.emission_texture = mat.albedo_texture
				mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				mat.emission = Color(0.18, 0.18, 0.18)
			else:
				mat.emission_enabled = false
			mat.roughness = 0.60
		elif is_mid_zone:
			mat.albedo_color = Color(1.18, 1.18, 1.18, 1.0)
			if mat.albedo_texture != null:
				mat.emission_enabled = true
				mat.emission_texture = mat.albedo_texture
				mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				mat.emission = Color(0.20, 0.20, 0.20)
			else:
				mat.emission_enabled = false
			mat.roughness = 0.58
		else:
			# Zona 1: claridad óptima para visibilidad subacuática
			mat.albedo_color = Color(1.25, 1.25, 1.25, 1.0)
			if mat.albedo_texture != null:
				mat.emission_enabled = true
				mat.emission_texture = mat.albedo_texture
				mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				mat.emission = Color(0.22, 0.22, 0.22)
			else:
				mat.emission_enabled = false
			mat.roughness = 0.55
			
		return mat
	return orig_mat

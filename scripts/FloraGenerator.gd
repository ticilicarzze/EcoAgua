@tool
class_name FloraGenerator
extends Node3D

## Script para generación procedural optimizada de Flora mediante MultiMeshInstance3D
## Diseñado para VR (Meta Quest / WebXR) para mantener 90 FPS y mínimas Draw Calls.

@export_group("Configuración General")
## Si es verdadero, genera la flora automáticamente al iniciar el juego
@export var generate_on_ready: bool = true

## Botón para regenerar en tiempo de edición desde el inspector
@export var regenerar_flora: bool = false:
	set(val):
		if val:
			generate_all_flora()
			regenerar_flora = false

## Botón para limpiar toda la flora generada
@export var limpiar_flora: bool = false:
	set(val):
		if val:
			clear_generated_flora()
			limpiar_flora = false

@export_group("Definiciones de Flora")
## Arreglo de configuraciones de flora a generar proceduralmente
@export var flora_configs: Array[FloraConfig] = []


func _ready() -> void:
	if not Engine.is_editor_hint() and generate_on_ready:
		generate_all_flora()


## Genera todos los nodos MultiMeshInstance3D según la configuración
func generate_all_flora() -> void:
	clear_generated_flora()
	
	if flora_configs.is_empty():
		_setup_default_configs()

	print("🌿 FloraGenerator: Iniciando generación de flora procedural...")
	var total_instancias := 0
	var total_draw_calls := 0

	for config in flora_configs:
		if not config or not config.model_scene or config.count <= 0:
			continue
			
		var mesh := _extract_mesh_from_scene(config.model_scene)
		if not mesh:
			push_warning("⚠️ FloraGenerator: No se pudo extraer Mesh de " + str(config.model_scene.resource_path))
			continue
			
		var multi_instance := MultiMeshInstance3D.new()
		multi_instance.name = "MM_" + config.nombre
		multi_instance.cast_shadow = config.cast_shadows
		
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = config.count
		
		for i in range(config.count):
			var pos := Vector3(
				config.center.x + randf_range(-config.extents.x, config.extents.x),
				config.center.y + randf_range(config.min_y_offset, config.max_y_offset),
				config.center.z + randf_range(-config.extents.z, config.extents.z)
			)
			
			var xform := Transform3D.IDENTITY
			
			# Escala aleatoria
			var s := randf_range(config.scale_min, config.scale_max)
			xform = xform.scaled(Vector3(s, s, s))
			
			# Rotación aleatoria en eje Y
			if config.random_rotation_y:
				xform = xform.rotated(Vector3.UP, randf_range(0.0, TAU))
				
			# Inclinación sutil aleatoria (opcional para pastos/juncos)
			if config.random_tilt_deg > 0.0:
				var tilt_rad := deg_to_rad(randf_range(-config.random_tilt_deg, config.random_tilt_deg))
				xform = xform.rotated(Vector3.RIGHT, tilt_rad)
				
			xform.origin = pos
			mm.set_instance_transform(i, xform)
			
		multi_instance.multimesh = mm
		add_child(multi_instance)
		
		if Engine.is_editor_hint():
			multi_instance.owner = get_tree().edited_scene_root
			
		total_instancias += config.count
		total_draw_calls += 1

	print("✅ FloraGenerator: Generadas ", total_instancias, " plantas en solo ", total_draw_calls, " Draw Calls.")


## Elimina los nodos MultiMesh generados anteriormente
func clear_generated_flora() -> void:
	var to_remove := []
	for child in get_children():
		if child is MultiMeshInstance3D or child.name.begins_with("MM_"):
			to_remove.append(child)
			
	for node in to_remove:
		node.queue_free()


## Extrae el primer MeshInstance3D.mesh encontrado dentro de un PackedScene
func _extract_mesh_from_scene(packed_scene: PackedScene) -> Mesh:
	if not packed_scene:
		return null
		
	var temp_node := packed_scene.instantiate()
	var mesh: Mesh = null
	
	if temp_node is MeshInstance3D:
		mesh = temp_node.mesh
	else:
		var mesh_nodes := temp_node.find_children("*", "MeshInstance3D", true, false)
		if not mesh_nodes.is_empty():
			mesh = (mesh_nodes[0] as MeshInstance3D).mesh
			
	temp_node.free()
	return mesh


## Carga configuraciones por defecto para la vegetación de EcoAgua si está vacía
func _setup_default_configs() -> void:
	flora_configs.clear()
	
	# Cargar modelos disponibles
	var path_juncos := "res://assets/models/ZONA1/Vegetación ribereña/Junco.glb"
	var path_cerato := "res://assets/models/ZONA1/Vegetacion Acuática/Ceratophyllum.glb"
	var path_potamo := "res://assets/models/ZONA1/Vegetacion Acuática/Potamogeton.glb"
	var path_graminea := "res://assets/models/ZONA1/Vegetación ribereña/Graminea_pampeana.glb"
	var path_pastizales := "res://assets/models/ZONA1/Vegetación ribereña/Pastizales_altos_pampeanos.glb"
	var path_ceibo := "res://assets/models/ZONA1/Vegetación ribereña/Ceibo.glb"
	var path_sauce := "res://assets/models/ZONA1/Vegetación ribereña/Sauce_criollo.glb"
	var path_cortadera := "res://assets/models/ZONA1/Vegetación ribereña/Cortadera.glb"

	_add_default_item("Juncos_Ribera", path_juncos, 80, Vector3(0, 0, 0), Vector3(15, 0, 80), 0.8, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_default_item("Ceratophyllum_Agua", path_cerato, 100, Vector3(0, -1.0, 0), Vector3(10, 0, 80), 0.7, 1.3, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_default_item("Potamogeton_Agua", path_potamo, 60, Vector3(0, -0.8, 0), Vector3(12, 0, 80), 0.8, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_default_item("Gramineas_Llanura", path_graminea, 50, Vector3(8, 0.2, 0), Vector3(20, 0, 80), 0.9, 1.3, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_default_item("Pastizales_Ribera", path_pastizales, 60, Vector3(-8, 0.2, 0), Vector3(20, 0, 80), 0.8, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_default_item("Ceibos_Bosque", path_ceibo, 20, Vector3(15, 0, 0), Vector3(15, 0, 80), 0.9, 1.4, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_add_default_item("Sauces_Orilla", path_sauce, 15, Vector3(-15, 0, 0), Vector3(15, 0, 80), 0.9, 1.3, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_add_default_item("Cortaderas_Borde", path_cortadera, 25, Vector3(5, 0, 0), Vector3(15, 0, 80), 0.8, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func _add_default_item(nombre: String, res_path: String, count: int, center: Vector3, extents: Vector3, s_min: float, s_max: float, shadow: GeometryInstance3D.ShadowCastingSetting) -> void:
	if ResourceLoader.exists(res_path):
		var cfg := FloraConfig.new()
		cfg.nombre = nombre
		cfg.model_scene = load(res_path)
		cfg.count = count
		cfg.center = center
		cfg.extents = extents
		cfg.scale_min = s_min
		cfg.scale_max = s_max
		cfg.cast_shadows = shadow
		flora_configs.append(cfg)

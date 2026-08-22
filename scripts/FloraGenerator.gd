@tool
class_name FloraGenerator
extends Node3D

## Generador Procedural Ecológico de Flora para EcoAgua
## Muestra la curvatura del río (RiverPath) y distribuye vegetación por estratos ribereños
## manteniendo 90 FPS en VR (MultiMeshInstance3D).

@export_group("Configuración General")
@export var generate_on_ready: bool = true
@export var river_path_nodepath: NodePath = NodePath("../RiverPath")
@export var river_channel_half_width: float = 4.5 # Ancho medio del canal de agua
@export var water_level_y: float = 0.0

@export_group("Acciones Inspector")
@export var regenerar_flora: bool = false:
	set(val):
		if val:
			generate_all_flora()
			regenerar_flora = false

@export var limpiar_flora: bool = false:
	set(val):
		if val:
			clear_generated_flora()
			limpiar_flora = false

@export_group("Definiciones por Zona")
@export var flora_configs: Array[FloraConfig] = []

var _river_curve: Curve3D = null


func _ready() -> void:
	if not Engine.is_editor_hint() and generate_on_ready:
		call_deferred("generate_all_flora")


## Genera todas las MultiMeshInstance3D siguiendo las reglas ecológicas
func generate_all_flora() -> void:
	clear_generated_flora()
	_update_river_curve_reference()
	
	if flora_configs.is_empty():
		_setup_ecological_configs()
		
	if not _river_curve:
		push_warning("⚠️ FloraGenerator: No se encontró la curva RiverPath. Usando modo aproximado por Z.")

	print("🌿 FloraGenerator: Generando vegetación según Reglas Ecológicas y Curvatura del Río...")
	var total_instancias := 0
	var total_draw_calls := 0

	for config in flora_configs:
		if not config or not config.model_scene or config.count <= 0:
			continue
			
		var mesh := _extract_mesh_from_scene(config.model_scene)
		if not mesh:
			# Omitir limpiamente si el modelo no existe o no tiene mesh
			print("ℹ️ FloraGenerator: Omitiendo ", config.nombre, " (sin modelo válido).")
			continue
			
		var multi_instance := MultiMeshInstance3D.new()
		multi_instance.name = "MM_Z" + str(config.zona_id) + "_" + config.nombre
		multi_instance.cast_shadow = config.cast_shadows
		
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = config.count
		
		# Rango Z según Zona Ecológica
		var z_min_max := _get_z_bounds_for_zone(config.zona_id)
		var z_min: float = z_min_max.x
		var z_max: float = z_min_max.y
		
		for i in range(config.count):
			var pos := _sample_bank_position(z_min, z_max, config)
			
			var xform := Transform3D.IDENTITY
			
			# Escala aleatoria uniforme
			var s := randf_range(config.scale_min, config.scale_max)
			xform = xform.scaled(Vector3(s, s, s))
			
			# Rotación aleatoria estrictamente vertical en eje Y (nunca inclinada hacia abajo)
			if config.random_rotation_y:
				xform = xform.rotated(Vector3.UP, randf_range(0.0, TAU))
				
			# Inclinación sutil opcional (manteniendo orientación vertical general)
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

	print("✅ FloraGenerator: Generadas ", total_instancias, " plantas en ", total_draw_calls, " MultiMesh (Draw Calls).")


## Calcula la posición exacta en la orilla respetando la curvatura y sin entrar al centro del río
func _sample_bank_position(z_min: float, z_max: float, config: FloraConfig) -> Vector3:
	var target_z := randf_range(z_min, z_max)
	var center_pos := Vector3(0, water_level_y, target_z)
	var right_vec := Vector3.RIGHT
	
	if _river_curve:
		# Muestrear la curva del río
		var curve_length := _river_curve.get_baked_length()
		# Mapear Z (de +150 a -450) a la distancia horneada de la curva
		var t_ratio := clampf(remap(target_z, 150.0, -450.0, 0.0, curve_length), 0.0, curve_length)
		var xform_center := _river_curve.sample_baked_with_rotation(t_ratio)
		center_pos = xform_center.origin
		
		var forward := -xform_center.basis.z.normalized()
		right_vec = forward.cross(Vector3.UP).normalized()

	# Determinar orilla (Izquierda vs Derecha)
	var side_sign := 1.0
	match config.bank_side:
		FloraConfig.SideOption.LEFT_ONLY:
			side_sign = -1.0
		FloraConfig.SideOption.RIGHT_ONLY:
			side_sign = 1.0
		FloraConfig.SideOption.BOTH:
			side_sign = -1.0 if randf() > 0.5 else 1.0
			
	# Distancia desde el centro del canal = Ancho del río + Distancia de estrato
	var dist_from_shore := randf_range(config.min_dist_orilla, config.max_dist_orilla)
	var total_lateral_offset := river_channel_half_width + dist_from_shore
	
	var world_pos := center_pos + (right_vec * side_sign * total_lateral_offset)
	
	# Calcular la altura del terreno (evita que la planta quede flotando)
	world_pos.y = _get_terrain_height_at(world_pos, dist_from_shore)
	
	return world_pos


## Obtiene la altura adecuada del suelo para la orilla
func _get_terrain_height_at(pos: Vector3, dist_from_shore: float) -> float:
	# Raycast si la escena está activa en el árbol de física
	if is_inside_tree() and get_world_3d() and get_world_3d().direct_space_state:
		var space_state := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			pos + Vector3(0, 15.0, 0),
			pos + Vector3(0, -15.0, 0)
		)
		var result := space_state.intersect_ray(query)
		if result and result.has("position"):
			return result.position.y
			
	# Perfil de talud matemático de respaldo (Perfil de Orilla 1:1)
	if dist_from_shore <= 0.0:
		# Sumergidas en el borde de la línea de agua (-0.1m a -0.5m)
		return water_level_y + (dist_from_shore * 0.4)
	else:
		# Terreno firme eleva gradualmente según la distancia de la costa
		return water_level_y + minf(dist_from_shore * 0.25, 2.0)


## Limpia los MultiMesh generados
func clear_generated_flora() -> void:
	var to_remove := []
	for child in get_children():
		if child is MultiMeshInstance3D or child.name.begins_with("MM_"):
			to_remove.append(child)
			
	for node in to_remove:
		node.queue_free()


## Devuelve los límites Z para cada Zona Ecológica
func _get_z_bounds_for_zone(zone_id: int) -> Vector2:
	match zone_id:
		1: return Vector2(150.0, -20.0)   # Zona 1: Ribera Natural / Conservada
		2: return Vector2(-20.0, -140.0)  # Zona 2: Ribera Antropizada / Agrícola
		3: return Vector2(-140.0, -260.0) # Zona 3: Ribera Urbana / Degradada
		4: return Vector2(-260.0, -450.0) # Zona 4: Zona Crítica / Eutrofizada
		_: return Vector2(100.0, -100.0)


## Intenta referenciar el Path3D del río
func _update_river_curve_reference() -> void:
	_river_curve = null
	var node := get_node_or_null(river_path_nodepath)
	if node is Path3D:
		_river_curve = (node as Path3D).curve


## Extrae la malla de una escena PackedScene
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


## Configura la lista de especies según las Reglas Ecológicas de la investigación
func _setup_ecological_configs() -> void:
	flora_configs.clear()

	# Rutas a modelos 3D disponibles
	var p_junco := "res://assets/models/ZONA1/Vegetación ribereña/Junco.glb"
	var p_totoras := "res://assets/models/ZONA1/Vegetación ribereña/Totoras.glb"
	var p_sauce := "res://assets/models/ZONA1/Vegetación ribereña/Sauce_criollo.glb"
	var p_ceibo := "res://assets/models/ZONA1/Vegetación ribereña/Ceibo.glb"
	var p_cortadera := "res://assets/models/ZONA1/Vegetación ribereña/Cortadera.glb"
	var p_graminea := "res://assets/models/ZONA1/Vegetación ribereña/Graminea_pampeana.glb"
	var p_pastizal := "res://assets/models/ZONA1/Vegetación ribereña/Pastizales_altos_pampeanos.glb"
	var p_cerato := "res://assets/models/ZONA1/Vegetacion Acuática/Ceratophyllum.glb"
	var p_alga := "res://assets/models/ZONA1/Vegetacion Acuática/Alga_filamentosa.glb"
	var p_rama := "res://assets/models/ZONA1/Vegetacion Acuática/Rama_sola.glb"

	# === ZONA 1: RIBERA NATURAL / CONSERVADA ===
	_add_eco_item("Juncos", p_junco, 25, 1, "Línea de Agua", -0.5, -0.1, 0.8, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_eco_item("Totoras", p_totoras, 22, 1, "Orilla Inmediata", -0.2, 1.5, 0.8, 1.3, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_eco_item("Gramineas_Orilla", p_graminea, 15, 1, "Orilla Inmediata", 0.0, 2.0, 0.8, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_eco_item("Sauce_Criollo", p_sauce, 4, 1, "Franja Ribereña", 2.0, 6.0, 0.9, 1.3, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_add_eco_item("Ceibo", p_ceibo, 2, 1, "Margen Superior", 3.0, 8.0, 0.9, 1.4, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_add_eco_item("Cortaderas", p_cortadera, 15, 1, "Margen Superior", 4.0, 10.0, 0.8, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_eco_item("Pastizales", p_pastizal, 15, 1, "Margen Superior", 4.0, 14.0, 0.8, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_eco_item("Ceratophyllum", p_cerato, 35, 1, "Acuática Somera", -3.5, -1.0, 0.7, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	# === ZONA 2: RIBERA ANTROPIZADA / AGRÍCOLA ===
	_add_eco_item("Sauce_Relicto", p_sauce, 2, 2, "Franja Ribereña", 2.0, 5.0, 0.9, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_add_eco_item("Cortaderas_Fragmentadas", p_cortadera, 18, 2, "Margen Agrícola", 1.5, 8.0, 0.8, 1.2, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_eco_item("Gramineas_Zanja", p_graminea, 10, 2, "Orilla Escorrentía", 1.0, 5.0, 0.8, 1.1, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	# === ZONA 3: RIBERA URBANA / DEGRADADA ===
	_add_eco_item("Sauce_Estresado", p_sauce, 1, 3, "Franja Ribereña", 3.0, 5.0, 0.8, 1.0, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_add_eco_item("Pastos_Gastados", p_pastizal, 10, 3, "Terraplén Compactado", 1.0, 6.0, 0.7, 1.0, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	# === ZONA 4: ZONA CRÍTICA / EUTROFIZADA ===
	_add_eco_item("Algas_Filamentosas", p_alga, 25, 4, "Borde Acuático", -0.3, 0.1, 0.8, 1.3, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_add_eco_item("Arboles_Muertos", p_rama, 3, 4, "Franja Seca", 2.0, 6.0, 0.9, 1.3, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_add_eco_item("Malezas_Secas", p_graminea, 5, 4, "Margen Degradado", 2.0, 6.0, 0.7, 1.0, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


func _add_eco_item(nombre: String, res_path: String, count: int, zona_id: int, estrato: String, min_d: float, max_d: float, s_min: float, s_max: float, shadow: GeometryInstance3D.ShadowCastingSetting) -> void:
	if ResourceLoader.exists(res_path):
		var cfg := FloraConfig.new()
		cfg.nombre = nombre
		cfg.model_scene = load(res_path)
		cfg.count = count
		cfg.zona_id = zona_id
		cfg.estrato_nombre = estrato
		cfg.min_dist_orilla = min_d
		cfg.max_dist_orilla = max_d
		cfg.scale_min = s_min
		cfg.scale_max = s_max
		cfg.cast_shadows = shadow
		flora_configs.append(cfg)
	else:
		# Omitir limpiamente si el archivo no existe
		print("ℹ️ FloraGenerator: Modelo no encontrado para ", nombre, " (", res_path, "), omitiendo.")

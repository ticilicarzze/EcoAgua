@tool
extends MeshInstance3D

class_name WaterVisualController

## Controller to bind WaterManager state metrics to watershader2.gdshader.
## Attach this script to the MeshInstance3D named "Water" representing the river water.

# Reference to the shader material. If left empty, it will auto-detect from the mesh.
@export var water_material: ShaderMaterial

# Visual profiles (Colors) matching each zone for watershader2.gdshader (Pampean brown river palette)
const ZONE_COLORS = {
	1: {
		"shallow":   Color(0.55, 0.44, 0.28, 1.0), # Té con leche claro (Z1)
		"deep":      Color(0.30, 0.20, 0.08, 1.0), # Marrón pardo profundo
		"base":      Color(0.45, 0.35, 0.22, 1.0), # Superficie templada traslúcida
		"fresnel":   Color(0.48, 0.46, 0.42, 1.0), # Reflejo tenue desaturado
		"beers_law": 0.35,                         # Clara, visibilidad alta
		"roughness": 0.22
	},
	2: {
		"shallow":   Color(0.47, 0.33, 0.15, 1.0), # Café con leche (Z2)
		"deep":      Color(0.24, 0.14, 0.05, 1.0), # Marrón medio denso
		"base":      Color(0.38, 0.26, 0.12, 1.0), # Tono orgánico en suspensión
		"fresnel":   Color(0.42, 0.44, 0.40, 1.0), # Reflejo mate verdoso
		"beers_law": 0.65,                         # Absorción moderada
		"roughness": 0.28
	},
	3: {
		"shallow":   Color(0.36, 0.22, 0.08, 1.0), # Chocolate líquido (Z3)
		"deep":      Color(0.16, 0.09, 0.03, 1.0), # Pardo muy oscuro
		"base":      Color(0.28, 0.16, 0.06, 1.0), # Sedimento espeso
		"fresnel":   Color(0.35, 0.35, 0.33, 1.0), # Reflejo opaco grisáceo
		"beers_law": 1.10,                         # Turbia, absorción alta
		"roughness": 0.35
	},
	4: {
		"shallow":   Color(0.28, 0.15, 0.04, 1.0), # Marrón lodo oscuro (Z4)
		"deep":      Color(0.10, 0.05, 0.01, 1.0), # Casi negro terroso
		"base":      Color(0.20, 0.10, 0.02, 1.0), # Lodo degradado químicamente
		"fresnel":   Color(0.28, 0.26, 0.24, 1.0), # Reflejo opaco apagado
		"beers_law": 1.80,                         # Máxima absorción, muy opaca
		"roughness": 0.45
	}
}

@export_group("Color Override")
## Activá esto para editar el color del río directamente desde el Inspector.
## Cuando está activo, los colores de zona son ignorados.
@export var use_color_override: bool = false
@export var override_shallow: Color = Color(0.55, 0.44, 0.28, 1.0)
@export var override_deep:    Color = Color(0.30, 0.20, 0.08, 1.0)
@export var override_base:    Color = Color(0.45, 0.35, 0.22, 1.0)
@export var override_fresnel: Color = Color(0.48, 0.46, 0.42, 1.0)
@export_range(0.0, 3.0, 0.05) var override_beers_law: float = 0.35
@export_range(0.0, 1.0, 0.01) var override_roughness: float = 0.22

func _ready() -> void:
	# Fallback: Attempt to fetch ShaderMaterial from active material slot or override
	if not water_material:
		var active_mat = material_override
		if active_mat is ShaderMaterial:
			water_material = active_mat
		else:
			active_mat = get_active_material(0)
			if active_mat is ShaderMaterial:
				water_material = active_mat
			else:
				if not Engine.is_editor_hint():
					push_warning("WaterVisualController: MeshInstance3D is missing a ShaderMaterial. Uniforms will not be updated.")

func _apply_colors(shallow: Color, deep: Color, base: Color, fresnel: Color, beers: float, rough: float) -> void:
	water_material.set_shader_parameter("metallic", 0.0)
	water_material.set_shader_parameter("shallow_water_color", shallow)
	water_material.set_shader_parameter("deep_water_color", deep)
	water_material.set_shader_parameter("base_water_color", Vector3(base.r, base.g, base.b))
	water_material.set_shader_parameter("fresnel_water_color", Vector3(fresnel.r, fresnel.g, fresnel.b))
	water_material.set_shader_parameter("beers_law", beers)
	water_material.set_shader_parameter("roughness", rough)

func _process(_delta: float) -> void:
	if not water_material:
		var active_mat = material_override
		if active_mat is ShaderMaterial:
			water_material = active_mat
		else:
			return

	# Color override activo: usa los valores del Inspector directamente
	if use_color_override:
		_apply_colors(override_shallow, override_deep, override_base,
			override_fresnel, override_beers_law, override_roughness)
		return

	# In editor (sin override): aplica Zona 1 del diccionario
	if Engine.is_editor_hint():
		var z = ZONE_COLORS[1]
		_apply_colors(z["shallow"], z["deep"], z["base"], z["fresnel"], z["beers_law"], z["roughness"])
		return
	
	# Runtime: fetch progress from WaterManager autoload
	var progress: float = WaterManager.progress_ratio

	# Compute dynamic interpolated colors
	var colors = get_interpolated_colors(progress)

	# Apply parameters to watershader2.gdshader
	_apply_colors(colors.shallow, colors.deep, colors.base, colors.fresnel, colors.beers_law, colors.roughness)

## Computes interpolated colors based on progress ratio and WaterManager transition settings
func get_interpolated_colors(ratio: float) -> Dictionary:
	var use_interpolation = WaterManager.use_interpolation
	var window = WaterManager.transition_window
	var half_window = window / 2.0
	
	var current_zone = WaterManager.current_zone
	var z = ZONE_COLORS[current_zone]
	var target_shallow = z["shallow"]
	var target_deep = z["deep"]
	var target_base = z["base"]
	var target_fresnel = z["fresnel"]
	var target_beers = z["beers_law"]
	var target_roughness = z["roughness"]
	
	# Interpolate colors if inside transition windows to avoid visual pops
	if use_interpolation:
		if ratio >= 0.25 - half_window and ratio <= 0.25 + half_window:
			var t = (ratio - (0.25 - half_window)) / window
			target_shallow = ZONE_COLORS[1]["shallow"].lerp(ZONE_COLORS[2]["shallow"], t)
			target_deep = ZONE_COLORS[1]["deep"].lerp(ZONE_COLORS[2]["deep"], t)
			target_base = ZONE_COLORS[1]["base"].lerp(ZONE_COLORS[2]["base"], t)
			target_fresnel = ZONE_COLORS[1]["fresnel"].lerp(ZONE_COLORS[2]["fresnel"], t)
			target_beers = lerp(ZONE_COLORS[1]["beers_law"], ZONE_COLORS[2]["beers_law"], t)
			target_roughness = lerp(ZONE_COLORS[1]["roughness"], ZONE_COLORS[2]["roughness"], t)
		elif ratio >= 0.50 - half_window and ratio <= 0.50 + half_window:
			var t = (ratio - (0.50 - half_window)) / window
			target_shallow = ZONE_COLORS[2]["shallow"].lerp(ZONE_COLORS[3]["shallow"], t)
			target_deep = ZONE_COLORS[2]["deep"].lerp(ZONE_COLORS[3]["deep"], t)
			target_base = ZONE_COLORS[2]["base"].lerp(ZONE_COLORS[3]["base"], t)
			target_fresnel = ZONE_COLORS[2]["fresnel"].lerp(ZONE_COLORS[3]["fresnel"], t)
			target_beers = lerp(ZONE_COLORS[2]["beers_law"], ZONE_COLORS[3]["beers_law"], t)
			target_roughness = lerp(ZONE_COLORS[2]["roughness"], ZONE_COLORS[3]["roughness"], t)
		elif ratio >= 0.75 - half_window and ratio <= 0.75 + half_window:
			var t = (ratio - (0.75 - half_window)) / window
			target_shallow = ZONE_COLORS[3]["shallow"].lerp(ZONE_COLORS[4]["shallow"], t)
			target_deep = ZONE_COLORS[3]["deep"].lerp(ZONE_COLORS[4]["deep"], t)
			target_base = ZONE_COLORS[3]["base"].lerp(ZONE_COLORS[4]["base"], t)
			target_fresnel = ZONE_COLORS[3]["fresnel"].lerp(ZONE_COLORS[4]["fresnel"], t)
			target_beers = lerp(ZONE_COLORS[3]["beers_law"], ZONE_COLORS[4]["beers_law"], t)
			target_roughness = lerp(ZONE_COLORS[3]["roughness"], ZONE_COLORS[4]["roughness"], t)
	
	return {
		"shallow": target_shallow,
		"deep": target_deep,
		"base": target_base,
		"fresnel": target_fresnel,
		"beers_law": target_beers,
		"roughness": target_roughness,
	}

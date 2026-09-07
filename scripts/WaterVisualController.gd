@tool
extends MeshInstance3D

class_name WaterVisualController

## Controller to bind WaterManager state metrics to watershader2.gdshader.
## Attach this script to the MeshInstance3D named "Water" representing the river water.

# Reference to the shader material. If left empty, it will auto-detect from the mesh.
@export var water_material: ShaderMaterial

# Visual profiles (Colors and dynamic motion parameters) matching each zone
const ZONE_PROFILES = {
	1: {
		"shallow":         Color(0.55, 0.44, 0.28, 1.0), # Té con leche claro (Z1)
		"deep":            Color(0.30, 0.20, 0.08, 1.0), # Marrón pardo profundo
		"base":            Color(0.45, 0.35, 0.22, 1.0), # Superficie templada traslúcida
		"fresnel":         Color(0.48, 0.46, 0.42, 1.0), # Reflejo tenue desaturado
		"beers_law":       0.35,                         # Clara, visibilidad alta
		"roughness":       0.22,
		"wave_amplitude":  1.00,                         # Oleaje normal pleno
		"flow_speed":      1.80,                         # Corriente viva
		"normal_strength": 1.00                          # Ondulaciones completas
	},
	2: {
		"shallow":         Color(0.47, 0.33, 0.15, 1.0), # Café con leche (Z2)
		"deep":            Color(0.24, 0.14, 0.05, 1.0), # Marrón medio denso
		"base":            Color(0.38, 0.26, 0.12, 1.0), # Tono orgánico en suspensión
		"fresnel":         Color(0.42, 0.44, 0.40, 1.0), # Reflejo mate verdoso
		"beers_law":       0.65,                         # Absorción moderada
		"roughness":       0.28,
		"wave_amplitude":  0.85,
		"flow_speed":      1.20,
		"normal_strength": 0.85
	},
	3: {
		"shallow":         Color(0.36, 0.22, 0.08, 1.0), # Chocolate líquido (Z3)
		"deep":            Color(0.16, 0.09, 0.03, 1.0), # Pardo muy oscuro
		"base":            Color(0.28, 0.16, 0.06, 1.0), # Sedimento espeso
		"fresnel":         Color(0.35, 0.35, 0.33, 1.0), # Reflejo opaco grisáceo
		"beers_law":       1.10,                         # Turbia, absorción alta
		"roughness":       0.35,
		"wave_amplitude":  0.30,                         # Olas disminuidas
		"flow_speed":      0.35,                         # Velocidad de agua disminuida
		"normal_strength": 0.50                          # Ondulaciones reducidas
	},
	4: {
		"shallow":         Color(0.28, 0.15, 0.04, 1.0), # Marrón lodo oscuro (Z4)
		"deep":            Color(0.10, 0.05, 0.01, 1.0), # Casi negro terroso
		"base":            Color(0.20, 0.10, 0.02, 1.0), # Lodo degradado químicamente
		"fresnel":         Color(0.28, 0.26, 0.24, 1.0), # Reflejo opaco apagado
		"beers_law":       1.80,                         # Máxima absorción, muy opaca
		"roughness":       0.45,
		"wave_amplitude":  0.02,                         # Olas prácticamente nulas (agua plana)
		"flow_speed":      0.02,                         # Velocidad prácticamente nula (estancada)
		"normal_strength": 0.12                          # Casi sin ondulaciones superficiales
	}
}

# Alias for backwards compatibility
const ZONE_COLORS = ZONE_PROFILES

@export_group("Color Override")
## Activá esto para editar el color del río directamente desde el Inspector.
## Cuando está activo, los colores de zona son ignorados, pero la simulación física de olas se mantiene.
@export var use_color_override: bool = false
@export var override_shallow: Color = Color(0.55, 0.44, 0.28, 1.0)
@export var override_deep:    Color = Color(0.30, 0.20, 0.08, 1.0)
@export var override_base:    Color = Color(0.45, 0.35, 0.22, 1.0)
@export var override_fresnel: Color = Color(0.48, 0.46, 0.42, 1.0)
@export_range(0.0, 3.0, 0.05) var override_beers_law: float = 0.35
@export_range(0.0, 1.0, 0.01) var override_roughness: float = 0.22

# Continuous water flow time accumulator (avoids texture phase jumps on speed changes)
var _water_flow_time: float = 0.0

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

func _process(delta: float) -> void:
	if not water_material:
		var active_mat = material_override
		if active_mat is ShaderMaterial:
			water_material = active_mat
		else:
			return

	var visuals: Dictionary
	if Engine.is_editor_hint():
		visuals = ZONE_PROFILES[1].duplicate()
	else:
		var progress: float = WaterManager.progress_ratio
		visuals = get_interpolated_visuals(progress)

	# Continuous flow time integration based on current flow speed
	var current_flow_speed: float = visuals["flow_speed"]
	_water_flow_time += delta * current_flow_speed

	# Update dynamic wave, ripple and velocity parameters in watershader2.gdshader
	water_material.set_shader_parameter("custom_water_time", _water_flow_time)
	water_material.set_shader_parameter("wave_amplitude_scale", visuals["wave_amplitude"])
	water_material.set_shader_parameter("normal_strength_scale", visuals["normal_strength"])
	water_material.set_shader_parameter("river_flow_speed", current_flow_speed)

	# Apply water colors
	if use_color_override:
		_apply_colors(override_shallow, override_deep, override_base,
			override_fresnel, override_beers_law, override_roughness)
	else:
		_apply_colors(visuals.shallow, visuals.deep, visuals.base,
			visuals.fresnel, visuals.beers_law, visuals.roughness)

## Computes interpolated visuals (colors, wave amplitude, flow speed, normal strength)
func get_interpolated_visuals(ratio: float) -> Dictionary:
	var use_interpolation = WaterManager.use_interpolation
	var window = WaterManager.transition_window
	var half_window = window / 2.0
	
	var current_zone = WaterManager.current_zone
	var z = ZONE_PROFILES[current_zone]
	var target_shallow = z["shallow"]
	var target_deep = z["deep"]
	var target_base = z["base"]
	var target_fresnel = z["fresnel"]
	var target_beers = z["beers_law"]
	var target_roughness = z["roughness"]
	var target_wave_amp = z["wave_amplitude"]
	var target_flow_speed = z["flow_speed"]
	var target_normal_strength = z["normal_strength"]
	
	# Interpolate visuals inside transition windows to avoid pops
	if use_interpolation:
		if ratio >= 0.25 - half_window and ratio <= 0.25 + half_window:
			var t = (ratio - (0.25 - half_window)) / window
			var z1 = ZONE_PROFILES[1]
			var z2 = ZONE_PROFILES[2]
			target_shallow = z1["shallow"].lerp(z2["shallow"], t)
			target_deep = z1["deep"].lerp(z2["deep"], t)
			target_base = z1["base"].lerp(z2["base"], t)
			target_fresnel = z1["fresnel"].lerp(z2["fresnel"], t)
			target_beers = lerp(z1["beers_law"], z2["beers_law"], t)
			target_roughness = lerp(z1["roughness"], z2["roughness"], t)
			target_wave_amp = lerp(z1["wave_amplitude"], z2["wave_amplitude"], t)
			target_flow_speed = lerp(z1["flow_speed"], z2["flow_speed"], t)
			target_normal_strength = lerp(z1["normal_strength"], z2["normal_strength"], t)
		elif ratio >= 0.50 - half_window and ratio <= 0.50 + half_window:
			var t = (ratio - (0.50 - half_window)) / window
			var z2 = ZONE_PROFILES[2]
			var z3 = ZONE_PROFILES[3]
			target_shallow = z2["shallow"].lerp(z3["shallow"], t)
			target_deep = z2["deep"].lerp(z3["deep"], t)
			target_base = z2["base"].lerp(z3["base"], t)
			target_fresnel = z2["fresnel"].lerp(z3["fresnel"], t)
			target_beers = lerp(z2["beers_law"], z3["beers_law"], t)
			target_roughness = lerp(z2["roughness"], z3["roughness"], t)
			target_wave_amp = lerp(z2["wave_amplitude"], z3["wave_amplitude"], t)
			target_flow_speed = lerp(z2["flow_speed"], z3["flow_speed"], t)
			target_normal_strength = lerp(z2["normal_strength"], z3["normal_strength"], t)
		elif ratio >= 0.75 - half_window and ratio <= 0.75 + half_window:
			var t = (ratio - (0.75 - half_window)) / window
			var z3 = ZONE_PROFILES[3]
			var z4 = ZONE_PROFILES[4]
			target_shallow = z3["shallow"].lerp(z4["shallow"], t)
			target_deep = z3["deep"].lerp(z4["deep"], t)
			target_base = z3["base"].lerp(z4["base"], t)
			target_fresnel = z3["fresnel"].lerp(z4["fresnel"], t)
			target_beers = lerp(z3["beers_law"], z4["beers_law"], t)
			target_roughness = lerp(z3["roughness"], z4["roughness"], t)
			target_wave_amp = lerp(z3["wave_amplitude"], z4["wave_amplitude"], t)
			target_flow_speed = lerp(z3["flow_speed"], z4["flow_speed"], t)
			target_normal_strength = lerp(z3["normal_strength"], z4["normal_strength"], t)
	
	return {
		"shallow": target_shallow,
		"deep": target_deep,
		"base": target_base,
		"fresnel": target_fresnel,
		"beers_law": target_beers,
		"roughness": target_roughness,
		"wave_amplitude": target_wave_amp,
		"flow_speed": target_flow_speed,
		"normal_strength": target_normal_strength,
	}

# Legacy function name alias
func get_interpolated_colors(ratio: float) -> Dictionary:
	return get_interpolated_visuals(ratio)

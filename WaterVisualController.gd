extends MeshInstance3D

class_name WaterVisualController

## Controller to bind WaterManager state metrics to the custom water shader.
## Attach this script to the MeshInstance3D representing the river water.

# Reference to the shader material. If left empty, it will auto-detect from the mesh.
@export var water_material: ShaderMaterial

# Visual profiles (Colors) matching each zone
const ZONE_COLORS = {
	1: {
		"albedo": Color(0.55, 0.47, 0.38, 0.45), # Translucent light brown / té con leche muy diluido (40-60cm visibility)
		"turbidity": Color(0.48, 0.40, 0.32, 1.0) # Sandy brown base
	},
	2: {
		"albedo": Color(0.45, 0.35, 0.26, 0.75), # Medium brown / café con leche (20-30cm visibility)
		"turbidity": Color(0.35, 0.26, 0.18, 1.0) # Medium brown base
	},
	3: {
		"albedo": Color(0.25, 0.16, 0.10, 0.92), # Dark rich brown / chocolate líquido (0-10cm visibility)
		"turbidity": Color(0.18, 0.10, 0.05, 1.0) # Dark brown base
	},
	4: {
		"albedo": Color(0.12, 0.12, 0.12, 0.98), # Almost opaque oily grey-black / gris-negro aceitoso (0cm visibility)
		"turbidity": Color(0.05, 0.05, 0.05, 1.0) # Black base
	}
}

func _ready() -> void:
	# Fallback: Attempt to fetch ShaderMaterial from active material slot 0
	if not water_material:
		var active_mat = get_active_material(0)
		if active_mat is ShaderMaterial:
			water_material = active_mat
		else:
			push_warning("WaterVisualController: MeshInstance3D is missing a ShaderMaterial on slot 0. Uniforms will not be updated.")

func _process(_delta: float) -> void:
	if not water_material:
		return
	
	# Fetch values from the centralized state manager
	var progress = WaterManager.progress_ratio
	
	# 1. Update flow speed parameter
	water_material.set_shader_parameter("flow_speed", WaterManager.water_flow_speed)
	
	# 2. Map visibility in meters to shader extinction coefficient
	# (k = 3.0 / visibility ensures light decays to ~5% at the visibility depth limit)
	var visibility = WaterManager.turbidity_visibility
	var extinction = 100.0 # Instant opacity fallback for Zone 4 (0cm visibility)
	if visibility > 0.001:
		extinction = 3.0 / visibility
	water_material.set_shader_parameter("extinction_coefficient", extinction)
	
	# 3. Calculate and apply interpolated colors
	var colors = get_interpolated_colors(progress)
	water_material.set_shader_parameter("albedo_color", colors.albedo)
	water_material.set_shader_parameter("turbidity_color", colors.turbidity)

## Computes interpolated colors based on progress ratio and WaterManager transition settings
func get_interpolated_colors(ratio: float) -> Dictionary:
	var use_interpolation = WaterManager.use_interpolation
	var window = WaterManager.transition_window
	var half_window = window / 2.0
	
	var current_zone = WaterManager.current_zone
	var target_albedo = ZONE_COLORS[current_zone]["albedo"]
	var target_turbidity = ZONE_COLORS[current_zone]["turbidity"]
	
	# Interpolate colors if inside transition windows to avoid visual pops
	if use_interpolation:
		if ratio >= 0.25 - half_window and ratio <= 0.25 + half_window:
			var t = (ratio - (0.25 - half_window)) / window
			target_albedo = ZONE_COLORS[1]["albedo"].lerp(ZONE_COLORS[2]["albedo"], t)
			target_turbidity = ZONE_COLORS[1]["turbidity"].lerp(ZONE_COLORS[2]["turbidity"], t)
		elif ratio >= 0.50 - half_window and ratio <= 0.50 + half_window:
			var t = (ratio - (0.50 - half_window)) / window
			target_albedo = ZONE_COLORS[2]["albedo"].lerp(ZONE_COLORS[3]["albedo"], t)
			target_turbidity = ZONE_COLORS[2]["turbidity"].lerp(ZONE_COLORS[3]["turbidity"], t)
		elif ratio >= 0.75 - half_window and ratio <= 0.75 + half_window:
			var t = (ratio - (0.75 - half_window)) / window
			target_albedo = ZONE_COLORS[3]["albedo"].lerp(ZONE_COLORS[4]["albedo"], t)
			target_turbidity = ZONE_COLORS[3]["turbidity"].lerp(ZONE_COLORS[4]["turbidity"], t)
	
	return {
		"albedo": target_albedo,
		"turbidity": target_turbidity
	}

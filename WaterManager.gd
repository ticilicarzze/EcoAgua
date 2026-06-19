extends Node

## Centralized State Manager for EcoAguaUNR
## Manages water metrics and zones based on the progress_ratio of the path.

# Signals
signal zone_changed(new_zone: int)
signal metrics_updated(wqi: float, do: float)

# Constant configuration metrics per zone
const ZONE_METRICS = {
	1: {
		"name": "Baseline (Low Pollution)",
		"wqi": 90.0,
		"do": 8.0,
		"flow_speed": 2.0,
		"visibility": 0.6
	},
	2: {
		"name": "Agricultural/Livestock",
		"wqi": 60.0,
		"do": 5.5,
		"flow_speed": 1.2,
		"visibility": 0.4
	},
	3: {
		"name": "Peri-urban/Agro-industrial",
		"wqi": 30.0,
		"do": 2.0,
		"flow_speed": 0.6,
		"visibility": 0.15
	},
	4: {
		"name": "Critical Chemical (Closure)",
		"wqi": 5.0,
		"do": 0.5,
		"flow_speed": 0.1,
		"visibility": 0.0
	}
}

# Configurable settings
@export var use_interpolation: bool = true
@export var transition_window: float = 0.05 # 5% transition window centered on zone boundaries

# State variables
var current_zone: int = 1
var water_quality_index: float = 90.0
var dissolved_oxygen: float = 8.0
var water_flow_speed: float = 2.0
var turbidity_visibility: float = 0.6

# Set progress ratio (0.0 to 1.0) and dynamically recalculate metrics
var progress_ratio: float = 0.0:
	set(value):
		progress_ratio = clamp(value, 0.0, 1.0)
		_update_metrics()

func _ready() -> void:
	# Initialize metrics to Zone 1 defaults
	_update_metrics()

func _update_metrics() -> void:
	# 1. Determine current zone based on strict progress thresholds
	var new_zone: int = 1
	if progress_ratio < 0.25:
		new_zone = 1
	elif progress_ratio < 0.50:
		new_zone = 2
	elif progress_ratio < 0.75:
		new_zone = 3
	else:
		new_zone = 4
	
	var has_zone_changed := false
	if new_zone != current_zone:
		current_zone = new_zone
		has_zone_changed = true
	
	# 2. Calculate values (interpolated or step-wise)
	var target_wqi: float = ZONE_METRICS[current_zone]["wqi"]
	var target_do: float = ZONE_METRICS[current_zone]["do"]
	var target_flow: float = ZONE_METRICS[current_zone]["flow_speed"]
	var target_vis: float = ZONE_METRICS[current_zone]["visibility"]
	
	if use_interpolation:
		var half_window = transition_window / 2.0
		
		# Check transition boundaries
		if progress_ratio >= 0.25 - half_window and progress_ratio <= 0.25 + half_window:
			var t = (progress_ratio - (0.25 - half_window)) / transition_window
			target_wqi = lerp(ZONE_METRICS[1]["wqi"], ZONE_METRICS[2]["wqi"], t)
			target_do = lerp(ZONE_METRICS[1]["do"], ZONE_METRICS[2]["do"], t)
			target_flow = lerp(ZONE_METRICS[1]["flow_speed"], ZONE_METRICS[2]["flow_speed"], t)
			target_vis = lerp(ZONE_METRICS[1]["visibility"], ZONE_METRICS[2]["visibility"], t)
		elif progress_ratio >= 0.50 - half_window and progress_ratio <= 0.50 + half_window:
			var t = (progress_ratio - (0.50 - half_window)) / transition_window
			target_wqi = lerp(ZONE_METRICS[2]["wqi"], ZONE_METRICS[3]["wqi"], t)
			target_do = lerp(ZONE_METRICS[2]["do"], ZONE_METRICS[3]["do"], t)
			target_flow = lerp(ZONE_METRICS[2]["flow_speed"], ZONE_METRICS[3]["flow_speed"], t)
			target_vis = lerp(ZONE_METRICS[2]["visibility"], ZONE_METRICS[3]["visibility"], t)
		elif progress_ratio >= 0.75 - half_window and progress_ratio <= 0.75 + half_window:
			var t = (progress_ratio - (0.75 - half_window)) / transition_window
			target_wqi = lerp(ZONE_METRICS[3]["wqi"], ZONE_METRICS[4]["wqi"], t)
			target_do = lerp(ZONE_METRICS[3]["do"], ZONE_METRICS[4]["do"], t)
			target_flow = lerp(ZONE_METRICS[3]["flow_speed"], ZONE_METRICS[4]["flow_speed"], t)
			target_vis = lerp(ZONE_METRICS[3]["visibility"], ZONE_METRICS[4]["visibility"], t)
	
	# Apply updated values
	water_quality_index = target_wqi
	dissolved_oxygen = target_do
	water_flow_speed = target_flow
	turbidity_visibility = target_vis
	
	# Emit signals
	if has_zone_changed:
		zone_changed.emit(current_zone)
		
	metrics_updated.emit(water_quality_index, dissolved_oxygen)

## Helper function to get zone details
func get_zone_name() -> String:
	return ZONE_METRICS[current_zone]["name"]

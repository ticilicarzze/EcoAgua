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
		"wqi_min": 85.0,
		"wqi_max": 90.0,
		"do_min": 8.0,
		"do_max": 8.5,
		"flow_speed": 2.0,
		"visibility_min": 0.4,
		"visibility_max": 0.6
	},
	2: {
		"name": "Agricultural/Livestock",
		"wqi_min": 60.0,
		"wqi_max": 70.0,
		"do_min": 6.0,
		"do_max": 8.0,
		"flow_speed": 1.2,
		"visibility_min": 0.2,
		"visibility_max": 0.3
	},
	3: {
		"name": "Peri-urban/Agro-industrial",
		"wqi_min": 35.0,
		"wqi_max": 45.0,
		"do_min": 3.0,
		"do_max": 5.0,
		"flow_speed": 0.6,
		"visibility_min": 0.0,
		"visibility_max": 0.1
	},
	4: {
		"name": "Critical Chemical (Closure)",
		"wqi_min": 5.0,
		"wqi_max": 20.0,
		"do_min": 0.5,
		"do_max": 2.0,
		"flow_speed": 0.1,
		"visibility_min": 0.0,
		"visibility_max": 0.0
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

## Computes the metric value for a given progress ratio
func get_metric_value(metric_name: String, ratio: float) -> float:
	var use_range := metric_name + "_min" in ZONE_METRICS[1]
	
	# Determine zone based on progress thresholds
	var zone: int = 1
	if ratio < 0.25:
		zone = 1
	elif ratio < 0.50:
		zone = 2
	elif ratio < 0.75:
		zone = 3
	else:
		zone = 4

	if not use_interpolation:
		if use_range:
			# Return the midpoint of the range for that zone
			return 0.5 * (ZONE_METRICS[zone][metric_name + "_min"] + ZONE_METRICS[zone][metric_name + "_max"])
		else:
			return ZONE_METRICS[zone][metric_name]

	# With interpolation:
	var half_w = transition_window / 2.0
	
	# Check transition boundaries
	if ratio >= 0.25 - half_w and ratio <= 0.25 + half_w:
		var t = (ratio - (0.25 - half_w)) / transition_window
		var val_start = ZONE_METRICS[1][metric_name + "_min"] if use_range else ZONE_METRICS[1][metric_name]
		var val_end = ZONE_METRICS[2][metric_name + "_max"] if use_range else ZONE_METRICS[2][metric_name]
		return lerp(val_start, val_end, t)
	elif ratio >= 0.50 - half_w and ratio <= 0.50 + half_w:
		var t = (ratio - (0.50 - half_w)) / transition_window
		var val_start = ZONE_METRICS[2][metric_name + "_min"] if use_range else ZONE_METRICS[2][metric_name]
		var val_end = ZONE_METRICS[3][metric_name + "_max"] if use_range else ZONE_METRICS[3][metric_name]
		return lerp(val_start, val_end, t)
	elif ratio >= 0.75 - half_w and ratio <= 0.75 + half_w:
		var t = (ratio - (0.75 - half_w)) / transition_window
		var val_start = ZONE_METRICS[3][metric_name + "_min"] if use_range else ZONE_METRICS[3][metric_name]
		var val_end = ZONE_METRICS[4][metric_name + "_max"] if use_range else ZONE_METRICS[4][metric_name]
		return lerp(val_start, val_end, t)
		
	# Otherwise, we are inside a specific zone
	if use_range:
		# Linearly map within the zone's active range
		var z_start := 0.0
		var z_end := 1.0
		match zone:
			1:
				z_start = 0.0
				z_end = 0.25 - half_w
			2:
				z_start = 0.25 + half_w
				z_end = 0.50 - half_w
			3:
				z_start = 0.50 + half_w
				z_end = 0.75 - half_w
			4:
				z_start = 0.75 + half_w
				z_end = 1.0
		var t = (ratio - z_start) / (z_end - z_start)
		return lerp(ZONE_METRICS[zone][metric_name + "_max"], ZONE_METRICS[zone][metric_name + "_min"], t)
	else:
		return ZONE_METRICS[zone][metric_name]

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
	
	# Apply updated values using the helper function
	water_quality_index = get_metric_value("wqi", progress_ratio)
	dissolved_oxygen = get_metric_value("do", progress_ratio)
	water_flow_speed = get_metric_value("flow_speed", progress_ratio)
	turbidity_visibility = get_metric_value("visibility", progress_ratio)
	
	# Emit signals
	if has_zone_changed:
		zone_changed.emit(current_zone)
		
	metrics_updated.emit(water_quality_index, dissolved_oxygen)

## Helper function to get zone details
func get_zone_name() -> String:
	return ZONE_METRICS[current_zone]["name"]

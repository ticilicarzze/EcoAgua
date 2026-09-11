extends Node

## Centralized State Manager for EcoAguaUNR
## Manages water metrics and zones based on the progress_ratio of the path.

# Signals
signal zone_changed(new_zone: int)
signal metrics_updated(wqi: float, do: float, turbidez: float)

# =========================================================
# MÉTRICAS POR ZONA — Valores reales (Arroyo Ludueña / EcoAgua 2026)
# =========================================================
# Zona 1: Excelente | Zona 2: Bueno | Zona 3: Regular | Zona 4: Pésima
# Los parámetros con valor null no aplican para esa zona y no se muestran en el HUD.
const ZONE_METRICS = {
	1: {
		"name":           "Baseline (Excelente)",
		"wqi_min":        91.0,
		"wqi_max":        100.0,
		"do_min":         9.0,
		"do_max":         9.0,
		"no3":            1.0,    # Nitratos (mg/L)
		"nh4":            0.05,   # Amonio (mg/L)
		"po4":            0.03,   # Fosfatos (mg/L)
		"dbo":            -1.0,   # No aplica
		"coliforms":      -1.0,   # No aplica
		"cr":             -1.0,   # No aplica
		"flow_speed":     1.8,
		"wave_amplitude": 1.0,
		"visibility_min": 120.0,
		"visibility_max": 160.0,
		"turbidez":       1.0
	},
	2: {
		"name":           "Agrícola / Ganadero (Bueno)",
		"wqi_min":        71.0,
		"wqi_max":        90.0,
		"do_min":         7.5,
		"do_max":         7.5,
		"no3":            4.0,    # Nitratos (mg/L)
		"nh4":            -1.0,   # No aplica
		"po4":            1.0,    # Fosfatos (mg/L)
		"dbo":            -1.0,   # No aplica
		"coliforms":      -1.0,   # No aplica
		"cr":             -1.0,   # No aplica
		"flow_speed":     1.2,
		"wave_amplitude": 0.85,
		"visibility_min": 70.0,
		"visibility_max": 90.0,
		"turbidez":       0.75
	},
	3: {
		"name":           "Periurbano / Agroindustrial (Regular)",
		"wqi_min":        51.0,
		"wqi_max":        70.0,
		"do_min":         8.5,
		"do_max":         8.5,
		"no3":            -1.0,   # No aplica
		"nh4":            0.2,    # Amonio (mg/L)
		"po4":            -1.0,   # No aplica
		"dbo":            4.6,    # DBO (mg/L)
		"coliforms":      3090.0, # Coliformes fecales (UFC/100 mL)
		"cr":             -1.0,   # No aplica
		"flow_speed":     0.35,
		"wave_amplitude": 0.30,
		"visibility_min": 40.0,
		"visibility_max": 60.0,
		"turbidez":       0.50
	},
	4: {
		"name":           "Mixta Cloacal+Industrial (Pésima)",
		"wqi_min":        0.0,
		"wqi_max":        25.0,
		"do_min":         5.5,
		"do_max":         5.5,
		"no3":            -1.0,       # No aplica
		"nh4":            1.8,        # Amonio (mg/L)
		"po4":            -1.0,       # No aplica
		"dbo":            20.0,       # DBO (mg/L)
		"coliforms":      780000.0,   # Coliformes fecales (UFC/100 mL)
		"cr":             60.0,       # Cromo Total (µg/L) — contaminación industrial
		"flow_speed":     0.18,
		"wave_amplitude": 0.15,
		"visibility_min": 15.0,
		"visibility_max": 20.0,
		"turbidez":       0.30
	}
}

# Nombres de estado para el encabezado del HUD
const ZONE_STATUS_NAMES: Dictionary = {
	1: "ESTADO EXCELENTE",
	2: "ESTADO BUENO",
	3: "ESTADO REGULAR",
	4: "ESTADO PÉSIMO"
}

# Nota de fauna para Zona 4 (contaminación extrema)
const ZONE_FAUNA_NOTES: Dictionary = {
	4: "Madrecita (C. decemmaculatus) · Anguila criolla (S. marmoratus)"
}

# =========================================================
# Configurable settings
# =========================================================
@export var use_interpolation: bool = true
@export var transition_window: float = 0.05 # Ventana de transición: 5% centrada en el límite de zona

# State variables
var current_zone: int = 1
var water_quality_index: float = 95.0
var dissolved_oxygen: float = 9.0
var water_flow_speed: float = 1.8
var wave_amplitude: float = 1.0
var turbidity_visibility: float = 0.6
var turbidez: float = 1.0

# Setter automático: cada vez que se asigna progress_ratio se recalculan las métricas
var progress_ratio: float = 0.0:
	set(value):
		progress_ratio = clamp(value, 0.0, 1.0)
		_update_metrics()

func _ready() -> void:
	_update_metrics()

# =========================================================
# get_zone_parameters — Retorna los parámetros activos de la zona indicada.
# Los parámetros con valor -1.0 no aplican para esa zona y se omiten.
# =========================================================
func get_zone_parameters(zone: int) -> Dictionary:
	if not ZONE_METRICS.has(zone):
		return {}
	var m: Dictionary = ZONE_METRICS[zone]
	var result: Dictionary = {}
	result["do"]        = get_metric_value("do", progress_ratio)
	# Parámetros fijos por zona (no interpolados entre zonas)
	if m["no3"]       >= 0.0: result["no3"]       = m["no3"]
	if m["nh4"]       >= 0.0: result["nh4"]       = m["nh4"]
	if m["po4"]       >= 0.0: result["po4"]       = m["po4"]
	if m["dbo"]       >= 0.0: result["dbo"]       = m["dbo"]
	if m["coliforms"] >= 0.0: result["coliforms"] = m["coliforms"]
	if m["cr"]        >= 0.0: result["cr"]        = m["cr"]
	return result

# =========================================================
# get_metric_value — Valor interpolado de una métrica según el ratio de avance
# =========================================================
func get_metric_value(metric_name: String, ratio: float) -> float:
	var use_range := (metric_name + "_min") in ZONE_METRICS[1]

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
			return 0.5 * (ZONE_METRICS[zone][metric_name + "_min"] + ZONE_METRICS[zone][metric_name + "_max"])
		else:
			return ZONE_METRICS[zone][metric_name]

	var half_w := transition_window / 2.0

	if ratio >= 0.25 - half_w and ratio <= 0.25 + half_w:
		var t := (ratio - (0.25 - half_w)) / transition_window
		var val_start: float = ZONE_METRICS[1][metric_name + "_min"] if use_range else ZONE_METRICS[1][metric_name]
		var val_end:   float = ZONE_METRICS[2][metric_name + "_max"] if use_range else ZONE_METRICS[2][metric_name]
		return lerp(val_start, val_end, t)
	elif ratio >= 0.50 - half_w and ratio <= 0.50 + half_w:
		var t := (ratio - (0.50 - half_w)) / transition_window
		var val_start: float = ZONE_METRICS[2][metric_name + "_min"] if use_range else ZONE_METRICS[2][metric_name]
		var val_end:   float = ZONE_METRICS[3][metric_name + "_max"] if use_range else ZONE_METRICS[3][metric_name]
		return lerp(val_start, val_end, t)
	elif ratio >= 0.75 - half_w and ratio <= 0.75 + half_w:
		var t := (ratio - (0.75 - half_w)) / transition_window
		var val_start: float = ZONE_METRICS[3][metric_name + "_min"] if use_range else ZONE_METRICS[3][metric_name]
		var val_end:   float = ZONE_METRICS[4][metric_name + "_max"] if use_range else ZONE_METRICS[4][metric_name]
		return lerp(val_start, val_end, t)

	if use_range:
		var z_start := 0.0
		var z_end   := 1.0
		match zone:
			1: z_start = 0.0;            z_end = 0.25 - half_w
			2: z_start = 0.25 + half_w;  z_end = 0.50 - half_w
			3: z_start = 0.50 + half_w;  z_end = 0.75 - half_w
			4: z_start = 0.75 + half_w;  z_end = 1.0
		var t := (ratio - z_start) / (z_end - z_start)
		return lerp(ZONE_METRICS[zone][metric_name + "_max"], ZONE_METRICS[zone][metric_name + "_min"], t)
	else:
		return ZONE_METRICS[zone][metric_name]

# =========================================================
# _update_metrics — Recalcula estado y emite señales
# =========================================================
func _update_metrics() -> void:
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

	water_quality_index  = get_metric_value("wqi",            progress_ratio)
	dissolved_oxygen     = get_metric_value("do",             progress_ratio)
	water_flow_speed     = get_metric_value("flow_speed",     progress_ratio)
	wave_amplitude       = get_metric_value("wave_amplitude", progress_ratio)
	turbidity_visibility = get_metric_value("visibility",     progress_ratio)
	turbidez             = get_metric_value("turbidez",       progress_ratio)

	if has_zone_changed:
		zone_changed.emit(current_zone)

	metrics_updated.emit(water_quality_index, dissolved_oxygen, turbidez)

## Helper: nombre de la zona actual
func get_zone_name() -> String:
	return ZONE_METRICS[current_zone]["name"]

## Helper: nombre de estado para el HUD
func get_zone_status() -> String:
	return ZONE_STATUS_NAMES.get(current_zone, "")

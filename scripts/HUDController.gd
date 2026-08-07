extends CanvasLayer

## HUDController — EcoAguaUNR
## Controlador dinámico de interfaz gráfica (HUD).
## Escucha las señales de WaterManager para actualizar el ICA y el Oxígeno Disuelto (O2).

@onready var margin_top_left: MarginContainer = $Control/MarginContainer
@onready var margin_bottom_left: MarginContainer = $Control/MarginContainer2

@onready var label_ica: Label = $Control/MarginContainer/VBoxContainer/Label
@onready var bar_ica: TextureProgressBar = $Control/MarginContainer/VBoxContainer/TextureProgressBar

@onready var bar_o2: TextureProgressBar = $Control/MarginContainer2/VBoxContainer/TextureProgressBar
@onready var label_o2: Label = $Control/MarginContainer2/VBoxContainer/TextureProgressBar/Label
@onready var icon_eye: TextureRect = $Control/MarginContainer2/VBoxContainer/TextureRect

# Paleta de colores para indicadores (Verde -> Amarillo -> Rojo)
const COLOR_EXCELLENT := Color(0.2, 0.85, 0.3, 1.0)   # Verde limpio (Z1)
const COLOR_MODERATE  := Color(0.95, 0.75, 0.15, 1.0)  # Amarillo / Naranja (Z2-Z3)
const COLOR_CRITICAL  := Color(0.9, 0.25, 0.2, 1.0)   # Rojo crítico (Z4)

var _base_bottom_left_y: float = 0.0
var _floating_time: float = 0.0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	# Posicionar MarginContainer Top-Left (ICA)
	if margin_top_left:
		margin_top_left.anchor_left = 0.0
		margin_top_left.anchor_top = 0.0
		margin_top_left.anchor_right = 0.0
		margin_top_left.anchor_bottom = 0.0
		margin_top_left.offset_left = 35
		margin_top_left.offset_top = 35
		margin_top_left.offset_right = 235
		margin_top_left.offset_bottom = 115
	
	# Posicionar MarginContainer Bottom-Left (O2)
	if margin_bottom_left:
		margin_bottom_left.anchor_left = 0.0
		margin_bottom_left.anchor_top = 1.0
		margin_bottom_left.anchor_right = 0.0
		margin_bottom_left.anchor_bottom = 1.0
		margin_bottom_left.offset_left = 35
		margin_bottom_left.offset_top = -180
		margin_bottom_left.offset_right = 185
		margin_bottom_left.offset_bottom = -30
		_base_bottom_left_y = margin_bottom_left.offset_top
	
	# Conectar con las métricas de WaterManager
	if WaterManager:
		WaterManager.metrics_updated.connect(_on_metrics_updated)
		_on_metrics_updated(WaterManager.water_quality_index, WaterManager.dissolved_oxygen, WaterManager.turbidez)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Sutil bamboleo del HUD para simular flotación bajo la corriente
	_floating_time += delta * 2.0
	if margin_bottom_left:
		margin_bottom_left.offset_top = _base_bottom_left_y + sin(_floating_time) * 3.0

func _on_metrics_updated(wqi: float, do_val: float, _turb: float) -> void:
	# 1. Indicador ICA (0 a 100)
	if label_ica:
		label_ica.text = "ICA: %d" % int(wqi)
	if bar_ica:
		_animate_bar(bar_ica, wqi, 100.0)

	# 2. Indicador Oxígeno Disuelto (DO) - Rango 0.0 a 9.0 mg/L
	if label_o2:
		label_o2.text = "O₂\n%.1f" % do_val
	if bar_o2:
		var o2_pct = clamp((do_val / 9.0) * 100.0, 0.0, 100.0)
		_animate_bar(bar_o2, o2_pct, 100.0)

func _animate_bar(bar: TextureProgressBar, value: float, max_val: float) -> void:
	bar.max_value = max_val
	var pct: float = clamp(value / max_val, 0.0, 1.0)
	
	# Determinar color suavizado según porcentaje
	var target_col: Color
	if pct >= 0.7:
		target_col = COLOR_MODERATE.lerp(COLOR_EXCELLENT, (pct - 0.7) / 0.3)
	elif pct >= 0.4:
		target_col = COLOR_CRITICAL.lerp(COLOR_MODERATE, (pct - 0.4) / 0.3)
	else:
		target_col = COLOR_CRITICAL
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(bar, "value", value, 0.4).set_trans(Tween.TRANS_SINE)
	if bar.texture_progress != null:
		tween.tween_property(bar, "tint_progress", target_col, 0.4)
	else:
		tween.tween_property(bar, "self_modulate", target_col, 0.4)

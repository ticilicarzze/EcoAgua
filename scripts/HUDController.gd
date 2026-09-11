extends CanvasLayer

## HUDController — EcoAguaUNR
## Nuevo HUD dinámico construido completamente por código.
##
## Layout (igual al mockup UI KIT):
##   • Panel inferior-izquierdo: título de zona + lista de parámetros con bullet ●
##   • Panel inferior-centro:    "Índice de Calidad del Agua" + barra horizontal + valor numérico
##
## Estilo visual (Especificaciones_HUD_Ecoagua.md):
##   • Fondo: #000000 al 50% de opacidad
##   • Borde: 1.7 pt, radio 10 pt
##   • Color de borde / acentos = color de zona
##   • Tipografía: Cousine (Bold para títulos y valores, Regular para etiquetas)
##   • Fallback: fuente por defecto de Godot si Cousine no está en assets/

# ─── Colores por zona ─────────────────────────────────────────────────────────
const ZONE_COLORS: Array[Color] = [
	Color(0, 0, 0, 0),                              # índice 0 reservado
	Color(0x1A / 255.0, 0xAC / 255.0, 0x04 / 255.0), # Z1 #1AAC04 — Verde Excelente
	Color(0xD0 / 255.0, 0xD5 / 255.0, 0x36 / 255.0), # Z2 #D0D536 — Amarillo Bueno
	Color(0xEB / 255.0, 0x76 / 255.0, 0x00 / 255.0), # Z3 #EB7600 — Naranja Regular
	Color(0xFF / 255.0, 0x00 / 255.0, 0x00 / 255.0), # Z4 #FF0000 — Rojo Pésimo
]

const ZONE_STATUS_LABELS: Array[String] = [
	"",
	"ESTADO EXCELENTE",
	"ESTADO BUENO",
	"ESTADO REGULAR",
	"ESTADO PÉSIMO",
]

# Constantes de estilo
const PANEL_BG_COLOR    := Color(0.0, 0.0, 0.0, 0.55)
const BORDER_WIDTH      := 2
const CORNER_RADIUS     := 10
const MARGIN_SCREEN     := 35         # Margen desde el borde de pantalla
const MARGIN_BOTTOM     := 30         # Margen desde el borde inferior
const PARAM_FONT_SIZE   := 12
const TITLE_FONT_SIZE   := 13
const ICA_NUM_FONT_SIZE := 14

# ─── Definición de parámetros por zona ───────────────────────────────────────
# Formato: [nombre_display, clave_en_diccionario, unidad]
const ZONE_PARAMS: Dictionary = {
	1: [
		["Oxígeno Disuelto", "do",  "mg/L"],
		["Amonio",           "nh4", "mg/L"],
		["Nitratos",         "no3", "mg/L"],
		["Fosfatos",         "po4", "mg/L"],
	],
	2: [
		["Oxígeno Disuelto", "do",  "mg/L"],
		["Nitratos",         "no3", "mg/L"],
		["Fosfatos",         "po4", "mg/L"],
	],
	3: [
		["Oxígeno Disuelto", "do",        "mg/L"],
		["Amonio",           "nh4",       "mg/L"],
		["DBO",              "dbo",       "mg/L"],
		["Coliformes Fec.",  "coliforms", "UFC/100mL"],
	],
	4: [
		["Oxígeno Disuelto", "do",        "mg/L"],
		["Amonio",           "nh4",       "mg/L"],
		["DBO",              "dbo",       "mg/L"],
		["Coliformes Fec.",  "coliforms", "UFC/100mL"],
		["Cromo Total",      "cr",        "µg/L"],
	],
}

# Número máximo de filas de parámetros (zona 4 tiene 5)
const MAX_PARAM_ROWS := 5

# ─── Nodos del HUD ────────────────────────────────────────────────────────────
var _root: Control

# Panel de parámetros (inferior-izquierdo)
var _param_panel: PanelContainer
var _zone_title:   Label
var _param_rows:   Array = []     # Array de Dictionary {row, dot, name_lbl, val_lbl}
var _separator:    HSeparator

# Panel ICA (inferior-centro)
var _ica_panel:       PanelContainer
var _ica_title_lbl:   Label
var _ica_value_lbl:   Label
var _ica_bar:         ProgressBar
var _ica_bar_fill:    StyleBoxFlat

# Fuentes
var _font_bold:    Font = null
var _font_regular: Font = null

# Estado interno
var _current_zone:        int   = 1
var _floating_time:       float = 0.0
var _param_panel_base_y:  float = 0.0
var _ica_panel_base_y:    float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_load_fonts()
	_build_hud()

	if WaterManager:
		WaterManager.zone_changed.connect(_on_zone_changed)
		WaterManager.metrics_updated.connect(_on_metrics_updated)
		# Estado inicial
		_on_zone_changed(WaterManager.current_zone)
		_update_ica(WaterManager.water_quality_index)

# ─── Carga de fuentes ─────────────────────────────────────────────────────────
func _load_fonts() -> void:
	var bold_path    := "res://assets/fonts/Cousine/Cousine/Cousine-Bold.ttf"
	var regular_path := "res://assets/fonts/Cousine/Cousine/Cousine-Regular.ttf"
	if ResourceLoader.exists(bold_path):
		_font_bold = load(bold_path)
	else:
		push_warning("HUD: Cousine-Bold.ttf no encontrada en assets/fonts/Cousine/Cousine/. Usando fuente por defecto.")
	if ResourceLoader.exists(regular_path):
		_font_regular = load(regular_path)
	else:
		push_warning("HUD: Cousine-Regular.ttf no encontrada en assets/fonts/Cousine/Cousine/. Usando fuente por defecto.")

# ─────────────────────────────────────────────────────────────────────────────
# CONSTRUCCIÓN DEL HUD
# ─────────────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_build_param_panel()
	_build_ica_panel()

# ─── Panel de parámetros (inferior-izquierdo) ─────────────────────────────────
func _build_param_panel() -> void:
	_param_panel = PanelContainer.new()
	_param_panel.name = "ParamPanel"
	_param_panel.add_theme_stylebox_override("panel", _make_panel_style(ZONE_COLORS[1]))

	# Ancla: esquina inferior-izquierda
	_param_panel.anchor_left   = 0.0
	_param_panel.anchor_top    = 1.0
	_param_panel.anchor_right  = 0.0
	_param_panel.anchor_bottom = 1.0
	_param_panel.offset_left   = MARGIN_SCREEN
	_param_panel.offset_right  = MARGIN_SCREEN + 260
	_param_panel.offset_bottom = -MARGIN_BOTTOM
	_param_panel.offset_top    = -MARGIN_BOTTOM - 160  # altura inicial (se ajusta dinámicamente)
	_param_panel_base_y = _param_panel.offset_top

	_root.add_child(_param_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_param_panel.add_child(vbox)

	# Título de zona
	_zone_title = _make_label("ZONA 1 - ESTADO EXCELENTE", true, TITLE_FONT_SIZE, ZONE_COLORS[1])
	vbox.add_child(_zone_title)

	# Separador horizontal con el color de zona
	_separator = HSeparator.new()
	_separator.add_theme_color_override("color", ZONE_COLORS[1])
	_separator.add_theme_constant_override("separation", 2)
	vbox.add_child(_separator)

	# Filas de parámetros (se construyen todas, la visibilidad se gestiona por zona)
	_param_rows.clear()
	for _i in range(MAX_PARAM_ROWS):
		var row_data := _build_param_row(ZONE_COLORS[1])
		row_data["row"].visible = false
		vbox.add_child(row_data["row"])
		_param_rows.append(row_data)

# Construye una fila de parámetro vacía reutilizable
func _build_param_row(col: Color) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# Bullet ●
	var dot := _make_label("●", false, 10, col)
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.custom_minimum_size = Vector2(14, 0)
	row.add_child(dot)

	# Nombre del parámetro (minúsculas, Regular, se expande)
	var name_lbl := _make_label("—", false, PARAM_FONT_SIZE, Color.WHITE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	# Valor + unidad (Bold, alineado a la derecha, en color de zona)
	var val_lbl := _make_label("—", true, PARAM_FONT_SIZE, col)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.custom_minimum_size = Vector2(90, 0)
	row.add_child(val_lbl)

	return {"row": row, "dot": dot, "name_lbl": name_lbl, "val_lbl": val_lbl}

# ─── Panel ICA (inferior-centro) ──────────────────────────────────────────────
func _build_ica_panel() -> void:
	_ica_panel = PanelContainer.new()
	_ica_panel.name = "ICAPanel"
	_ica_panel.add_theme_stylebox_override("panel", _make_panel_style(ZONE_COLORS[1]))

	# Ancla: borde inferior, centrado horizontalmente
	_ica_panel.anchor_left   = 0.5
	_ica_panel.anchor_top    = 1.0
	_ica_panel.anchor_right  = 0.5
	_ica_panel.anchor_bottom = 1.0
	_ica_panel.offset_left   = -160
	_ica_panel.offset_right  =  160
	_ica_panel.offset_bottom = -MARGIN_BOTTOM
	_ica_panel.offset_top    = -MARGIN_BOTTOM - 52
	_ica_panel_base_y = _ica_panel.offset_top

	_root.add_child(_ica_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	_ica_panel.add_child(vbox)

	# Fila superior: etiqueta + número ICA
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	vbox.add_child(header_row)

	_ica_title_lbl = _make_label("Índice de Calidad del Agua", false, PARAM_FONT_SIZE, Color.WHITE)
	_ica_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_ica_title_lbl)

	_ica_value_lbl = _make_label("95", true, ICA_NUM_FONT_SIZE, ZONE_COLORS[1])
	_ica_value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_row.add_child(_ica_value_lbl)

	# Barra de progreso horizontal
	_ica_bar = ProgressBar.new()
	_ica_bar.min_value       = 0.0
	_ica_bar.max_value       = 100.0
	_ica_bar.value           = 95.0
	_ica_bar.show_percentage = false
	_ica_bar.custom_minimum_size = Vector2(300, 10)

	# Estilo del fondo de la barra
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.12, 0.12, 0.9)
	bar_bg.corner_radius_top_left     = 4
	bar_bg.corner_radius_top_right    = 4
	bar_bg.corner_radius_bottom_left  = 4
	bar_bg.corner_radius_bottom_right = 4
	_ica_bar.add_theme_stylebox_override("background", bar_bg)

	# Estilo del relleno (se actualiza con el color de zona)
	_ica_bar_fill = StyleBoxFlat.new()
	_ica_bar_fill.bg_color = ZONE_COLORS[1]
	_ica_bar_fill.corner_radius_top_left     = 4
	_ica_bar_fill.corner_radius_top_right    = 4
	_ica_bar_fill.corner_radius_bottom_left  = 4
	_ica_bar_fill.corner_radius_bottom_right = 4
	_ica_bar.add_theme_stylebox_override("fill", _ica_bar_fill)

	vbox.add_child(_ica_bar)

# ─────────────────────────────────────────────────────────────────────────────
# ACTUALIZACIÓN DE ZONA
# ─────────────────────────────────────────────────────────────────────────────
func _on_zone_changed(new_zone: int) -> void:
	_current_zone = new_zone
	var col   := ZONE_COLORS[new_zone]
	var status := ZONE_STATUS_LABELS[new_zone]

	# Actualizar estilos de panel
	var panel_style := _make_panel_style(col)
	_param_panel.add_theme_stylebox_override("panel", panel_style)
	_ica_panel.add_theme_stylebox_override("panel",   _make_panel_style(col))

	# Título
	_zone_title.text = "ZONA %d - %s" % [new_zone, status]
	_zone_title.add_theme_color_override("font_color", col)

	# Separador
	_separator.add_theme_color_override("color", col)

	# Color de la barra ICA y número
	_ica_bar_fill.bg_color = col
	_ica_value_lbl.add_theme_color_override("font_color", col)

	# Rearmar filas de parámetros para esta zona
	_populate_param_rows(new_zone, col)

# Llena las filas de parámetros con los datos de la zona activa
func _populate_param_rows(zone: int, col: Color) -> void:
	var params_def: Array = ZONE_PARAMS.get(zone, [])
	var params_data: Dictionary = {}
	if WaterManager:
		params_data = WaterManager.get_zone_parameters(zone)

	var active_rows: int = params_def.size()

	for i in range(MAX_PARAM_ROWS):
		var rd: Dictionary = _param_rows[i]
		if i < active_rows:
			var def: Array      = params_def[i]
			var display: String = def[0]
			var key:     String = def[1]
			var unit:    String = def[2]
			var value:   float  = params_data.get(key, 0.0)

			(rd["dot"]      as Label).add_theme_color_override("font_color", col)
			(rd["name_lbl"] as Label).text = display.to_lower()
			(rd["val_lbl"]  as Label).text = _format_value(value, unit, key)
			(rd["val_lbl"]  as Label).add_theme_color_override("font_color", col)
			(rd["row"]      as Control).visible = true
		else:
			(rd["row"] as Control).visible = false

	# Ajustar altura del panel al número de filas activas
	# Título(20) + sep(10) + filas(20 c/u) + márgenes internos(16) + separación(vbox)
	var panel_height: float = 20 + 10 + active_rows * 22 + 26
	_param_panel.offset_top = -MARGIN_BOTTOM - panel_height
	_param_panel_base_y     = _param_panel.offset_top

# ─────────────────────────────────────────────────────────────────────────────
# ACTUALIZACIÓN DE MÉTRICAS (cada frame activo de WaterManager)
# ─────────────────────────────────────────────────────────────────────────────
func _on_metrics_updated(wqi: float, _do_val: float, _turb: float) -> void:
	_update_ica(wqi)
	# Actualizar valores de parámetros en tiempo real
	if not WaterManager:
		return
	var params_data := WaterManager.get_zone_parameters(_current_zone)
	var params_def: Array = ZONE_PARAMS.get(_current_zone, [])
	for i in range(min(_param_rows.size(), params_def.size())):
		var def:     Array  = params_def[i]
		var key:     String = def[1]
		var unit:    String = def[2]
		if params_data.has(key):
			var val_lbl := _param_rows[i]["val_lbl"] as Label
			val_lbl.text = _format_value(params_data[key], unit, key)

func _update_ica(wqi: float) -> void:
	if not _ica_bar or not _ica_value_lbl:
		return
	# Animar la barra suavemente
	var tw := create_tween()
	tw.tween_property(_ica_bar, "value", wqi, 0.5).set_trans(Tween.TRANS_SINE)
	# Número ICA sin animación de conteo (se actualiza directamente)
	_ica_value_lbl.text = "%d" % int(wqi)

# ─────────────────────────────────────────────────────────────────────────────
# _process — Efecto de flotación sutil en ambos paneles
# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_floating_time += delta * 1.4
	var wave: float = sin(_floating_time) * 2.0
	if _param_panel:
		_param_panel.offset_top = _param_panel_base_y + wave
	if _ica_panel:
		_ica_panel.offset_top = _ica_panel_base_y + wave * 0.7

# ─────────────────────────────────────────────────────────────────────────────
# UTILIDADES
# ─────────────────────────────────────────────────────────────────────────────

## Crea un Label con el estilo del HUD aplicado
func _make_label(text: String, bold: bool, size: int, col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_font_size_override("font_size", size)
	if bold and _font_bold:
		lbl.add_theme_font_override("font", _font_bold)
	elif not bold and _font_regular:
		lbl.add_theme_font_override("font", _font_regular)
	return lbl

## StyleBoxFlat semitransparente con borde del color de zona
func _make_panel_style(zone_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color                    = PANEL_BG_COLOR
	style.border_color                = zone_color
	style.border_width_left           = BORDER_WIDTH
	style.border_width_right          = BORDER_WIDTH
	style.border_width_top            = BORDER_WIDTH
	style.border_width_bottom         = BORDER_WIDTH
	style.corner_radius_top_left      = CORNER_RADIUS
	style.corner_radius_top_right     = CORNER_RADIUS
	style.corner_radius_bottom_left   = CORNER_RADIUS
	style.corner_radius_bottom_right  = CORNER_RADIUS
	style.content_margin_left         = 10
	style.content_margin_right        = 10
	style.content_margin_top          = 8
	style.content_margin_bottom       = 8
	return style

## Formatea el valor según su tipo/clave
func _format_value(value: float, unit: String, key: String) -> String:
	if key == "coliforms":
		# Coliformes: entero con separador de miles
		var v := int(value)
		if v >= 1000:
			return "%d.%03d %s" % [v / 1000, v % 1000, unit]
		else:
			return "%d %s" % [v, unit]
	elif key == "cr":
		# Cromo: entero en µg/L
		return "%d %s" % [int(value), unit]
	elif value < 0.1:
		return "%.2f %s" % [value, unit]
	elif value < 10.0:
		return "%.1f %s" % [value, unit]
	else:
		return "%.0f %s" % [value, unit]

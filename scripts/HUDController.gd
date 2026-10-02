extends CanvasLayer
class_name HUDController

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

# Constantes de estilo (declaradas como var para que HUDControllerVR pueda sobreescribirlas)
var _is_vr:                   bool  = false
var PANEL_BG_COLOR:           Color = Color(0.0, 0.0, 0.0, 0.55)
var BORDER_WIDTH:             int   = 2
var CORNER_RADIUS:            int   = 10
var MARGIN_SCREEN:            int   = 35   # Margen desde el borde de pantalla
var MARGIN_BOTTOM:            int   = 30   # Margen desde el borde inferior
var PARAM_FONT_SIZE:          int   = 12
var TITLE_FONT_SIZE:          int   = 13
var ICA_NUM_FONT_SIZE:        int   = 14
var PARAM_PANEL_WIDTH:        int   = 260  # Ancho del panel de parámetros (px)
var PARAM_VAL_COL_WIDTH:      int   = 90   # Ancho de la columna de valores (px)
var ICA_PANEL_HALF_W:         int   = 160  # Semiancho del panel ICA (px)
var ICA_BAR_HEIGHT:           int   = 10   # Altura de la barra ICA (px)

# Subtítulos
var SUBTITLE_ANCHOR_LEFT:     float = 0.25
var SUBTITLE_ANCHOR_RIGHT:    float = 0.75
var SUBTITLE_BOTTOM_OFFSET:   int   = 110
var SUBTITLE_VOICE_FONT_SIZE: int   = 11
var SUBTITLE_TEXT_FONT_SIZE:  int   = 13

# Botón Sumergirse
var DIVE_PANEL_HALF_W:        int   = 160
var DIVE_PANEL_HALF_H:        int   = 36
var DIVE_INTRO_FONT_SIZE:     int   = 13
var DIVE_BTN_FONT_SIZE:       int   = 17
var DIVE_HINT_FONT_SIZE:      int   = 11

# Cartel grande
var CARD_TITLE_FONT_SIZE:     int   = 20
var CARD_PARAM_FONT_SIZE:     int   = 15
var CARD_VAL_FONT_SIZE:       int   = 16
var CARD_ICA_FONT_SIZE:       int   = 14
var CARD_ICA_VAL_FONT_SIZE:   int   = 18

# Créditos
var CREDITS_TITLE_FONT_SIZE:  int   = 28
var CREDITS_SUB_FONT_SIZE:    int   = 16
var CREDITS_BODY_FONT_SIZE:   int   = 13

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
var _sep_style:    StyleBoxLine

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

# ─── Estado narrativo ─────────────────────────────────────────────────────────
# Referencia al panel de cartel grande y al panel de subtítulos/texto narrativo
var _big_card_panel:     Control = null  # Panel central grande de parámetros
var _subtitle_panel:     Control = null  # Panel de subtítulos/locución
var _subtitle_label:     Label   = null
var _subtitle_voice_lbl: Label   = null  # Etiqueta del nombre de la voz (Arroyo / Intérprete)
var _subtitle_tween:     Tween   = null  # Tween para secuenciar oraciones de subtítulos
var _dive_button_panel:  Control = null  # Panel con botón "Sumergirse"
var _credits_panel:      Control = null  # Panel de créditos finales
var _main_node:          Node    = null  # Referencia al nodo main para llamar on_dive_button_pressed
var _big_card_visible:   bool    = false # Estado del cartel grande


# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_load_fonts()
	_build_hud()

	if WaterManager:
		if not WaterManager.zone_changed.is_connected(_on_zone_changed):
			WaterManager.zone_changed.connect(_on_zone_changed)
		if not WaterManager.metrics_updated.is_connected(_on_metrics_updated):
			WaterManager.metrics_updated.connect(_on_metrics_updated)
		# Estado inicial
		_on_zone_changed(WaterManager.current_zone)
		_update_ica(WaterManager.water_quality_index)

	# Buscar nodo main para comunicar el botón "Sumergirse"
	_main_node = get_tree().get_root().get_node_or_null("Main") \
		if get_tree().get_root().has_node("Main") else null
	if not _main_node:
		# Intentar buscar el primer nodo que tenga on_dive_button_pressed
		for child in get_tree().get_root().get_children():
			if child.has_method("on_dive_button_pressed"):
				_main_node = child
				break

	# Construir elementos narrativos
	_build_narrative_ui()

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
func _get_hud_parent() -> Node:
	return self

func _build_hud() -> void:
	var parent_node := _get_hud_parent()
	for child in parent_node.get_children():
		if child is Control:
			child.queue_free()

	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _is_vr:
		_root.custom_minimum_size = Vector2(1920, 1080)
	parent_node.add_child(_root)

	_build_param_panel()
	_build_ica_panel()

# ─── Panel de parámetros (inferior-izquierdo) ─────────────────────────────────
func _build_param_panel() -> void:
	_param_panel = PanelContainer.new()
	_param_panel.name = "ParamPanel"
	_param_panel.add_theme_stylebox_override("panel", _make_panel_style(ZONE_COLORS[1]))

	# Ancla: esquina inferior-izquierda
	_param_panel.anchor_left     = 0.0
	_param_panel.anchor_top      = 1.0
	_param_panel.anchor_right    = 0.0
	_param_panel.anchor_bottom   = 1.0
	_param_panel.grow_horizontal = Control.GROW_DIRECTION_END
	_param_panel.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	_param_panel.offset_left     = MARGIN_SCREEN
	_param_panel.offset_right    = MARGIN_SCREEN + PARAM_PANEL_WIDTH
	_param_panel.offset_bottom   = -MARGIN_BOTTOM
	_param_panel.offset_top      = -MARGIN_BOTTOM
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
	_sep_style = StyleBoxLine.new()
	_sep_style.color = ZONE_COLORS[1]
	_sep_style.thickness = 1
	_separator.add_theme_stylebox_override("separator", _sep_style)
	_separator.add_theme_constant_override("separation", 4)
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
	var dot := _make_label("●", false, max(8, PARAM_FONT_SIZE - 2), col)
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.custom_minimum_size = Vector2(PARAM_FONT_SIZE + 2, 0)
	row.add_child(dot)

	# Nombre del parámetro (minúsculas, Regular, se expande)
	var name_lbl := _make_label("—", false, PARAM_FONT_SIZE, Color.WHITE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	# Valor + unidad (Bold, alineado a la derecha, en color de zona)
	var val_lbl := _make_label("—", true, PARAM_FONT_SIZE, col)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.custom_minimum_size = Vector2(PARAM_VAL_COL_WIDTH, 0)
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
	_ica_panel.offset_left   = -ICA_PANEL_HALF_W
	_ica_panel.offset_right  =  ICA_PANEL_HALF_W
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
	_ica_bar.custom_minimum_size = Vector2(ICA_PANEL_HALF_W * 2 - 20, ICA_BAR_HEIGHT)

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
	if _sep_style:
		_sep_style.color = col

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
			(rd["name_lbl"] as Label).text = display
			(rd["val_lbl"]  as Label).text = _format_value(value, unit, key)
			(rd["val_lbl"]  as Label).add_theme_color_override("font_color", col)
			(rd["row"]      as Control).visible = true
		else:
			(rd["row"] as Control).visible = false

	# Ajustar altura del panel exactamente al contenido visible
	_update_param_panel_size()
	_update_param_panel_size.call_deferred()

func _update_param_panel_size() -> void:
	if not _param_panel:
		return
	_param_panel.reset_size()
	var panel_height: float = _param_panel.get_combined_minimum_size().y
	_param_panel.offset_top = -MARGIN_BOTTOM - panel_height
	_param_panel.offset_bottom = -MARGIN_BOTTOM
	_param_panel_base_y = _param_panel.offset_top

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
	_ica_bar.value = wqi
	_ica_value_lbl.text = "%d" % int(round(wqi))

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
		_param_panel.offset_bottom = -MARGIN_BOTTOM + wave
	if _ica_panel:
		_ica_panel.offset_top = _ica_panel_base_y + wave * 0.7
		_ica_panel.offset_bottom = -MARGIN_BOTTOM + wave * 0.7

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
	return "%.0f %s" % [value, unit]

# ═════════════════════════════════════════════════════════════════════════════
# ─── SISTEMA NARRATIVO ────────────────────────────────────────────────────────
# ═════════════════════════════════════════════════════════════════════════════



## Textos de subtítulos por estado (NarrativeState int → Array de secuencias)
## Cada secuencia es un Array: [Voz, Texto, Duración en segundos]
const SUBTITLE_SEQUENCE_BY_STATE: Dictionary = {
	1: [
		["", "", 3.0],
		["El Arroyo", "Hace mucho tiempo que estoy acá. Tal vez, cuando me mirás, ves solamente agua… pero debajo de mi superficie hay mucho más. Hay peces, plantas, insectos y pequeños organismos que también forman parte de mí. ¡Te invito a sumergirte y conocerme mejor!", 18.5]
	],
	4: [
		["El Arroyo", "Aquí el agua todavía es clara, la luz acaricia el fondo y la vida florece en equilibrio. Hay peces, plantas, insectos y pequeños organismos que también forman parte de mí.", 12.5],
		["Intérprete", "Un arroyo no es sólo el agua que vemos. Es un ecosistema en el que sus componentes están muy relacionados y todo funciona como en una gran orquesta.", 10.0]
	],
	5: [
		["", "", 3.0],
		["El Arroyo", "El paisaje empieza a cambiar, aparecen los cultivos. Y cuando llueve, el agua arrastra y se lleva consigo parte de lo que encuentra en el suelo.", 9.8]
	],
	8: [
		["Intérprete", "La escorrentía puede transportar sedimentos y nutrientes, como nitrógeno y fósforo, desde los campos hacia el arroyo. Éste exceso favorece el crecimiento de algas y plantas acuáticas y se conoce como eutrofización.", 14.6],
		["Intérprete", "A simple vista puede parecer que hay más vida. Pero cuando éstas algas y plantas se descomponen los microorganismos consumen el oxígeno del agua.", 9.9]
	],
	9: [
		["", "", 3.0],
		["El Arroyo", "Esta zona está más urbanizada, hay casas, calles… el agua sigue corriendo, pero ya no llega sola. Trae sustancias que antes no formaban parte de mí. Y a quienes viven en mi interior, les cuesta cada vez más respirar.", 15.8]
	],
	12: [
		["Intérprete", "Los efluentes urbanos e industriales pueden incorporar materia orgánica, amonio, coliformes fecales, y otros contaminantes. Cuando aumenta la materia orgánica, los microorganismos necesitan más oxígeno para degradarla. Ésto aumenta la Demanda Bioquímica de Oxígeno o DBO.", 19.0],
		["Intérprete", "Una consecuencia de todo esto es que queda menos oxígeno disponible para peces e invertebrados.", 6.5]
	],
	13: [
		["", "", 3.0],
		["El Arroyo", "Ahora el paisaje es muy diferente. Algunos creen que sigo igual, porque aún me ven correr, pero no todo lo que cambia puede verse. Por dentro soy diferente. Muchos seres vivos ya no pueden vivir en estas condiciones. Los peces que antes encontraba, los pequeños organismos que casi no vemos… No todos pueden quedarse.", 22.5]
	],
	16: [
		["Intérprete", "El aumento de nutrientes, materia orgánica y otros contaminantes modifica las condiciones del agua y afecta a las comunidades que viven en ella. Las especies sensibles suelen desaparecer primero. Por eso, observar quienes están y quienes ya no, también nos permite conocer la salud de un ecosistema. Te recomiendo que salgas de aquí, las condiciones no son aptas.", 24.0]
	],
	18: [
		["Intérprete", "La calidad de un arroyo no puede entenderse solamente mirando el agua. Hay que aprender a leerlo en relación a todo lo que ocurre a su alrededor.", 9.5],
		["El Arroyo", "Si aprendes a mirar todo lo que llevo dentro… Nunca volverás a verme solamente como agua.", 7.0]
	]
}

# ─── Construye la UI narrativa completa (botón, subtítulos, cartel grande, créditos) ──
func _build_narrative_ui() -> void:
	_build_dive_button()
	_build_subtitle_panel()
	_build_big_card_panel()
	_build_credits_panel()

# ─── Panel / Botón "Sumergirse" ───────────────────────────────────────────────
func _build_dive_button() -> void:
	_dive_button_panel = PanelContainer.new()
	_dive_button_panel.name = "DiveButtonPanel"

	# Estilo del panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.78)
	style.border_color = ZONE_COLORS[1]
	style.set_border_width_all(BORDER_WIDTH)
	style.set_corner_radius_all(CORNER_RADIUS + 4)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_dive_button_panel.add_theme_stylebox_override("panel", style)

	# Centrado en pantalla (vertical: 55% desde arriba)
	_dive_button_panel.anchor_left   = 0.5
	_dive_button_panel.anchor_top    = 0.55
	_dive_button_panel.anchor_right  = 0.5
	_dive_button_panel.anchor_bottom = 0.55
	_dive_button_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dive_button_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	_dive_button_panel.offset_left   = -DIVE_PANEL_HALF_W
	_dive_button_panel.offset_right  =  DIVE_PANEL_HALF_W
	_dive_button_panel.offset_top    = -DIVE_PANEL_HALF_H
	_dive_button_panel.offset_bottom =  DIVE_PANEL_HALF_H

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_dive_button_panel.add_child(vbox)

	# Texto introductorio
	var intro_lbl := _make_label("EcoAgua — Arroyo Ludueña", false, DIVE_INTRO_FONT_SIZE, Color(0.85, 0.85, 0.80))
	intro_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(intro_lbl)

	# Botón
	var btn := Button.new()
	btn.text = "🌊  Sumergirse"
	if _font_bold:
		btn.add_theme_font_override("font", _font_bold)
	btn.add_theme_font_size_override("font_size", DIVE_BTN_FONT_SIZE)
	btn.add_theme_color_override("font_color",         ZONE_COLORS[1])
	btn.add_theme_color_override("font_hover_color",   Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", ZONE_COLORS[1].lightened(0.2))
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	btn.add_theme_stylebox_override("normal",   btn_style)
	btn.add_theme_stylebox_override("hover",    btn_style)
	btn.add_theme_stylebox_override("pressed",  btn_style)
	btn.add_theme_stylebox_override("focus",    btn_style)
	btn.pressed.connect(_on_dive_button_pressed)
	vbox.add_child(btn)

	# Texto indicativo para VR / Teclado
	var hint_text := "Presioná cualquier botón del mando para sumergirte" if _is_vr else "Clic o presiona cualquier botón para sumergirte"
	var hint_lbl := _make_label(hint_text, false, DIVE_HINT_FONT_SIZE, Color(0.75, 0.90, 1.0, 0.85))
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_lbl)

	_root.add_child(_dive_button_panel)

# ─── Panel de subtítulos / locución ──────────────────────────────────────────
func _build_subtitle_panel() -> void:
	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.name = "SubtitlePanel"
	_subtitle_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	style.border_color = Color(1.0, 1.0, 1.0, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top   = 12
	style.content_margin_bottom = 12
	_subtitle_panel.add_theme_stylebox_override("panel", style)

	# Centrado horizontalmente ocupando la parte inferior
	_subtitle_panel.anchor_left   = SUBTITLE_ANCHOR_LEFT
	_subtitle_panel.anchor_right  = SUBTITLE_ANCHOR_RIGHT
	_subtitle_panel.anchor_top    = 1.0
	_subtitle_panel.anchor_bottom = 1.0
	_subtitle_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_subtitle_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_subtitle_panel.offset_left   = 0
	_subtitle_panel.offset_right  = 0
	_subtitle_panel.offset_bottom = -SUBTITLE_BOTTOM_OFFSET
	_subtitle_panel.offset_top    = -SUBTITLE_BOTTOM_OFFSET

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	_subtitle_panel.add_child(vbox)

	_subtitle_voice_lbl = _make_label("", true, SUBTITLE_VOICE_FONT_SIZE, Color(0.7, 0.85, 1.0, 0.85))
	_subtitle_voice_lbl.name = "VoiceLabel"
	_subtitle_voice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_subtitle_voice_lbl)

	_subtitle_label = _make_label("", false, SUBTITLE_TEXT_FONT_SIZE, Color.WHITE)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_subtitle_label)

	_root.add_child(_subtitle_panel)

# ─── Panel de cartel grande de parámetros ────────────────────────────────────
func _build_big_card_panel() -> void:
	_big_card_panel = PanelContainer.new()
	_big_card_panel.name = "BigCardPanel"
	_big_card_panel.visible = false

	# Centrado en pantalla pero más chico
	_big_card_panel.anchor_left   = 0.22
	_big_card_panel.anchor_right  = 0.78
	_big_card_panel.anchor_top    = 0.22
	_big_card_panel.anchor_bottom = 0.75
	_root.add_child(_big_card_panel)

func _show_big_card(zone: int) -> void:
	if not _big_card_panel:
		return
	_big_card_visible = true

	# Limpiar contenido anterior
	for child in _big_card_panel.get_children():
		child.queue_free()

	var col := ZONE_COLORS[zone]

	# Estilo del panel grande
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.88)
	style.border_color = col
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_big_card_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_big_card_panel.add_child(vbox)

	# Título grande de zona
	var title := _make_label(
		"ZONA %d  –  %s" % [zone, ZONE_STATUS_LABELS[zone]],
		true, CARD_TITLE_FONT_SIZE, col
	)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separador
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = col
	sep_style.thickness = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# Parámetros
	var params_def: Array = ZONE_PARAMS.get(zone, [])
	var params_data: Dictionary = WaterManager.get_zone_parameters(zone) if WaterManager else {}

	for def in params_def:
		var display: String = def[0]
		var key:     String = def[1]
		var unit:    String = def[2]
		var value:   float  = params_data.get(key, 0.0)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var dot := _make_label("●", false, max(8, CARD_PARAM_FONT_SIZE - 2), col)
		dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.custom_minimum_size = Vector2(CARD_PARAM_FONT_SIZE + 2, 0)
		row.add_child(dot)

		var name_lbl := _make_label(display, false, CARD_PARAM_FONT_SIZE, Color.WHITE)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var val_lbl := _make_label(_format_value(value, unit, key), true, CARD_VAL_FONT_SIZE, col)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.custom_minimum_size = Vector2(PARAM_VAL_COL_WIDTH + 30, 0)
		row.add_child(val_lbl)

		vbox.add_child(row)

	# ICA grande
	var sep2 := HSeparator.new()
	sep2.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep2)

	var wqi: float = WaterManager.water_quality_index if WaterManager else 75.0
	var ica_row := HBoxContainer.new()
	ica_row.add_theme_constant_override("separation", 10)
	var ica_lbl := _make_label("Índice de Calidad del Agua:", false, CARD_ICA_FONT_SIZE, Color.WHITE)
	ica_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ica_row.add_child(ica_lbl)
	var ica_val := _make_label("%d / 100" % int(round(wqi)), true, CARD_ICA_VAL_FONT_SIZE, col)
	ica_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ica_row.add_child(ica_val)
	vbox.add_child(ica_row)

	_big_card_panel.visible = true

func _hide_big_card_animated() -> void:
	if not _big_card_panel or not _big_card_visible:
		return
	_big_card_visible = false
	# Animación: encoger hacia la esquina inferior-izquierda con un Tween
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_big_card_panel, "anchor_left",   0.0,  0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_big_card_panel, "anchor_top",    1.0,  0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_big_card_panel, "anchor_right",  0.30, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_big_card_panel, "anchor_bottom", 1.0,  0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_big_card_panel, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	_big_card_panel.visible = false
	# Restaurar anclas para la próxima vez que se muestre
	_big_card_panel.anchor_left   = 0.22
	_big_card_panel.anchor_right  = 0.78
	_big_card_panel.anchor_top    = 0.22
	_big_card_panel.anchor_bottom = 0.75
	_big_card_panel.modulate.a = 1.0

# ─── Panel de créditos ────────────────────────────────────────────────────────
func _build_credits_panel() -> void:
	_credits_panel = PanelContainer.new()
	_credits_panel.name = "CreditsPanel"
	_credits_panel.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.92)
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	_credits_panel.add_theme_stylebox_override("panel", style)

	_credits_panel.anchor_left   = 0.0
	_credits_panel.anchor_right  = 1.0
	_credits_panel.anchor_top    = 0.0
	_credits_panel.anchor_bottom = 1.0

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	_credits_panel.add_child(vbox)

	var title := _make_label("EcoAgua — Arroyo Ludueña", true, CREDITS_TITLE_FONT_SIZE, ZONE_COLORS[1])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := _make_label("Universidad Nacional de Rosario", false, CREDITS_SUB_FONT_SIZE, Color(0.85, 0.85, 0.80))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var sep := HSeparator.new()
	var sep_st := StyleBoxLine.new()
	sep_st.color = ZONE_COLORS[1]
	sep_st.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_st)
	vbox.add_child(sep)

	var credits_text := [
		"Investigación y contenido científico: Equipo EcoAgua UNR",
		"Desarrollo 3D / VR: Taller de Tecnologías Creativas UNR",
		"Basado en datos reales del Arroyo Ludueña — Amaya et al. (2018)",
	]
	for line in credits_text:
		var lbl := _make_label(line, false, CREDITS_BODY_FONT_SIZE, Color(0.75, 0.75, 0.72))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(lbl)

	_root.add_child(_credits_panel)

# ─── Callback del botón "Sumergirse" ─────────────────────────────────────────
func _on_dive_button_pressed() -> void:
	# Ocultar el botón con un fadeout suave
	if _dive_button_panel:
		var tw := create_tween()
		tw.tween_property(_dive_button_panel, "modulate:a", 0.0, 0.4)
		await tw.finished
		_dive_button_panel.visible = false

	# Notificar al main para avanzar el estado narrativo
	if _main_node and _main_node.has_method("on_dive_button_pressed"):
		_main_node.on_dive_button_pressed()

# ─── Handler principal: recibe cambios de estado narrativo desde main.gd ─────
func on_narrative_state_changed(state_int: int, zone: int) -> void:
	# Ocultar paneles por defecto
	if _dive_button_panel:   _dive_button_panel.visible  = (state_int == 0) # WAITING_START
	if _credits_panel:       _credits_panel.visible       = false
	if _subtitle_panel:      _subtitle_panel.visible      = false
	if _big_card_panel:      _big_card_panel.visible      = false

	match state_int:
		0: # WAITING_START — mostrar botón
			if _dive_button_panel:
				_dive_button_panel.modulate.a = 1.0
				_dive_button_panel.visible = true

		1, 5, 9, 13: # Fases de superficie con locución del Arroyo
			_show_subtitle(state_int)

		2, 6, 10, 14: # Fases de inmersión — sin texto, fundido
			pass

		3, 7, 11, 15: # Fases de cartel grande
			_show_big_card(zone)

		4, 8, 12, 16: # Fases bajo el agua con subtítulos
			_hide_big_card_animated()
			_show_subtitle(state_int)

		17: # Z4_EMERGE — silencio
			pass

		18: # Z4_CLOSING — subtítulos del cierre
			_show_subtitle(state_int)

		19: # CREDITS — pantalla final de créditos (dura 30s)
			if _credits_panel:
				_credits_panel.visible = true
				_credits_panel.modulate.a = 0.0
				var tw := create_tween()
				tw.tween_property(_credits_panel, "modulate:a", 1.0, 1.0)
			# Ocultar HUD y subtítulos
			if _param_panel:    _param_panel.visible    = false
			if _ica_panel:      _ica_panel.visible      = false
			if _subtitle_panel: _subtitle_panel.visible = false

		20: # DONE — manejado por main._auto_reset_tour()
			pass

## Desvanece suavemente la pantalla de créditos antes del reinicio
func fade_out_credits(duration: float = 1.0) -> void:
	if _credits_panel and _credits_panel.visible:
		var tw := create_tween()
		tw.tween_property(_credits_panel, "modulate:a", 0.0, duration)
		await tw.finished

func _show_subtitle(state_int: int) -> void:
	if not _subtitle_panel:
		return
	
	if _subtitle_tween:
		_subtitle_tween.kill()
		_subtitle_tween = null

	var sequence: Array = SUBTITLE_SEQUENCE_BY_STATE.get(state_int, [])
	if sequence.is_empty():
		_subtitle_panel.visible = false
		return

	_subtitle_panel.visible = true
	_subtitle_tween = create_tween()
	
	for chunk in sequence:
		var voice: String = chunk[0]
		var text: String = chunk[1]
		var dur: float = chunk[2]
		
		# Insertar un callback para cambiar el texto, luego esperar `dur` segundos
		_subtitle_tween.tween_callback(func():
			if text.is_empty():
				_subtitle_panel.visible = false
			else:
				_subtitle_panel.visible = true
				if _subtitle_voice_lbl:
					_subtitle_voice_lbl.text = voice
				if _subtitle_label:
					_subtitle_label.text = text
		)
		_subtitle_tween.tween_interval(dur)
	
	# Al finalizar la secuencia, ocultamos el panel
	_subtitle_tween.tween_callback(func(): _subtitle_panel.visible = false)

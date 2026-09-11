extends "res://scripts/HUDController.gd"
class_name HUDControllerVR

## HUDControllerVR — EcoAguaUNR
## HUD optimizado para visores de Realidad Virtual (Meta Quest / OpenXR / WebXR).
##
## Hereda toda la lógica de HUDController y sobreescribe únicamente
## las variables de tamaño antes de llamar a super._ready(),
## resultando en un HUD más grande y legible dentro del visor.
##
## Diferencias respecto al HUD de pantalla plana:
##   • Fuente parámetros:  12 pt  →  16 pt
##   • Fuente títulos:     13 pt  →  17 pt
##   • Fuente ICA:         14 pt  →  18 pt
##   • Ancho panel params: 260 px →  340 px
##   • Semiancho ICA:      160 px →  210 px
##   • Borde del panel:     2 px  →   3 px
##   • Radio de esquina:   10 pt  →  12 pt
##   • Margen pantalla:    35 px  →  50 px
##   • Margen inferior:    30 px  →  45 px

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# ── Tamaños VR — fuentes más grandes para lectura cómoda en el visor ────────
	PARAM_FONT_SIZE      = 16
	TITLE_FONT_SIZE      = 17
	ICA_NUM_FONT_SIZE    = 18

	# ── Dimensiones de los paneles ───────────────────────────────────────────────
	PARAM_PANEL_WIDTH    = 340   # más ancho para acomodar la fuente mayor
	ICA_PANEL_HALF_W     = 210   # barra ICA más ancha

	# ── Estilo del borde ─────────────────────────────────────────────────────────
	BORDER_WIDTH         = 3
	CORNER_RADIUS        = 12

	# ── Márgenes ─────────────────────────────────────────────────────────────────
	MARGIN_SCREEN        = 50    # más separado del borde para no invadir el FOV
	MARGIN_BOTTOM        = 45    # más alto desde el borde inferior

	# ── Construir el HUD con los valores VR ya establecidos ──────────────────────
	super._ready()

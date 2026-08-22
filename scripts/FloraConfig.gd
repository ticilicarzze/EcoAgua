class_name FloraConfig
extends Resource

enum SideOption { BOTH, LEFT_ONLY, RIGHT_ONLY }

@export var nombre: String = "Especie"
@export var model_scene: PackedScene
@export var count: int = 20
@export var zona_id: int = 1 # 1: Natural, 2: Agrícola, 3: Urbana, 4: Eutrofizada
@export var estrato_nombre: String = "Orilla"

## Distancia lateral respecto a la línea de costa/orilla (en metros)
## 0.0m es justo en el borde del agua. Valores negativos son dentro del agua.
@export var min_dist_orilla: float = 0.0
@export var max_dist_orilla: float = 3.0

## Distribución en las orillas (Ambas orillas, solo izquierda, solo derecha)
@export var bank_side: SideOption = SideOption.BOTH

@export var scale_min: float = 0.8
@export var scale_max: float = 1.2
@export var random_rotation_y: bool = true
@export var random_tilt_deg: float = 3.0
@export var cast_shadows: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

class_name FloraConfig
extends Resource

@export var nombre: String = "Especie"
@export var model_scene: PackedScene
@export var count: int = 50
@export var center: Vector3 = Vector3.ZERO
@export var extents: Vector3 = Vector3(10, 0, 50)
@export var min_y_offset: float = 0.0
@export var max_y_offset: float = 0.0
@export var scale_min: float = 0.8
@export var scale_max: float = 1.2
@export var random_rotation_y: bool = true
@export var random_tilt_deg: float = 5.0
@export var cast_shadows: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

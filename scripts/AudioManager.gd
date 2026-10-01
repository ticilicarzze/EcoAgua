class_name AudioManager
extends Node

## =============================================================================
## AUDIO MANAGER — EcoAgua UNR
## =============================================================================
## Control centralizado y modular del paisaje sonoro de EcoAgua.
## 
## Diseñado para que puedas editar TODO desde el Inspector de Godot:
## - Subir o bajar el volumen de cada sonido (sliders en dB).
## - Cambiar o reemplazar cualquier archivo de audio arrastrándolo al slot.
## - Acortar o limitar la duración de cantos de pájaros y chapuzones.
## - Configurar la frecuencia y tiempo entre cantos de aves.
## =============================================================================

enum NarrativeState {
	WAITING_START    = 0,
	Z1_SURFACE_INTRO = 1,
	Z1_DIVING        = 2,
	Z1_CARD          = 3,
	Z1_UNDERWATER    = 4,
	Z2_SURFACE       = 5,
	Z2_DIVING        = 6,
	Z2_CARD          = 7,
	Z2_UNDERWATER    = 8,
	Z3_SURFACE       = 9,
	Z3_DIVING        = 10,
	Z3_CARD          = 11,
	Z3_UNDERWATER    = 12,
	Z4_SURFACE       = 13,
	Z4_DIVING        = 14,
	Z4_CARD          = 15,
	Z4_UNDERWATER    = 16,
	Z4_EMERGE        = 17,
	Z4_CLOSING       = 18,
	CREDITS          = 19,
	DONE             = 20,
}

# --- 1. RÍO Y CHAPUZÓN ---
@export_group("1. Río y Chapuzón")
@export var stream_rio_fondo: AudioStream = preload("res://assets/sounds/rioFondo.ogg")
@export_range(-80.0, 12.0, 0.5) var vol_rio_fondo: float = -12.0

@export var stream_sumergirse: AudioStream = preload("res://assets/sounds/sumergirse2.mp3")
@export_range(-80.0, 12.0, 0.5) var vol_sumergirse: float = -2.0
@export_range(0.0, 10.0, 0.1) var sumergirse_max_duration: float = 0.0 ## 0 = duración completa del audio

# --- 2. AMBIENTES SUBACUÁTICOS ---
@export_group("2. Ambientes Subacuáticos (Bajo el agua)")
@export var stream_underwater_1_2: AudioStream = preload("res://assets/sounds/underwater-1-2/underwater_1_2.ogg")
@export_range(-80.0, 12.0, 0.5) var vol_underwater_1_2: float = -10.0

@export var stream_underwater_3_4: AudioStream = preload("res://assets/sounds/underwater-3-4/underwater_3_4.ogg")
@export_range(-80.0, 12.0, 0.5) var vol_underwater_3_4: float = -10.0

# --- 3. AMBIENTES SUPERFICIE ZONA 3 Y 4 ---
@export_group("3. Superficie Urbana e Industrial")
@export var stream_ciudad_z3: AudioStream = preload("res://assets/sounds/ciudadZona3/ciudad_zona3.ogg")
@export_range(-80.0, 12.0, 0.5) var vol_ciudad_z3: float = -12.0

@export var stream_industrial_z3: AudioStream = preload("res://assets/sounds/industrialZona3/industrial_zona3.ogg")
@export_range(-80.0, 12.0, 0.5) var vol_industrial_z3: float = -11.0

@export var stream_factory_z4: AudioStream = preload("res://assets/sounds/factory/factory.ogg")
@export_range(-80.0, 12.0, 0.5) var vol_factory_z4: float = -11.0

# --- 4. CANTOS DE AVES (SUPERFICIE ZONAS 1 Y 2) ---
@export_group("4. Cantos de Aves")
@export var bird_sounds_z1: Array[AudioStream] = [
	preload("res://assets/sounds/CantosPajaros/martinPescador.mp3"),
	preload("res://assets/sounds/CantosPajaros/teros.wav"),
	preload("res://assets/sounds/CantosPajaros/ardeaAalba.wav"),
]
@export var bird_sounds_z2: Array[AudioStream] = [
	preload("res://assets/sounds/CantosPajaros/chaja.mp3"),
	preload("res://assets/sounds/CantosPajaros/bigua.mp3"),
	preload("res://assets/sounds/CantosPajaros/teros.wav"),
]
@export_range(-80.0, 12.0, 0.5) var vol_birds: float = -8.0
@export var birds_enabled: bool = true
@export_range(1.0, 20.0, 0.5) var bird_interval_min: float = 3.5
@export_range(1.0, 30.0, 0.5) var bird_interval_max: float = 8.0
## Si un audio de ave es muy largo (ej. Tero dura 40s), se corta suavemente a los X segundos. (0 = no cortar)
@export_range(0.0, 30.0, 0.5) var bird_max_duration: float = 6.0

# --- 5. TRANSICIONES ---
@export_group("5. Transiciones y Fades")
@export_range(0.1, 5.0, 0.1) var fade_duration: float = 1.2


# -----------------------------------------------------------------------------
# NODOS REPRODUCTORES INTERNOS
# -----------------------------------------------------------------------------
var _player_rio: AudioStreamPlayer = null
var _player_underwater: AudioStreamPlayer = null
var _player_splash: AudioStreamPlayer = null
var _player_ciudad_z3: AudioStreamPlayer = null
var _player_industrial_z3: AudioStreamPlayer = null
var _player_factory_z4: AudioStreamPlayer = null
var _player_birds: AudioStreamPlayer = null
var _player_voice: AudioStreamPlayer = null
var _current_voice_queue: Array = []

var _tweens: Dictionary = {}
var _birds_active: bool = false
var _current_surface_zone: int = 1
var _next_bird_timer: float = 2.0
var _bird_cutoff_timer: float = 0.0
var _splash_cutoff_timer: float = 0.0


func _ready() -> void:
	# Inicializar o recuperar los reproductores de audio
	_player_rio           = _get_or_create_player("RioPlayer", stream_rio_fondo)
	_player_underwater    = _get_or_create_player("UnderwaterPlayer", stream_underwater_1_2)
	_player_splash        = _get_or_create_player("SplashPlayer", stream_sumergirse)
	_player_ciudad_z3     = _get_or_create_player("CiudadZ3Player", stream_ciudad_z3)
	_player_industrial_z3 = _get_or_create_player("IndustrialZ3Player", stream_industrial_z3)
	_player_factory_z4    = _get_or_create_player("FactoryZ4Player", stream_factory_z4)
	_player_birds         = _get_or_create_player("BirdsPlayer", null)
	_player_voice         = _get_or_create_player("VoicePlayer", null)
	_player_voice.finished.connect(_on_voice_finished)


func _get_or_create_player(player_name: String, default_stream: AudioStream) -> AudioStreamPlayer:
	var p: AudioStreamPlayer = get_node_or_null(player_name)
	if not p:
		p = AudioStreamPlayer.new()
		p.name = player_name
		p.bus = &"Master"
		add_child(p)
	if default_stream and not p.stream:
		p.stream = default_stream
	return p


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Control de cantos aleatorios de aves en superficie Z1 y Z2
	if _birds_active and birds_enabled:
		_next_bird_timer -= delta
		if _next_bird_timer <= 0.0:
			_play_random_bird(_current_surface_zone)
			_next_bird_timer = randf_range(bird_interval_min, bird_interval_max)

	# Control de duración máxima para cantos de aves (corte suave)
	if _bird_cutoff_timer > 0.0:
		_bird_cutoff_timer -= delta
		if _bird_cutoff_timer <= 0.0 and _player_birds and _player_birds.playing:
			_fade_out(_player_birds, 0.8)

	# Control de duración máxima para el chapuzón / sumergirse
	if _splash_cutoff_timer > 0.0:
		_splash_cutoff_timer -= delta
		if _splash_cutoff_timer <= 0.0 and _player_splash and _player_splash.playing:
			_fade_out(_player_splash, 0.4)


## Notificación recibida desde main.gd al cambiar de estado narrativo
func on_narrative_state_changed(state: int, zone: int) -> void:
	# Sincronizar streams asignados desde el Inspector (solo si han cambiado)
	_sync_streams()

	if voice_audios.has(state):
		_current_voice_queue = voice_audios[state].duplicate()
		# Si es una zona de superficie con 3s de ambiente, demorar la voz
		if state in [1, 5, 9, 13]:
			var timer = get_tree().create_timer(3.0)
			timer.timeout.connect(_play_next_voice)
		else:
			_play_next_voice()
	else:
		if _player_voice and _player_voice.playing:
			_player_voice.stop()
		_current_voice_queue.clear()

	match state:
		# --- ESPERA INICIAL (PANTALLA DE INICIO) ---
		NarrativeState.WAITING_START:
			_current_surface_zone = 1
			_birds_active = true
			_next_bird_timer = randf_range(1.5, 3.5)
			if not _player_rio.playing:
				_fade_in(_player_rio, vol_rio_fondo)
			_fade_out(_player_underwater)
			_fade_out(_player_ciudad_z3)
			_fade_out(_player_industrial_z3)
			_fade_out(_player_factory_z4)

		# --- INTRO EN SUPERFICIE ZONA 1 (TRAS TOCAR "SUMERGIRSE") ---
		NarrativeState.Z1_SURFACE_INTRO:
			_current_surface_zone = 1
			_birds_active = true
			# El sonido del río continúa sin pausas ni reinicios
			if not _player_rio.playing:
				_fade_in(_player_rio, vol_rio_fondo)
			_fade_out(_player_underwater)
			_fade_out(_player_ciudad_z3)
			_fade_out(_player_industrial_z3)
			_fade_out(_player_factory_z4)

		# --- INMERSIÓN ZONA 1 ---
		NarrativeState.Z1_DIVING:
			play_splash()
			_birds_active = false
			_fade_out(_player_birds, 0.4)
			_fade_out(_player_rio, 0.8)
			_play_underwater(stream_underwater_1_2, vol_underwater_1_2)

		# --- BAJO EL AGUA ZONA 1 ---
		NarrativeState.Z1_CARD, NarrativeState.Z1_UNDERWATER:
			_play_underwater(stream_underwater_1_2, vol_underwater_1_2)

		# --- EMERSIÓN Y SUPERFICIE ZONA 2 ---
		NarrativeState.Z2_SURFACE:
			play_splash()
			_current_surface_zone = 2
			_birds_active = true
			_next_bird_timer = randf_range(1.5, 3.5)
			_fade_out(_player_underwater)
			_fade_in(_player_rio, vol_rio_fondo)

		# --- INMERSIÓN ZONA 2 ---
		NarrativeState.Z2_DIVING:
			play_splash()
			_birds_active = false
			_fade_out(_player_birds, 0.4)
			_fade_out(_player_rio, 0.8)
			_play_underwater(stream_underwater_1_2, vol_underwater_1_2)

		# --- BAJO EL AGUA ZONA 2 ---
		NarrativeState.Z2_CARD, NarrativeState.Z2_UNDERWATER:
			_play_underwater(stream_underwater_1_2, vol_underwater_1_2)

		# --- EMERSIÓN Y SUPERFICIE ZONA 3 ---
		NarrativeState.Z3_SURFACE:
			play_splash()
			_birds_active = false
			_fade_out(_player_birds, 0.3)
			_fade_out(_player_rio)
			_fade_out(_player_underwater)
			_fade_out(_player_factory_z4)
			# En Zona 3 se combinan Ciudad e Industria
			_fade_in(_player_ciudad_z3, vol_ciudad_z3)
			_fade_in(_player_industrial_z3, vol_industrial_z3)

		# --- INMERSIÓN ZONA 3 ---
		NarrativeState.Z3_DIVING:
			play_splash()
			_fade_out(_player_ciudad_z3, 0.8)
			_fade_out(_player_industrial_z3, 0.8)
			_play_underwater(stream_underwater_3_4, vol_underwater_3_4)

		# --- BAJO EL AGUA ZONA 3 ---
		NarrativeState.Z3_CARD, NarrativeState.Z3_UNDERWATER:
			_fade_out(_player_ciudad_z3, 0.5)
			_fade_out(_player_industrial_z3, 0.5)
			_play_underwater(stream_underwater_3_4, vol_underwater_3_4)

		# --- EMERSIÓN Y SUPERFICIE ZONA 4 ---
		NarrativeState.Z4_SURFACE:
			play_splash()
			_fade_out(_player_underwater)
			_fade_out(_player_ciudad_z3)
			_fade_out(_player_industrial_z3)
			_fade_out(_player_factory_z4) # Silencio absoluto según guión

		# --- INMERSIÓN ZONA 4 ---
		NarrativeState.Z4_DIVING:
			play_splash()
			_fade_out(_player_factory_z4, 0.5)
			_fade_out(_player_ciudad_z3)
			_fade_out(_player_industrial_z3)
			_play_underwater(stream_underwater_3_4, vol_underwater_3_4)

		# --- BAJO EL AGUA ZONA 4 (CARTEL Y RODAJE BAJO AGUA) ---
		NarrativeState.Z4_CARD, NarrativeState.Z4_UNDERWATER:
			_fade_out(_player_factory_z4, 0.5)
			_fade_out(_player_ciudad_z3)
			_fade_out(_player_industrial_z3)
			_play_underwater(stream_underwater_3_4, vol_underwater_3_4)

		# --- EMERSIÓN FINAL Y CIERRE ZONA 4 (SALE A TIERRA) ---
		NarrativeState.Z4_EMERGE:
			play_splash()
			_fade_out(_player_underwater)
			_fade_out(_player_factory_z4) # Sigue el vacío

		NarrativeState.Z4_CLOSING:
			_fade_out(_player_underwater)
			_fade_out(_player_factory_z4)

		# --- CRÉDITOS Y DONE ---
		NarrativeState.CREDITS, NarrativeState.DONE:
			stop_all()


## Reproduce el sonido de sumergirse / salir del agua
func play_splash() -> void:
	if not stream_sumergirse or not _player_splash:
		return
	_player_splash.stop()
	_player_splash.stream = stream_sumergirse
	_player_splash.volume_db = vol_sumergirse
	_player_splash.play()
	if sumergirse_max_duration > 0.0:
		_splash_cutoff_timer = sumergirse_max_duration


## Reproduce un canto de ave aleatorio según la zona activa
func _play_random_bird(zone: int) -> void:
	var list: Array[AudioStream] = bird_sounds_z1 if zone == 1 else bird_sounds_z2
	if list.is_empty() or not _player_birds:
		return
	var stream: AudioStream = list.pick_random()
	if not stream:
		return

	_player_birds.stop()
	_player_birds.stream = stream
	_player_birds.volume_db = vol_birds
	_player_birds.play()

	if bird_max_duration > 0.0:
		_bird_cutoff_timer = bird_max_duration


## Maneja la reproducción y cambio de stream bajo el agua
func _play_underwater(target_stream: AudioStream, target_vol: float) -> void:
	if not _player_underwater:
		return
	if _player_underwater.stream != target_stream:
		_player_underwater.stream = target_stream
		_fade_in(_player_underwater, target_vol)
	elif not _player_underwater.playing:
		_fade_in(_player_underwater, target_vol)
	else:
		# Ya está reproduciendo el stream correcto
		if not is_equal_approx(_player_underwater.volume_db, target_vol):
			_fade_in(_player_underwater, target_vol)


## Fade in suave hacia el volumen objetivo
func _fade_in(player: AudioStreamPlayer, target_db: float, duration: float = -1.0) -> void:
	if not player or not player.stream:
		return
	var dur: float = duration if duration >= 0.0 else fade_duration

	# Si ya está reproduciéndose, no reiniciar playback ni resetear posición
	if player.playing:
		if is_equal_approx(player.volume_db, target_db):
			return
		if _tweens.has(player) and is_instance_valid(_tweens[player]):
			_tweens[player].kill()
		var tw := create_tween()
		_tweens[player] = tw
		tw.tween_property(player, "volume_db", target_db, dur)
		return

	if _tweens.has(player) and is_instance_valid(_tweens[player]):
		_tweens[player].kill()

	player.volume_db = -60.0
	player.play()

	var tw := create_tween()
	_tweens[player] = tw
	tw.tween_property(player, "volume_db", target_db, dur)


## Fade out suave y detención del reproductor
func _fade_out(player: AudioStreamPlayer, duration: float = -1.0) -> void:
	if not player or not player.playing:
		return
	var dur: float = duration if duration >= 0.0 else fade_duration

	if _tweens.has(player) and is_instance_valid(_tweens[player]):
		_tweens[player].kill()

	var tw := create_tween()
	_tweens[player] = tw
	tw.tween_property(player, "volume_db", -60.0, dur)
	tw.tween_callback(player.stop)


## Detiene todos los reproductores de sonido
func stop_all() -> void:
	_birds_active = false
	var players: Array[AudioStreamPlayer] = [
		_player_rio, _player_underwater, _player_splash,
		_player_ciudad_z3, _player_industrial_z3, _player_factory_z4, _player_birds, _player_voice
	]
	for p in players:
		if p:
			_fade_out(p, 0.5)


## Actualiza los streams de los reproductores solo si han cambiado para no interrumpir la reproducción
func _sync_streams() -> void:
	if _player_rio and stream_rio_fondo and _player_rio.stream != stream_rio_fondo:
		_player_rio.stream = stream_rio_fondo
	if _player_ciudad_z3 and stream_ciudad_z3 and _player_ciudad_z3.stream != stream_ciudad_z3:
		_player_ciudad_z3.stream = stream_ciudad_z3
	if _player_industrial_z3 and stream_industrial_z3 and _player_industrial_z3.stream != stream_industrial_z3:
		_player_industrial_z3.stream = stream_industrial_z3
	if _player_factory_z4 and stream_factory_z4 and _player_factory_z4.stream != stream_factory_z4:
		_player_factory_z4.stream = stream_factory_z4


# --- LOCUCIÓN (VOZ) ---
@export_range(-10.0, 12.0, 0.5) var vol_voice: float = 4.0

var voice_audios: Dictionary = {
	1: [preload("res://assets/sounds/Audios/Audio1.mp3")],
	4: [preload("res://assets/sounds/Audios/Audio2.mp3"), preload("res://assets/sounds/Audios/Audio3.mp3")],
	5: [preload("res://assets/sounds/Audios/Audio4.mp3")],
	8: [preload("res://assets/sounds/Audios/Audio5.mp3"), preload("res://assets/sounds/Audios/Audio6.mp3")],
	9: [preload("res://assets/sounds/Audios/Audio7.mp3")],
	12: [preload("res://assets/sounds/Audios/Audio8.mp3"), preload("res://assets/sounds/Audios/Audio9.mp3")],
	13: [preload("res://assets/sounds/Audios/Audio10.mp3")],
	16: [preload("res://assets/sounds/Audios/Audio11.mp3")],
	18: [preload("res://assets/sounds/Audios/Audio12.mp3")] # Falta el Audio13 que el usuario agregará después
}

func play_voice_for_state(state: int) -> void:
	if voice_audios.has(state):
		_current_voice_queue = voice_audios[state].duplicate()
		# Si es una zona de superficie con 3s de ambiente, demorar la voz
		if state in [1, 5, 9, 13]:
			var timer = get_tree().create_timer(3.0)
			timer.timeout.connect(_play_next_voice)
		else:
			_play_next_voice()
	else:
		if _player_voice and _player_voice.playing:
			_player_voice.stop()
		_current_voice_queue.clear()

func _play_next_voice() -> void:
	if _current_voice_queue.is_empty():
		return
	var next_stream = _current_voice_queue.pop_front()
	if _player_voice:
		_player_voice.stream = next_stream
		_player_voice.volume_db = vol_voice
		_player_voice.play()

func _on_voice_finished() -> void:
	_play_next_voice()

extends Node
## Efectos de sonido de la interfaz (assets/sfx/ui/<nombre>.ogg) y volúmenes del juego.
## Sfx.play("notify") desde cualquier sitio; los volúmenes se recuerdan en user://audio.json.

signal volume_changed

const DIR := "res://assets/sfx/ui/"
const SAVE_PATH := "user://audio.json"
const VOICES := 6

## Volumen de los efectos de UI, de la escena (bucles) y de la música, 0..1 lineales.
var ui_volume: float = 0.8
var scene_volume: float = 0.7
var music_volume: float = 0.5

const MUSIC_PATH := "res://assets/music/theme.ogg"
## Atenuación de la música durante las escenas de sexo, para que manden los gemidos.
const MUSIC_DUCK_DB := -10.0
var _music: AudioStreamPlayer
var _music_ducked := false

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	if FileAccess.file_exists(SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if parsed is Dictionary:
			ui_volume = clampf(float(parsed.get("ui", ui_volume)), 0.0, 1.0)
			scene_volume = clampf(float(parsed.get("scene", scene_volume)), 0.0, 1.0)
			music_volume = clampf(float(parsed.get("music", music_volume)), 0.0, 1.0)
	_music = AudioStreamPlayer.new()
	_music.bus = "Master"
	add_child(_music)
	if ResourceLoader.exists(MUSIC_PATH):
		var stream: AudioStreamOggVorbis = load(MUSIC_PATH)
		stream.loop = true
		_music.stream = stream
		_apply_music_volume()
		_music.play()


## Baja la música mientras hay sexo en pantalla (la escena lo pide cada frame).
func duck_music(ducked: bool) -> void:
	if ducked == _music_ducked:
		return
	_music_ducked = ducked
	if _music.stream:
		create_tween().tween_property(_music, "volume_db", _music_target_db(), 0.6)


func _music_target_db() -> float:
	return linear_to_db(maxf(music_volume, 0.0001)) + (MUSIC_DUCK_DB if _music_ducked else 0.0)


func _apply_music_volume() -> void:
	if music_volume <= 0.001:
		_music.volume_db = -80.0
	else:
		_music.volume_db = _music_target_db()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_music_volume()
	_save()
	volume_changed.emit()


## Reproduce un efecto; `db` ajusta ese disparo. Ignora repeticiones en menos de 60 ms.
func play(name: String, db: float = 0.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 60:
		return
	_last_played[name] = now
	var stream := _stream(name)
	if stream == null:
		return
	var player := _players[0]
	for p in _players:
		if not p.playing:
			player = p
			break
	player.stream = stream
	player.volume_db = linear_to_db(maxf(ui_volume, 0.0001)) + db
	player.play()


func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var path := DIR + name + ".ogg"
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


func scene_db() -> float:
	return linear_to_db(maxf(scene_volume, 0.0001))


func set_ui_volume(value: float) -> void:
	ui_volume = clampf(value, 0.0, 1.0)
	_save()
	volume_changed.emit()


func set_scene_volume(value: float) -> void:
	scene_volume = clampf(value, 0.0, 1.0)
	_save()
	volume_changed.emit()


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"ui": ui_volume, "scene": scene_volume, "music": music_volume}))

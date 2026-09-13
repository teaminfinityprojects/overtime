extends Control
## La ilustración grande: imagen fija por estado (assets/scenes/<nivel>/<estado>.png, editadas con
## Qwen-Image-Edit a partir de la base) o placeholder. Si falta la imagen exacta con el compañero
## esperando, se superpone su sprite (assets/coworkers/<id>.png) sobre la imagen de ella sola.

var day: Day
var _cache: Dictionary = {}
var _time: float = 0.0
var _last_key: String = ""
var _anim_start: float = 0.0
## Sonido del bucle activo (assets/anim/<nivel>/<estado>.ogg), en bucle mientras dure el estado.
var _audio: AudioStreamPlayer
var _audio_key: String = ""
const AUDIO_DB := -6.0
## Vídeo real (Theora, assets/video/<nivel>/<estado>.ogv, generado con Wan 2.2): si está activo tiene
## prioridad sobre el spritesheet (assets/anim, bucles H3). Se dibuja a mano desde su textura para que
## las capas (ropa colgada, compañero) queden encima. Desde el 12 sep 2026 los .ogv son los bucles H3
## reescalados x2 (tools/upscale_video.py) con su audio original al lado; los Wan 2.2 se descartaron.
const PREFER_VIDEO := true
var _video: VideoStreamPlayer
var _video_key: String = ""


func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = Sfx.scene_db() + AUDIO_DB
	add_child(_audio)
	Sfx.volume_changed.connect(func() -> void: _audio.volume_db = Sfx.scene_db() + AUDIO_DB)
	_video = VideoStreamPlayer.new()
	_video.loop = true
	_video.expand = true
	_video.visible = false
	_video.volume_db = -80.0
	add_child(_video)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Arranca (o para) el sonido de la ruta dada (OGG en bucle); "" lo apaga.
func _sync_audio(path: String) -> void:
	if path == _audio_key:
		return
	_audio_key = path
	_audio.stop()
	if path == "" or not ResourceLoader.exists(path):
		return
	var stream: AudioStreamOggVorbis = load(path)
	stream.loop = true
	_audio.stream = stream
	_audio.play()


# --- Estado -----------------------------------------------------------------------

func _clothes() -> String:
	return "%s_%s" % ["top" if day.top_on else "notop", "bottom" if day.bottom_on else "nobottom"]


## Clave de estado: {work|fuck|hot|climax}_{top|notop}_{bottom|nobottom}_{quien|none}.
func state_key() -> String:
	if day == null:
		return "work_top_bottom_none"
	if day.climaxing != "":
		return "%s_%s_%s" % ["climaxwork" if day.climax_from_work else "climax", _clothes(), day.climaxing]
	if day.mode == Day.Mode.FUCK and not day.visitor.is_empty():
		return "fuck_%s_%s" % [_clothes(), day.visitor["id"]]
	if day.is_distracted:
		return "hot_%s_none" % _clothes()
	if not day.visitor.is_empty():
		return "work_%s_%s" % [_clothes(), day.visitor["id"]]
	return "work_%s_none" % _clothes()


## Claves alternativas si falta la imagen exacta, de más a menos parecida.
func _fallbacks(key: String) -> Array[String]:
	var out: Array[String] = []
	if key.begins_with("climaxwork_"):
		out.append(key.replace("climaxwork_", "climax_"))
		out.append(key.replace("climaxwork_", "work_"))
	if key.begins_with("climax_"):
		out.append(key.replace("climax_", "fuck_"))
	if key.begins_with("hot_"):
		out.append(key.replace("hot_", "work_"))
	if key.begins_with("work_") and not key.ends_with("_none"):
		out.append(key.get_slice("_", 0) + "_" + key.get_slice("_", 1) + "_" + key.get_slice("_", 2) + "_none")
	return out


# --- Recursos ---------------------------------------------------------------------

func _level_id() -> String:
	return day.level.get("id", "x")


## Efecto de sonido por acto (assets/sfx/<acto>.ogg, Stable Audio 3): oral/titjob/sex con
## visita, hot sola, y teclado/oficina para el resto.
func _sfx_for(key: String) -> String:
	var act := "work"
	if key.begins_with("fuck_"):
		act = Day.act_for(day.top_on, day.bottom_on)
	elif key.begins_with("hot_"):
		act = "hot"
	var path := "res://assets/sfx/%s.ogg" % act
	return path if ResourceLoader.exists(path) else ""


## Vídeo para la clave o sus alternativas: la clave con .ogv existente, o "".
func _video_for(key: String) -> String:
	if not PREFER_VIDEO:
		return ""
	for k in [key] + _fallbacks(key):
		var path := "res://assets/video/%s/%s.ogv" % [_level_id(), k]
		var cache_key := "video:" + path
		if not _cache.has(cache_key):
			_cache[cache_key] = ResourceLoader.exists(path)
		if _cache[cache_key]:
			return k
	return ""


## Dibuja el fotograma actual del vídeo de `vkey` (cambiando de clip si hace falta).
## Devuelve false mientras el primer fotograma no está listo.
func _draw_video(vkey: String) -> bool:
	if vkey != _video_key:
		_video_key = vkey
		_video.stop()
		_video.stream = load("res://assets/video/%s/%s.ogv" % [_level_id(), vkey])
		_video.play()
	var tex := _video.get_video_texture()
	if tex == null or tex.get_size().x < 2.0:
		return false
	var fit := _fit(tex.get_size())
	draw_texture_rect(tex, fit, false)
	_draw_props(fit)
	return true



## Bucle animado (spritesheet de tools/video_to_sheet.py) para la clave o sus alternativas:
## {texture, meta} o vacío si no hay.
func _anim_for(key: String) -> Dictionary:
	for k in [key] + _fallbacks(key):
		var base := "res://assets/anim/%s/%s" % [_level_id(), k]
		var cache_key := "anim:" + base
		if not _cache.has(cache_key):
			var entry := {}
			if ResourceLoader.exists(base + ".png") and FileAccess.file_exists(base + ".json"):
				var meta = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
				if meta is Dictionary:
					entry = {"texture": load(base + ".png"), "meta": meta, "key": k}
			_cache[cache_key] = entry
		if not _cache[cache_key].is_empty():
			return _cache[cache_key]
	return {}


func _draw_anim(anim: Dictionary) -> void:
	var meta: Dictionary = anim["meta"]
	var frames := int(meta["frames"])
	var fps := float(meta["fps"])
	var frame := int((_time - _anim_start) * fps) % frames
	var cols := int(meta["cols"])
	var fw := float(meta["w"])
	var fh := float(meta["h"])
	var region := Rect2(Vector2(frame % cols, frame / cols) * Vector2(fw, fh), Vector2(fw, fh))
	draw_texture_rect_region(anim["texture"], _fit(Vector2(fw, fh)), region)


func _still_for(key: String) -> Texture2D:
	for k in [key] + _fallbacks(key):
		var path := "res://assets/scenes/%s/%s.png" % [_level_id(), k]
		if not _cache.has(path):
			_cache[path] = load(path) if ResourceLoader.exists(path) else null
		if _cache[path] != null:
			return _cache[path]
	return null


func _coworker_sprite() -> Texture2D:
	if day.visitor.is_empty() or day.mode == Day.Mode.FUCK or day.climaxing != "" or day.is_touching():
		return null
	var path := "res://assets/coworkers/%s.png" % day.visitor["id"]
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


# --- Dibujo -----------------------------------------------------------------------

func _draw() -> void:
	if day == null:
		return
	var key := state_key()
	if key != _last_key:
		_last_key = key
		_anim_start = _time
	Sfx.duck_music(key.begins_with("fuck_") or key.begins_with("hot_") or key.begins_with("climax") or day.is_touching())
	draw_rect(Rect2(Vector2.ZERO, size), UIKit.BG)

	# Vídeo real si existe; si no, bucle animado (spritesheet); si no, imagen fija.
	var vkey := _video_for(key)
	if vkey != "":
		# Audio del propio clip (assets/video/<nivel>/<clave>.ogg) si existe; si no, efecto por acto.
		var own := "res://assets/video/%s/%s.ogg" % [_level_id(), vkey]
		_sync_audio(own if ResourceLoader.exists(own) else _sfx_for(key))
		if _draw_video(vkey):
			return
	else:
		_video_key = ""
		_video.stop()
	var anim := _anim_for(key)
	if vkey == "":
		_sync_audio("res://assets/anim/%s/%s.ogg" % [_level_id(), anim.get("key", "")] if not anim.is_empty() else _sfx_for(key))
	if not anim.is_empty():
		_draw_anim(anim)
		_draw_props(_fit(Vector2(float(anim["meta"]["w"]), float(anim["meta"]["h"]))))
		return
	if _draw_layered(key):
		return

	var still := _still_for(key)
	if still == null:
		_draw_placeholder(key)
		return
	var fit := _fit(still.get_size())
	draw_texture_rect(still, fit, false)
	_draw_props(fit)

	# Si la imagen es la de ella sola pero hay visita, el compañero va como sprite encima.
	var sprite := _coworker_sprite()
	if sprite and not _exact_exists(key):
		var anchor: Dictionary = day.level.get("coworker_anchor", {"x": 300, "y": 790, "height": 640})
		var scale := fit.size.x / still.get_size().x
		var height := float(anchor["height"]) * scale
		var width := height * sprite.get_size().x / sprite.get_size().y
		var feet := fit.position + Vector2(float(anchor["x"]), float(anchor["y"])) * scale
		var bob := sin(_time * 1.6) * 3.0
		draw_texture_rect(sprite, Rect2(feet.x - width * 0.5, feet.y - height + bob, width, height), false)


## Devuelve true si pudo componer la escena por capas.
func _draw_layered(key: String) -> bool:
	var layers: Dictionary = day.level.get("layers", {})
	if layers.is_empty() or not (key.begins_with("work_") or key.begins_with("hot_")):
		return false
	var pose := "hot" if key.begins_with("hot_") else "sit"
	var girl := _tex("res://assets/layers/girl/%s_%s.png" % [pose, _clothes()])
	if girl == null and pose == "hot":
		girl = _tex("res://assets/layers/girl/sit_%s.png" % _clothes())
	var background := _tex(layers.get("background", ""))
	if girl == null or background == null:
		return false
	var fit := _fit(background.get_size())
	draw_texture_rect(background, fit, false)
	var scale := fit.size.x / background.get_size().x

	# El puesto (mesa + chica) comparte lienzo y ancla: los sprites "sit" ya traen la mesa, así que
	# la capa de mesa solo se dibuja en poses donde ella no está en la mesa.
	var station: Dictionary = layers.get("station", {"x": 600, "y": 810, "h": 640})
	var desk := _tex(layers.get("desk", ""))
	if desk and not girl.get_size().is_equal_approx(desk.get_size()):
		_draw_anchored(desk, station, fit.position, scale, 0.0)
	_draw_anchored(girl, station, fit.position, scale, 0.0)
	# El compañero va por delante de ella (z-index): más cerca de cámara, pies un poco más abajo.
	var sprite := _coworker_sprite()
	if sprite:
		_draw_anchored(sprite, layers.get("man_wait", {"x": 940, "y": 805, "h": 660}), fit.position, scale, sin(_time * 1.6) * 3.0)
	return true


func _tex(path: String) -> Texture2D:
	if path == "":
		return null
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func _draw_anchored(texture: Texture2D, anchor: Dictionary, origin: Vector2, scale: float, bob: float) -> void:
	var height := float(anchor["h"]) * scale
	var width := height * texture.get_size().x / texture.get_size().y
	var feet := origin + Vector2(float(anchor["x"]), float(anchor["y"])) * scale
	draw_texture_rect(texture, Rect2(feet.x - width * 0.5, feet.y - height + bob, width, height), false)


func _exact_exists(key: String) -> bool:
	return ResourceLoader.exists("res://assets/scenes/%s/%s.png" % [_level_id(), key])


## La ropa que se ha quitado aparece colgada en la escena: sprites recortados (tools/cutout_diff.gd)
## anclados en fracciones del lienzo (data/levels/<id>.json → props.blouse / props.skirt).
func _draw_props(canvas: Rect2) -> void:
	var props: Dictionary = day.level.get("props", {})
	var wanted: Array[String] = []
	if not day.top_on and day.changing != "top":
		wanted.append("blouse")
	if not day.bottom_on and day.changing != "bottom":
		wanted.append("skirt")
	for name in wanted:
		var anchor: Dictionary = props.get(name, {})
		var texture := _tex(anchor.get("image", "res://assets/props/%s.png" % name))
		if texture == null or anchor.is_empty():
			continue
		var w := canvas.size.x * float(anchor["w"])
		var h := w * texture.get_size().y / texture.get_size().x
		var pos := canvas.position + Vector2(float(anchor["x"]), float(anchor["y"])) * canvas.size
		draw_texture_rect(texture, Rect2(pos, Vector2(w, h)), false)


## Rectángulo de dibujo: la imagen cubre toda la zona (sin bandas) recortando lo que sobre,
## con el recorte vertical sesgado hacia arriba para no perder los pies ni la mesa.
func _fit(tex_size: Vector2) -> Rect2:
	var scale := maxf(size.x / tex_size.x, size.y / tex_size.y)
	var drawn := tex_size * scale
	var offset := Vector2((size.x - drawn.x) * 0.5, (size.y - drawn.y) * 0.65)
	return Rect2(offset, drawn)



func _draw_placeholder(key: String) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#cfd6e6"))
	draw_rect(Rect2(0, size.y * 0.62, size.x, size.y * 0.38), Color("#8e93a6"))
	draw_string(ThemeDB.fallback_font, Vector2(40, size.y - 40), "sin arte · " + key, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("#2d3140"))

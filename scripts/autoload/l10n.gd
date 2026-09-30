extends Node
## Idioma del juego: "es" (original) o "en".
## - UI: los scripts escriben el texto en español dentro de tr(); data/i18n/en.json da la traducción
##   (clave = texto en español, con los mismos %s/%d). En español tr() devuelve la clave tal cual.
## - Datos: cualquier valor {"es": …, "en": …} de data/*.json lo resuelve Catalog al cargar.
## Se elige en el menú; por defecto, el idioma del sistema/navegador. Se recuerda en user://language.json.

signal changed

const LANGS := ["es", "en"]
const SAVE_PATH := "user://language.json"
const EN_PATH := "res://data/i18n/en.json"

var lang: String = "es"
var _english := Translation.new()


func _ready() -> void:
	_english.locale = "en"
	var file := FileAccess.open(EN_PATH, FileAccess.READ)
	var table = JSON.parse_string(file.get_as_text()) if file else {}
	if table is Dictionary:
		for key: String in table:
			_english.add_message(key, table[key])
	var saved := ""
	if FileAccess.file_exists(SAVE_PATH):
		var parsed = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
		if parsed is Dictionary:
			saved = parsed.get("lang", "")
	_apply(saved if saved in LANGS else ("es" if OS.get_locale_language() == "es" else "en"))


func set_lang(value: String) -> void:
	if value == lang or value not in LANGS:
		return
	_apply(value)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"lang": lang}))
	changed.emit()


func _apply(value: String) -> void:
	lang = value
	# La traducción inglesa solo se registra en inglés: si no, Godot la usa de respaldo (fallback "en") y la UI
	# sale en inglés con el juego en español.
	if lang == "en":
		TranslationServer.add_translation(_english)
	else:
		TranslationServer.remove_translation(_english)
	TranslationServer.set_locale(lang)
	# La pantalla de carga (web/shell.html) lo lee de aquí para salir en el mismo idioma la próxima vez.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.setItem('overtime_lang', '%s') } catch (e) {}" % lang, true)


## Traducción desde código estático (funciones static no tienen tr()).
static func t(text: String) -> String:
	return TranslationServer.translate(text)


## Resuelve en profundidad los {"es": …, "en": …} de un dato cargado de JSON al idioma activo.
func resolve(value: Variant) -> Variant:
	if value is Dictionary:
		var dict: Dictionary = value
		if dict.size() > 0 and dict.keys().all(func(k: Variant) -> bool: return k in LANGS):
			return resolve(dict.get(lang, dict.get("es", "")))
		var out := {}
		for key in dict:
			out[key] = resolve(dict[key])
		return out
	if value is Array:
		return (value as Array).map(func(item: Variant) -> Variant: return resolve(item))
	return value

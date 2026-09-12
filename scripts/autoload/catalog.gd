extends Node
## Datos estáticos: chica, compañeros y niveles. Todo el contenido vive en res://data.

var character: Dictionary = {}
var coworkers: Dictionary = {}
var levels: Dictionary = {}
var level_order: Array[String] = []


func _ready() -> void:
	character = load_json("res://data/characters/candela/character.json")
	coworkers = load_json("res://data/coworkers.json")
	var dir := DirAccess.open("res://data/levels")
	var ids: Array[String] = []
	for file in dir.get_files():
		if file.ends_with(".json"):
			var data := load_json("res://data/levels/" + file)
			levels[data["id"]] = data
			ids.append(data["id"])
	ids.sort()
	level_order = ids


func coworker(id: String) -> Dictionary:
	return coworkers.get(id, {})


func level(id: String) -> Dictionary:
	return levels.get(id, {})


## "09:30" → minutos desde medianoche.
static func parse_clock(text: String) -> int:
	var parts := text.split(":")
	return int(parts[0]) * 60 + int(parts[1])


static func format_clock(minutes: float) -> String:
	var m := int(minutes)
	return "%02d:%02d" % [m / 60, m % 60]


func load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

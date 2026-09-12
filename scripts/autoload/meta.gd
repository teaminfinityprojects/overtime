extends Node
## Progreso persistente: niveles superados, mejor valoración y saldo. Stubs de compra como en
## Heartline; en producción todo lo que toque saldo o desbloqueos se valida en servidor.

signal changed

const SAVE_PATH := "user://save.json"

var hearts: int = 0
var best: Dictionary = {}
var unlocked_levels: Array = []
## Herramientas (capturas, pruebas) lo ponen a false para no tocar el guardado real.
var persist: bool = true


func _ready() -> void:
	load_game()


func level_unlocked(id: String) -> bool:
	return bool(Catalog.level(id).get("free", false)) or id in unlocked_levels


func record_day(level_id: String, won: bool, stars: int, report: float, satisfied: int) -> void:
	var previous: Dictionary = best.get(level_id, {})
	if won and stars >= int(previous.get("stars", 0)):
		best[level_id] = {"stars": stars, "report": report, "satisfied": satisfied}
	Metrics.track("day_end", {"level": level_id, "won": won, "stars": stars, "report": report, "satisfied": satisfied})
	if won:
		hearts += 10 * stars
	save_game()
	changed.emit()


func save_game() -> void:
	if not persist:
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"hearts": hearts, "best": best, "unlocked_levels": unlocked_levels}, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.open(SAVE_PATH, FileAccess.READ).get_as_text())
	if parsed is Dictionary:
		hearts = int(parsed.get("hearts", 0))
		best = parsed.get("best", {})
		unlocked_levels = parsed.get("unlocked_levels", [])


func reset() -> void:
	hearts = 0
	best = {}
	unlocked_levels = []
	save_game()
	changed.emit()

extends Node
## Registro de eventos de producto: cada punto de conversión emite uno.
## De momento escribe JSON Lines en user://metrics.jsonl y a consola; cuando esté
## Landing Metrics se sustituye `_deliver` por la llamada HTTP y el resto no cambia.

const LOG_PATH := "user://metrics.jsonl"

var session_id: String = ""
var _file: FileAccess


func _ready() -> void:
	session_id = "%d-%04x" % [Time.get_unix_time_from_system(), randi() % 0xFFFF]
	_file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if _file:
		_file.seek_end()
	track("session_start", {"platform": OS.get_name()})


func track(event: String, props: Dictionary = {}) -> void:
	var payload := {
		"event": event,
		"ts": Time.get_unix_time_from_system(),
		"session": session_id,
		"props": props,
	}
	_deliver(payload)


func _deliver(payload: Dictionary) -> void:
	var line := JSON.stringify(payload)
	if _file:
		_file.store_line(line)
		_file.flush()
	if OS.is_debug_build():
		print("[metrics] ", line)

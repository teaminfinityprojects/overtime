extends Node
## Métricas en Landing Metrics (skill infinity:metrics; contrato en docs/metrics-api-guide.md).
## - track(evento, props): en debug todos salen por consola; al panel solo van los de REMOTE_EVENTS, como
##   `event` con offer_slug = evento (el resto, mensajes o ropa, es demasiado frecuente para el panel).
## - click(slug, props): click interno. outbound(destino, slug, props): click de salida, offer_slug "destino:slug".
## - La vista (`view`) sale al arrancar; `view_time`, al cerrar u ocultar la pestaña.
## En web todo pasa por web/metrics.js (UTMs en 3 capas, visitor id, view_time), que carga la pantalla de carga
## (web/shell.html); si no está, se inyecta aquí.
## Fuera de web se envía con HTTPRequest. En builds de depuración no se envía nada: solo consola.

## Endpoint de Landing Metrics. Los proyectos usan .app y la guía (docs/) dice .dev: confirmar con el equipo.
const LOG_URL := "https://landingmetrics.tech555.app/log"
const JS_PATH := "res://web/metrics.js"
const VISITOR_PATH := "user://visitor_id"
const REMOTE_EVENTS := ["day_start", "day_end", "ad_impression"]

var _js: JavaScriptObject
var _visitor := ""


func _ready() -> void:
	if OS.has_feature("web"):
		_js = JavaScriptBridge.get_interface("overtimeMetrics")
		var file := FileAccess.open(JS_PATH, FileAccess.READ) if not _js else null
		if file:
			JavaScriptBridge.eval(file.get_as_text(), true)
			_js = JavaScriptBridge.get_interface("overtimeMetrics")
		if _js:
			_js.init(JSON.stringify({"log_url": LOG_URL, "dev": OS.is_debug_build()}))
		else:
			push_warning("Metrics: no se pudo cargar %s" % JS_PATH)
	# Un frame después, para que L10n (autoload posterior) ya haya elegido idioma.
	_send_view.call_deferred()


## En web la vista ya la suele mandar la pantalla de carga (web/shell.html); metrics.js la envía una sola vez.
func _send_view() -> void:
	var meta := {"lang": L10n.lang, "platform": OS.get_name()}
	if _js:
		_js.view(JSON.stringify(meta))
	else:
		_send("view", meta)


func _notification(what: int) -> void:
	# En web el view_time lo manda metrics.js al ocultar la pestaña; fuera de web, al cerrar la ventana.
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _js:
		_send("view_time", {"view_time_seconds": Time.get_ticks_msec() / 1000})


func track(event: String, props: Dictionary = {}) -> void:
	if OS.is_debug_build():
		print("[metrics] ", event, " ", JSON.stringify(props))
	if event in REMOTE_EVENTS:
		_send("event", _with_slug(event, props))


func click(slug: String, props: Dictionary = {}) -> void:
	_send("click", _with_slug(slug, props))


## Click hacia una plataforma externa (destination = "amateur" | "sugarcams"): sin el prefijo el panel lo descarta.
func outbound(destination: String, slug: String, props: Dictionary = {}) -> void:
	if _js:
		_js.outbound(destination, slug, JSON.stringify(props))
	else:
		_send("click", _with_slug("%s:%s" % [destination, slug], props))


## URL de salida con los params del visitante (utm_*, a, gclid…) y, donde falten, los del juego (`defaults`).
func outbound_url(url: String, defaults: Dictionary = {}) -> String:
	if _js:
		return String(_js.outboundUrl(url, JSON.stringify(defaults)))
	var params := PackedStringArray()
	var all := {"utm_source": "overtime"}.merged(defaults, true)
	for key: String in all:
		if not ("%s=" % key) in url:
			params.append("%s=%s" % [key, String(all[key]).uri_encode()])
	if params.is_empty():
		return url
	return url + ("&" if "?" in url else "?") + "&".join(params)


func open_url(url: String) -> void:
	if _js:
		_js.open(url)
	else:
		OS.shell_open(url)


func _with_slug(slug: String, props: Dictionary) -> Dictionary:
	var out := {"offer_slug": slug}
	out.merge(props)
	return out


func _send(type: String, metadata: Dictionary) -> void:
	if _js:
		_js.send(type, JSON.stringify(metadata))
		return
	var payload := {
		"type": type,
		"page": "app://overtime",
		"uuid": _visitor_id(),
		"metadata": _sanitize(metadata),
		"device": "mobile" if OS.has_feature("mobile") else "desktop",
		"utm_source": "overtime",
	}
	if OS.is_debug_build():
		print("[analytics] ", JSON.stringify(payload))
		return
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(func(_r: int, _c: int, _h: PackedStringArray, _b: PackedByteArray) -> void: request.queue_free())
	if request.request(LOG_URL, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(payload)) != OK:
		request.queue_free()


## Metadata ≤ 255 caracteres: strings a 50 sin caracteres de control; si aun así excede, {}.
func _sanitize(data: Dictionary) -> String:
	var clean := {}
	var control := RegEx.create_from_string("[\\x00-\\x1f]")
	for key: String in data:
		var value: Variant = data[key]
		if value is String:
			clean[key] = control.sub(value, "", true).substr(0, 50)
		elif value is int or value is float or value is bool:
			clean[key] = value
	var json := JSON.stringify(clean)
	return json if json.length() <= 255 else "{}"


func _visitor_id() -> String:
	if _visitor != "":
		return _visitor
	if FileAccess.file_exists(VISITOR_PATH):
		_visitor = FileAccess.open(VISITOR_PATH, FileAccess.READ).get_as_text().strip_edges()
	if _visitor == "":
		var hex := Crypto.new().generate_random_bytes(16).hex_encode()
		_visitor = "%s-%s-4%s-a%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(13, 3), hex.substr(17, 3), hex.substr(20, 12)]
		var file := FileAccess.open(VISITOR_PATH, FileAccess.WRITE)
		if file:
			file.store_string(_visitor)
	return _visitor

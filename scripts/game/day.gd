extends Node
class_name Day
## Simulación de una jornada: reloj, informe, productividad, mensajes y visitas.
## No sabe nada de UI: emite señales y expone estado; el HUD y las pruebas lo leen.

signal message_received(message: Dictionary)
signal message_answered(message: Dictionary, option: Dictionary)
signal visit_started(coworker_id: String)
signal visit_satisfied(coworker_id: String)
signal visit_aggravated(coworker_id: String)
signal dress_check(passed: bool)
signal productivity_hit(amount: float, reason: String)
signal day_ended(won: bool, stars: int)
signal line_spoken(who: String, text: String)
signal climax(coworker_id: String)
signal distracted(started: bool)

enum Mode { WORK, FUCK }

const MAX_PRODUCTIVITY := 10.0
## Minutos de jornada que tarda en quitarse o ponerse una prenda; mientras, no produce.
const CLOTHING_MINUTES := 1.5
const CLIMAX_MINUTES := 1.2

var level: Dictionary
var clock: float
var end_clock: float
var report: float = 0.0
var productivity: float = 7.0
var mode: Mode = Mode.WORK
var top_on: bool = true
var bottom_on: bool = true
## Prenda en transición y minutos que le quedan ("top"/"bottom", 0 si ninguna).
var changing: String = ""
var changing_left: float = 0.0
## Sola, desvestida y en modo Follar: se toca. Solo pasa si el jugador lo elige; nunca sola.
var is_distracted: bool = false
## Compañero que acaba de terminar: se muestra su viñeta unos instantes antes de irse.
var climaxing: String = ""
var _climax_left: float = 0.0
var speed: float = 1.0
var finished: bool = false
var won: bool = false

## Compañero en la mesa: {id, arousal 0..100, waited (min), aggravated}. Vacío si no hay nadie.
var visitor: Dictionary = {}
var queue: Array[String] = []
var satisfied_count: int = 0
var aggravated_count: int = 0
var pending_messages: Array[Dictionary] = []
var rejected: Dictionary = {}
var _events: Array = []
var _dress_checks: Array = []
var _seconds_per_minute: float = 1.0
var _accumulator: float = 0.0


func start(level_data: Dictionary) -> void:
	level = level_data
	clock = Catalog.parse_clock(level["start"])
	end_clock = Catalog.parse_clock(level["end"])
	_seconds_per_minute = float(level.get("seconds_per_game_minute", 1.0))
	_events = level["events"].duplicate(true)
	_events.sort_custom(func(a, b): return Catalog.parse_clock(a["at"]) < Catalog.parse_clock(b["at"]))
	Metrics.track("day_start", {"level": level["id"]})


func _process(delta: float) -> void:
	if finished or level.is_empty():
		return
	_accumulator += delta * speed / _seconds_per_minute
	while _accumulator >= 0.1:
		_accumulator -= 0.1
		_tick(0.1)


## Un décimo de minuto de jornada.
func _tick(minutes: float) -> void:
	clock += minutes
	_fire_events()
	_update_clothing(minutes)
	_update_climax(minutes)
	_update_visitor(minutes)
	_update_solo_play()
	_update_productivity(minutes)
	if changing == "" and not is_distracted and climaxing == "":
		report = minf(report + float(level["report_rate_per_minute"]) * (productivity / MAX_PRODUCTIVITY) * minutes, 100.0)
	if report >= 100.0:
		_finish(true)
	elif clock >= end_clock:
		_finish(false)


func _fire_events() -> void:
	while not _events.is_empty() and Catalog.parse_clock(_events[0]["at"]) <= clock:
		var event: Dictionary = _events.pop_front()
		match event["type"]:
			"message":
				_deliver(event)
			"visit":
				if not rejected.get(event["coworker"], false):
					request_visit(event["coworker"])
	for check in _dress_checks.duplicate():
		if clock >= check:
			_dress_checks.erase(check)
			var passed := top_on and bottom_on
			dress_check.emit(passed)
			Metrics.track("dress_check", {"passed": passed, "clock": Catalog.format_clock(clock)})
			if not passed:
				_hit(3.0, "El jefe te ha pillado sin ropa delante del cliente.")
				_deliver({"from": "boss", "text": "¿¡Pero qué haces así vestida!? Ese informe ya no es lo único que está en juego.", "options": [{"label": "Lo siento…", "effects": {}}]})


func _deliver(message: Dictionary) -> void:
	var copy := message.duplicate(true)
	copy["id"] = "%s-%d" % [copy["from"], Time.get_ticks_msec()]
	pending_messages.append(copy)
	if copy.has("dress_check"):
		_dress_checks.append(Catalog.parse_clock(copy["dress_check"]))
	message_received.emit(copy)
	Metrics.track("message_shown", {"from": copy["from"]})


func answer(message: Dictionary, option: Dictionary) -> void:
	pending_messages.erase(message)
	var effects: Dictionary = option.get("effects", {})
	var from: String = message["from"]
	if effects.get("reject", false):
		_reject(from)
	if effects.has("visit_delay"):
		_shift_visit(from, float(effects["visit_delay"]))
	message_answered.emit(message, option)
	Metrics.track("message_answered", {"from": from, "option": option["label"], "reject": effects.get("reject", false)})


## Rechazo por mensaje: unos se van, otros se cabrean y aparecen antes con refuerzos.
func _reject(coworker_id: String) -> void:
	var data := Catalog.coworker(coworker_id)
	if data.get("kind", "") != "coworker":
		return
	if data.get("on_reject", "leave") == "leave":
		rejected[coworker_id] = true
	else:
		_shift_visit(coworker_id, -10.0)
		if data.has("brings"):
			_events.append({"at": Catalog.format_clock(clock + 6.0), "type": "visit", "coworker": data["brings"]})
			_events.sort_custom(func(a, b): return Catalog.parse_clock(a["at"]) < Catalog.parse_clock(b["at"]))
		aggravated_count += 1
		visit_aggravated.emit(coworker_id)


func _shift_visit(coworker_id: String, minutes: float) -> void:
	for event in _events:
		if event["type"] == "visit" and event["coworker"] == coworker_id:
			event["at"] = Catalog.format_clock(maxf(Catalog.parse_clock(event["at"]) + minutes, clock + 1.0))
			break
	_events.sort_custom(func(a, b): return Catalog.parse_clock(a["at"]) < Catalog.parse_clock(b["at"]))


func request_visit(coworker_id: String) -> void:
	if visitor.is_empty() and climaxing == "":
		visitor = {"id": coworker_id, "arousal": 0.0, "waited": 0.0, "aggravated": false, "hinted": false}
		var data := Catalog.coworker(coworker_id)
		visit_started.emit(coworker_id)
		line_spoken.emit(coworker_id, data.get("greeting", ""))
		Metrics.track("visit_start", {"coworker": coworker_id})
	elif coworker_id not in queue and (visitor.is_empty() or visitor["id"] != coworker_id) and climaxing != coworker_id:
		queue.append(coworker_id)


func _update_visitor(minutes: float) -> void:
	if visitor.is_empty():
		if not queue.is_empty():
			request_visit(queue.pop_front())
		return
	var data := Catalog.coworker(visitor["id"])
	if mode == Mode.FUCK and changing == "":
		var met := wants_met(data)
		var rate := float(data["arousal_rate"] if met else data["arousal_rate_unmet"])
		visitor["arousal"] = minf(visitor["arousal"] + rate * minutes, 100.0)
		if not met and not visitor["hinted"]:
			visitor["hinted"] = true
			line_spoken.emit(visitor["id"], data.get("hint", ""))
		if visitor["arousal"] >= 100.0:
			_satisfy()
	else:
		visitor["waited"] += minutes
		if visitor["waited"] >= 3.0 and not visitor["hinted"]:
			visitor["hinted"] = true
			line_spoken.emit(visitor["id"], data.get("hint", ""))
		if visitor["waited"] >= float(data["patience"]) and not visitor["aggravated"]:
			visitor["aggravated"] = true
			aggravated_count += 1
			visit_aggravated.emit(visitor["id"])
			Metrics.track("visit_aggravated", {"coworker": visitor["id"]})
			if data.has("brings"):
				request_visit(data["brings"])


## Qué hace con el compañero según lo que lleva puesto: es la regla central del juego.
static func act_for(top: bool, bottom: bool) -> String:
	if top and bottom:
		return "oral"
	if not top and bottom:
		return "titjob"
	return "sex"


func current_act() -> String:
	return act_for(top_on, bottom_on)


static func act_label(act: String) -> String:
	match act:
		"oral": return "oral"
		"titjob": return "con las tetas"
		_: return "sexo"


func wants_met(data: Dictionary) -> bool:
	var wants: Dictionary = data.get("wants", {})
	if wants.has("top") and top_on != bool(wants["top"]):
		return false
	if wants.has("bottom") and bottom_on != bool(wants["bottom"]):
		return false
	return true


func _satisfy() -> void:
	var id: String = visitor["id"]
	satisfied_count += 1
	productivity = minf(productivity + 3.0, MAX_PRODUCTIVITY)
	visitor = {}
	# Se queda un instante la viñeta del final antes de que se vaya y ella vuelva al informe.
	climaxing = id
	_climax_left = CLIMAX_MINUTES
	climax.emit(id)
	line_spoken.emit(id, Catalog.coworker(id).get("climax", "Me voy a correr…"))
	Metrics.track("visit_satisfied", {"coworker": id, "act": current_act()})


func _update_climax(minutes: float) -> void:
	if climaxing == "":
		return
	_climax_left -= minutes
	if _climax_left > 0.0:
		return
	var id := climaxing
	climaxing = ""
	if queue.is_empty():
		mode = Mode.WORK
	visit_satisfied.emit(id)
	line_spoken.emit(id, Catalog.coworker(id).get("finish", ""))


func _update_productivity(minutes: float) -> void:
	if visitor.is_empty():
		_drain_when_alone(minutes)
		return
	# Esperando la toca y la besa: distrae. Follando mientras teclea: la productividad se hunde.
	var drain := 0.3 if mode == Mode.WORK else 0.9
	if visitor.get("aggravated", false):
		drain *= 1.8
	productivity = maxf(productivity - drain * minutes, 0.0)


## Tope de productividad según la ropa: vestida 10, una prenda fuera 7, desnuda 4.
## Puede trabajar así, pero rinde menos; el tope se ve en los pips del HUD.
func productivity_cap() -> float:
	var missing := int(not top_on) + int(not bottom_on)
	return [MAX_PRODUCTIVITY, 7.0, 4.0][missing]


func _drain_when_alone(minutes: float) -> void:
	if is_distracted:
		# Tocarse es no trabajar: la productividad cae a cero de inmediato.
		productivity = 0.0
		return
	var cap := productivity_cap()
	if productivity > cap:
		# Acaba de quitarse algo: baja hasta el tope, no de golpe.
		productivity = maxf(productivity - 1.5 * minutes, cap)
	elif mode == Mode.WORK and changing == "":
		productivity = minf(productivity + 0.12 * minutes, cap)


func _hit(amount: float, reason: String) -> void:
	productivity = maxf(productivity - amount, 0.0)
	productivity_hit.emit(amount, reason)


func set_mode(new_mode: Mode) -> void:
	if changing != "":
		return
	if new_mode == Mode.FUCK and visitor.is_empty() and top_on and bottom_on:
		# Sola y vestida no hay nada que hacer: hay que quitarse algo antes.
		return
	mode = new_mode
	Metrics.track("mode_toggle", {"mode": "fuck" if mode == Mode.FUCK else "work"})


func toggle_top() -> void:
	_start_changing("top")


func toggle_bottom() -> void:
	_start_changing("bottom")


func _start_changing(piece: String) -> void:
	if changing != "" or finished:
		return
	changing = piece
	changing_left = CLOTHING_MINUTES
	Metrics.track("clothing_toggle", {"piece": piece, "on": not (top_on if piece == "top" else bottom_on)})


func _update_clothing(minutes: float) -> void:
	if changing == "":
		return
	changing_left -= minutes
	if changing_left > 0.0:
		return
	if changing == "top":
		top_on = not top_on
	else:
		bottom_on = not bottom_on
	changing = ""
	changing_left = 0.0


## 0..1 de la transición de ropa en curso.
func changing_progress() -> float:
	return 0.0 if changing == "" else 1.0 - changing_left / CLOTHING_MINUTES


## Tocarse es una decisión del jugador: modo Follar sin nadie en la mesa y con alguna prenda
## fuera. Al vestirse del todo, llegar alguien o volver a Trabajar, se corta.
func _update_solo_play() -> void:
	var exposed := not top_on or not bottom_on
	var now := mode == Mode.FUCK and visitor.is_empty() and climaxing == "" and exposed
	if now != is_distracted:
		is_distracted = now
		distracted.emit(is_distracted)
		if is_distracted:
			Metrics.track("solo_play", {"clock": Catalog.format_clock(clock), "top": top_on, "bottom": bottom_on})

func minutes_left() -> float:
	return maxf(end_clock - clock, 0.0)


func _finish(did_win: bool) -> void:
	finished = true
	won = did_win
	var stars := 0
	if won:
		stars = 1 + (1 if satisfied_count >= 3 else 0) + (1 if minutes_left() >= 60.0 else 0)
	Meta.record_day(level["id"], won, stars, report, satisfied_count)
	day_ended.emit(won, stars)

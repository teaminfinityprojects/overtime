extends Node
## Simulador de equilibrio: corre la jornada a toda velocidad con jugadores automáticos y escribe
## cuándo (y si) acaban el informe. Sin UI. Uso:
##   godot --headless --path . tools/balance_sim.tscn
## Políticas: "worker" (vestida, ignora visitas), "tease" (sin blusa con visita, sigue tecleando mientras la tocan,
## nunca pulsa Follar), "flirty" (se quita la blusa, folla con todos,
## se viste para los controles del jefe), "nude" (desnuda todo el día, folla con todos, se toca sin nadie).

const POLICIES := ["worker", "tease", "flirty", "nude"]
var _runs: Array = []
var _day: Day
var _policy: String
var _index := 0
var _log: Array[String] = []
var _visit_minutes: float = 0.0
var _visit_started: float = 0.0
var _visit_lengths: Array[float] = []


func _ready() -> void:
	Meta.persist = false
	_start_next()


func _start_next() -> void:
	if _index >= POLICIES.size():
		_report()
		get_tree().quit()
		return
	_policy = POLICIES[_index]
	_index += 1
	_visit_lengths = []
	_day = Day.new()
	add_child(_day)
	_day.speed = 400.0
	_day.day_ended.connect(_on_ended)
	_day.visit_started.connect(func(_id: String) -> void: _visit_started = _day.clock)
	_day.visit_satisfied.connect(func(_id: String) -> void: _visit_lengths.append(_day.clock - _visit_started))
	_day.start(Catalog.level("desk_tuesday"))


func _process(_delta: float) -> void:
	if _day == null or _day.finished:
		return
	var d := _day
	# Contesta lo pendiente en cuanto puede: primera opción (la "amable"), salvo el worker, que rechaza.
	if d.can_answer():
		for m in d.pending_messages.duplicate():
			var options: Array = m.get("options", [])
			if options.is_empty():
				continue
			var pick: Dictionary = options[0]
			if _policy == "worker":
				for o in options:
					if o.get("effects", {}).get("reject", false):
						pick = o
			d.answer(m, pick)
	var check_soon := _dress_check_within(12.0)
	match _policy:
		"worker":
			d.set_mode(Day.Mode.WORK)
		"tease":
			if check_soon:
				if not d.top_on and d.changing == "": d.toggle_top()
				d.set_mode(Day.Mode.WORK)
			elif not d.visitor.is_empty():
				if d.top_on and d.changing == "": d.toggle_top()
				d.set_mode(Day.Mode.WORK)
			else:
				d.set_mode(Day.Mode.WORK)
		"flirty":
			if check_soon:
				if not d.top_on and d.changing == "": d.toggle_top()
				if not d.bottom_on and d.changing == "": d.toggle_bottom()
				d.set_mode(Day.Mode.WORK)
			elif not d.visitor.is_empty():
				var wants: Dictionary = Catalog.coworker(d.visitor["id"]).get("wants", {})
				if d.changing == "":
					if wants.has("top") and d.top_on != bool(wants["top"]): d.toggle_top()
					elif wants.has("bottom") and d.bottom_on != bool(wants["bottom"]): d.toggle_bottom()
				d.set_mode(Day.Mode.FUCK)
			else:
				d.set_mode(Day.Mode.WORK)
		"nude":
			if check_soon:
				if not d.top_on and d.changing == "": d.toggle_top()
				if not d.bottom_on and d.changing == "": d.toggle_bottom()
				d.set_mode(Day.Mode.WORK)
			else:
				if d.top_on and d.changing == "": d.toggle_top()
				elif d.bottom_on and d.changing == "": d.toggle_bottom()
				d.set_mode(Day.Mode.FUCK)


func _dress_check_within(minutes: float) -> bool:
	for c in _day._dress_checks:
		if c - _day.clock <= minutes and c > _day.clock - 1.0:
			return true
	return false


func _on_ended(won: bool, stars: int) -> void:
	if _day == null:
		return
	var d := _day
	var avg := 0.0
	for l in _visit_lengths:
		avg += l
	avg = avg / _visit_lengths.size() if not _visit_lengths.is_empty() else 0.0
	_runs.append("%-7s → %s a las %s · informe %3d%% · %d estrellas · %d satisfechos (media %.1f min) · %d cabreados · prod. final %.1f" % [
		_policy, "GANA " if won else "PIERDE", Catalog.format_clock(d.clock), int(d.report), stars, d.satisfied_count, avg, d.aggravated_count, d.productivity])
	d.queue_free()
	_day = null
	_start_next.call_deferred()


func _report() -> void:
	print("== balance desk_tuesday ==")
	for r in _runs:
		print(r)

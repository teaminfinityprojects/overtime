extends Node
## Juega una jornada completa sin ventana con una estrategia sencilla y comprueba la
## simulación: godot --headless --path . res://tools/smoke_test.tscn

var _failures := 0
var _ended := false
var _won := false
var _stars := 0
var _messages := 0
var _visits := 0


func _ready() -> void:
	_run()


func _run() -> void:
	Meta.persist = false
	var day := Day.new()
	add_child(day)
	day.message_received.connect(func(_m: Dictionary) -> void: _messages += 1)
	day.visit_started.connect(func(_id: String) -> void: _visits += 1)
	day.day_ended.connect(func(w: bool, s: int) -> void:
		_ended = true
		_won = w
		_stars = s)
	day.start(Catalog.level("desk_tuesday"))
	_check(day.clock == 9 * 60, "la jornada empieza a las 09:00")
	_check(day.report == 0.0 and day.productivity == 7.0, "estado inicial")
	_check(Day.act_for(true, true) == "oral" and Day.act_for(false, true) == "titjob" and Day.act_for(false, false) == "sex", "el acto depende de la ropa")
	day.toggle_top()
	_check(day.changing == "top" and day.top_on, "quitarse la blusa lleva tiempo")

	day.speed = 60.0
	var ticks := 0
	while not _ended and ticks < 4000:
		ticks += 1
		# Responde la primera opción (nunca rechaza) en cuanto puede: solo se contesta trabajando.
		if day.can_answer():
			for m in day.pending_messages.duplicate():
				day.answer(m, m["options"][0])
		# Estrategia: si hay visita, quitarse lo que pida y atenderla; si no, vestirse y trabajar.
		if day.changing != "":
			pass
		elif not day.visitor.is_empty():
			var wants: Dictionary = Catalog.coworker(day.visitor["id"]).get("wants", {})
			if wants.has("top") and day.top_on != bool(wants["top"]):
				day.toggle_top()
			elif wants.has("bottom") and day.bottom_on != bool(wants["bottom"]):
				day.toggle_bottom()
			else:
				day.set_mode(Day.Mode.FUCK)
		elif day.climaxing == "":
			if not day.top_on:
				day.toggle_top()
			elif not day.bottom_on:
				day.toggle_bottom()
			else:
				day.set_mode(Day.Mode.WORK)
		await get_tree().process_frame

	_check(_ended, "la jornada termina")
	_check(_messages >= 4, "llegan los mensajes del nivel (%d)" % _messages)
	_check(_visits >= 3, "hay visitas (%d)" % _visits)
	_check(day.satisfied_count >= 3, "la estrategia atiende a los compañeros (%d)" % day.satisfied_count)
	print("   resultado: %s · informe %.0f%% · %s · %d atendidos · %d cabreados · %d★" % ["informe entregado" if _won else "jornada agotada", day.report, Catalog.format_clock(day.clock), day.satisfied_count, day.aggravated_count, _stars])

	# Segunda jornada: ignorar a todos y solo trabajar; deben cabrearse y drenar productividad.
	_ended = false
	var lazy := Day.new()
	add_child(lazy)
	lazy.day_ended.connect(func(w: bool, _s: int) -> void:
		_ended = true
		_won = w)
	lazy.start(Catalog.level("desk_tuesday"))
	lazy.speed = 60.0
	ticks = 0
	while not _ended and ticks < 4000:
		ticks += 1
		for m in lazy.pending_messages.duplicate():
			lazy.answer(m, m["options"][m["options"].size() - 1])
		await get_tree().process_frame
	_check(lazy.aggravated_count >= 1 or lazy.rejected.size() >= 1, "rechazar tiene consecuencias (%d cabreados, %d se van)" % [lazy.aggravated_count, lazy.rejected.size()])

	# Tercera prueba: tocarse es decisión del jugador, nunca automático.
	var hot := Day.new()
	add_child(hot)
	hot.start(Catalog.level("desk_tuesday"))
	hot.top_on = false
	hot.bottom_on = false
	hot.speed = 60.0
	for i: int in 40:
		await get_tree().process_frame
	_check(not hot.is_distracted, "desvestida y sola en modo Trabajar NO se toca por su cuenta")
	_check(hot.productivity_cap() == 6.0 and hot.productivity <= 6.0, "trabajar desnuda tiene tope 6 (productividad %.1f)" % hot.productivity)
	_check(hot.report > 0.0, "y aun así el informe avanza (%.1f%%)" % hot.report)
	hot.set_mode(Day.Mode.FUCK)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hot.is_distracted, "al pulsar Follar sola y desvestida se toca")
	_check(hot.productivity == 0.0, "tocarse pone la productividad a 0")
	hot.set_mode(Day.Mode.WORK)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not hot.is_distracted, "al volver a Trabajar deja de tocarse")
	# Regla nueva: con un mensaje pendiente y en modo Follar no se puede contestar; trabajando sí.
	var probe := {"from": "boss", "text": "?", "options": [{"label": "ok", "effects": {}}]}
	hot._deliver(probe)
	var pending_msg: Dictionary = hot.pending_messages[hot.pending_messages.size() - 1]
	hot.set_mode(Day.Mode.FUCK)
	_check(not hot.answer(pending_msg, pending_msg["options"][0]), "follando no se contesta el móvil")
	hot.set_mode(Day.Mode.WORK)
	_check(hot.answer(pending_msg, pending_msg["options"][0]), "trabajando sí se contesta")
	hot.queue_free()
	print("   ignorando a todos: %s · informe %.0f%% · productividad %.1f" % ["entregado" if _won else "agotada", lazy.report, lazy.productivity])
	_finish()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("  ok    %s" % description)
	else:
		printerr("  FALLO %s" % description)
		_failures += 1


func _finish() -> void:
	print("\n%s" % ("TODO OK" if _failures == 0 else "%d comprobaciones fallidas" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)

extends Node
## Juega la escena de juego real (con HUD) a toda velocidad respondiendo mensajes y follando
## con todo el que llega: godot --headless --path . res://tools/ui_smoke_test.tscn

var _failures := 0


func _ready() -> void:
	Meta.persist = false
	var game: Game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	var day := game.day
	var ended := [false]
	day.day_ended.connect(func(_w: bool, _s: int) -> void: ended[0] = true)
	day.speed = 60.0
	var climaxes := [0]
	day.climax.connect(func(_id: String) -> void: climaxes[0] += 1)
	# Fuerza una cola: dos visitas seguidas desde el principio.
	day.request_visit("mario")
	day.request_visit("dani")
	var ticks := 0
	while not ended[0] and ticks < 3000:
		ticks += 1
		if day.can_answer():
			for m in day.pending_messages.duplicate():
				day.answer(m, m["options"][0])
		if day.changing == "" and not day.visitor.is_empty():
			# Se pone lo que quiere el visitante y folla; sola, vuelve al informe.
			var wants: Dictionary = Catalog.coworker(day.visitor["id"]).get("wants", {})
			if wants.has("top") and day.top_on != bool(wants["top"]):
				day.toggle_top()
			elif wants.has("bottom") and day.bottom_on != bool(wants["bottom"]):
				day.toggle_bottom()
			else:
				day.set_mode(Day.Mode.FUCK)
		elif day.visitor.is_empty() and day.climaxing == "":
			day.set_mode(Day.Mode.WORK)
		if ticks % 60 == 0 and day.changing == "" and day.visitor.is_empty():
			# Cambios de ropa a destiempo, como hace un jugador.
			if randf() < 0.5:
				day.toggle_top()
			else:
				day.toggle_bottom()
		await get_tree().process_frame
	_check(ended[0], "la jornada termina con la UI activa")
	_check(climaxes[0] >= 2, "hubo al menos dos clímax (%d)" % climaxes[0])
	_check(day.satisfied_count >= 2, "los compañeros en cola se atendieron (%d)" % day.satisfied_count)
	print("   %s · informe %.0f%% · %d atendidos" % ["entregado" if day.won else "agotada", day.report, day.satisfied_count])
	print("\n%s" % ("TODO OK" if _failures == 0 else "%d comprobaciones fallidas" % _failures))
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	print(("  ok    " if condition else "  FALLO ") + description)
	if not condition:
		_failures += 1

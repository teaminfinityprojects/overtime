extends Node
## Renderiza la jornada avanzada hasta una visita y guarda un PNG:
##   godot --path . res://tools/screenshot.tscn -- salida.png [minutos_de_avance]


func _ready() -> void:
	_run()


func _run() -> void:
	Meta.persist = false
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if args.size() > 0 else "user://screenshot.png"
	var advance := float(args[1]) if args.size() > 1 else 26.0
	var game: Game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	# Avanza la jornada a toda velocidad hasta el minuto pedido y deja una visita en curso.
	game.day.speed = 120.0
	while game.day.clock < 9 * 60 + advance:
		await get_tree().process_frame
	game.day.speed = 1.0
	# Tercer argumento: "fuck" pasa al modo sexo con la ropa puesta (oral); "ring" empieza a
	# quitarse la blusa (anillo de transición); por defecto captura la espera.
	# Cuarto argumento opcional: compañero a forzar en la mesa (p. ej. dani).
	if args.size() > 3:
		game.day.visitor = {}
		game.day.queue.clear()
		game.day.request_visit(args[3])
	if not game.day.visitor.is_empty() and args.size() > 2:
		if args[2] == "fuck":
			game.day.set_mode(Day.Mode.FUCK)
		elif args[2] == "ring":
			game.day.toggle_top()
	# "answer": responde todos los mensajes pendientes con la primera opción; "list": vuelve a la lista de chats.
	if args.size() > 2 and args[2] in ["answer", "list"]:
		for m in game.day.pending_messages.duplicate():
			game._phone._choose(m, m["options"][0])
		if args[2] == "list":
			game._phone._back()
		for i: int in 3:
			await get_tree().process_frame
	# "notop": sola y sin blusa (ropa colgada).
	if args.size() > 2 and args[2] == "notop":
		game.day.visitor = {}
		game.day.queue.clear()
		game.day.top_on = false
	# "nude": ella sola sin ropa (para revisar variantes de sprite).
	if args.size() > 2 and args[2] == "nude":
		game.day.visitor = {}
		game.day.queue.clear()
		game.day.top_on = false
		game.day.bottom_on = false
	for i: int in 40:
		await get_tree().process_frame
	var error := get_viewport().get_texture().get_image().save_png(output)
	print("captura: %s (%s)" % [ProjectSettings.globalize_path(output), error_string(error)])
	get_tree().quit(0 if error == OK else 1)

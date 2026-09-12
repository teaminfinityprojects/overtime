extends Node
## Arranca el juego en ventana, la agranda por código y captura antes y después para comprobar
## que el contenido se reescala: godot --path . res://tools/resize_test.tscn -- salida_prefijo

func _ready() -> void:
	Meta.persist = false
	var prefix: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://resize"
	var game: Game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for size in [Vector2i(1280, 720), Vector2i(1710, 1010)]:
		DisplayServer.window_set_size(size)
		for i: int in 20:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s_%dx%d.png" % [prefix, size.x, size.y])
		var scale := get_viewport().get_screen_transform().get_scale().x
		print("ventana %s → imagen %s · escala del contenido %.2f · el panel del teléfono (%d px de diseño) ocupa %.0f px reales" % [size, img.get_size(), scale, Game.PANEL_WIDTH, Game.PANEL_WIDTH * scale])
	get_tree().quit()

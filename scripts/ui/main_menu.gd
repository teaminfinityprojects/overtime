extends Control
## Menú: jugar el nivel libre, ver niveles y saldo.


func _ready() -> void:
	UIKit.fill_background(self)
	var column := UIKit.vbox(14)
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.custom_minimum_size = Vector2(480, 0)
	add_child(column)
	column.add_child(UIKit.title("OVERTIME", 72))
	column.add_child(UIKit.title("Termina el informe. Atiende a la oficina.", 20))
	var hearts := UIKit.hbox(6)
	hearts.alignment = BoxContainer.ALIGNMENT_CENTER
	hearts.add_child(UIKit.icon("heart-filled", 20, UIKit.HEART))
	hearts.add_child(UIKit.label(str(Meta.hearts), 20, UIKit.HEART))
	column.add_child(hearts)
	for id in Catalog.level_order:
		var level := Catalog.level(id)
		var best: Dictionary = Meta.best.get(id, {})
		var n_stars := int(best.get("stars", 0))
		var button := UIKit.icon_text_button("star-filled" if n_stars > 0 else "star", "%s%s" % [level["name"], ("  ×%d" % n_stars) if n_stars > 0 else ""], UIKit.PRIMARY if Meta.level_unlocked(id) else UIKit.PANEL_LIGHT, 24)
		button.disabled = not Meta.level_unlocked(id)
		button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game.tscn"))
		column.add_child(button)
	var fullscreen := UIKit.icon_text_button("maximize", "Pantalla completa (F11)", UIKit.PANEL_LIGHT, 16)
	fullscreen.pressed.connect(func() -> void: Screen.set_fullscreen(not Screen.is_fullscreen()))
	column.add_child(fullscreen)
	if OS.is_debug_build():
		var reset := UIKit.button("DEV · borrar progreso", UIKit.PANEL, 14)
		reset.pressed.connect(func() -> void:
			Meta.reset()
			get_tree().reload_current_scene())
		column.add_child(reset)
	column.reset_size()
	column.position = (size - column.size) * 0.5

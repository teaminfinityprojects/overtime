extends Node
## Captura cualquier escena: godot --path . tools/shot_scene.tscn -- res://scenes/main_menu.tscn salida.png
func _ready() -> void:
	Meta.persist = false
	var args := OS.get_cmdline_user_args()
	var scene: Node = (load(args[0]) as PackedScene).instantiate()
	add_child(scene)
	for i: int in 20:
		await get_tree().process_frame
	var err := get_viewport().get_texture().get_image().save_png(args[1])
	print("captura: %s (%s)" % [args[1], error_string(err)])
	get_tree().quit(0 if err == OK else 1)

extends Node
## Comprueba que un VideoStreamPlayer oculto sigue decodificando (la escena dibuja su textura a mano):
##   godot --path . tools/video_test.tscn
func _ready() -> void:
	var v := VideoStreamPlayer.new()
	v.loop = true
	v.expand = true
	v.visible = false
	v.stream = load("res://assets/video/desk_tuesday/work_top_bottom_none.ogv")
	add_child(v)
	v.play()
	await get_tree().create_timer(0.6).timeout
	var a: Image = v.get_video_texture().get_image()
	await get_tree().create_timer(0.8).timeout
	var b: Image = v.get_video_texture().get_image()
	var diff := 0
	for i in 200:
		var p := Vector2i(randi() % a.get_width(), randi() % a.get_height())
		if a.get_pixel(p.x, p.y).is_equal_approx(b.get_pixel(p.x, p.y)) == false:
			diff += 1
	print("video_test: %dx%d · reproduciendo=%s · píxeles distintos entre 2 fotogramas: %d/200" % [a.get_width(), a.get_height(), str(v.is_playing()), diff])
	get_tree().quit()

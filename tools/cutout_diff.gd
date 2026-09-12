extends SceneTree
## Recorta lo que una edición añadió a una escena: compara base y editada píxel a píxel dentro de
## una caja y guarda solo la diferencia con alfa, como sprite para superponer en el juego.
##   godot --headless --path . -s res://tools/cutout_diff.gd -- base.png editada.png salida.png x y w h [umbral]
## Imprime el ancla en fracciones del lienzo editado, para data/levels/<id>.json → props.

const FEATHER := 0.08


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	assert(a.size() >= 7, "faltan argumentos")
	var base := Image.load_from_file(a[0])
	var edited := Image.load_from_file(a[1])
	var box := Rect2i(int(a[3]), int(a[4]), int(a[5]), int(a[6]))
	var threshold := float(a[7]) if a.size() > 7 else 0.16
	if base.get_size() != edited.get_size():
		base.resize(edited.get_width(), edited.get_height(), Image.INTERPOLATE_LANCZOS)
	base.convert(Image.FORMAT_RGBA8)
	edited.convert(Image.FORMAT_RGBA8)

	var out := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	var opaque := 0
	for y in box.size.y:
		for x in box.size.x:
			var px := box.position + Vector2i(x, y)
			var b := base.get_pixelv(px)
			var e := edited.get_pixelv(px)
			var d := Vector3(b.r, b.g, b.b).distance_to(Vector3(e.r, e.g, e.b))
			var alpha := clampf((d - threshold) / FEATHER, 0.0, 1.0)
			if alpha > 0.5:
				opaque += 1
			out.set_pixel(x, y, Color(e.r, e.g, e.b, alpha))
	_despeckle(out)
	var used := out.get_used_rect()
	var cropped := out.get_region(used)
	assert(cropped.save_png(a[2]) == OK, "no se pudo guardar " + a[2])
	var origin := box.position + used.position
	print("recorte %s: %dx%d, %d px opacos · ancla {\"x\": %.4f, \"y\": %.4f, \"w\": %.4f}" % [
		a[2].get_file(), cropped.get_width(), cropped.get_height(), opaque,
		float(origin.x) / edited.get_width(), float(origin.y) / edited.get_height(), float(cropped.get_width()) / edited.get_width()])
	quit()


## Quita píxeles aislados: un píxel opaco con menos de 3 vecinos opacos se hace transparente.
func _despeckle(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var copy := image.duplicate()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if copy.get_pixel(x, y).a < 0.5:
				continue
			var n := 0
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if (dx != 0 or dy != 0) and copy.get_pixel(x + dx, y + dy).a >= 0.5:
						n += 1
			if n < 3:
				var c := image.get_pixel(x, y)
				image.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))

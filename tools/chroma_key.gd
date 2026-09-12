extends SceneTree
## Quita el fondo plano de los sprites generados (<carpeta>/raw/*.png) y guarda el recorte con
## alfa en <carpeta>/<nombre>.png. El color de fondo se toma de las esquinas de cada imagen, así
## que da igual que el modelo haya pintado verde, naranja o blanco.
##   godot --headless --path . -s res://tools/chroma_key.gd -- res://assets/layers/girl res://assets/layers/men

const DEFAULT_DIRS := ["res://assets/layers/girl", "res://assets/layers/men"]
const PADDING := 8
## Distancia de color (0..1) por debajo de la cual un píxel es fondo; entre TOL y TOL*1.6 se difumina.
const TOL := 0.16


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	for folder: String in (args if not args.is_empty() else DEFAULT_DIRS):
		_process_folder(folder)
	print("chroma key listo")
	quit()


func _process_folder(folder: String) -> void:
	var raw_dir := folder + "/raw"
	var dir := DirAccess.open(raw_dir)
	if dir == null:
		print("  (sin %s)" % raw_dir)
		return
	for file in dir.get_files():
		if not file.ends_with(".png") or file.begins_with("_"):
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(raw_dir + "/" + file))
		var key := _corner_color(image)
		_key_out(image, key)
		# La capa de mesa se recorta al lado izquierdo del máster (mesa y monitor), sin la chica.
		if file.begins_with("desk"):
			var meta := _read_meta(folder)
			var cut := int(meta.get("desk_cut_x", 600))
			image.fill_rect(Rect2i(cut, 0, image.get_width() - cut, image.get_height()), Color(0, 0, 0, 0))
			for r in meta.get("desk_clear_rects", []):
				image.fill_rect(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])), Color(0, 0, 0, 0))
		var cropped := image if file.begins_with("desk") or folder.ends_with("/girl") else _crop_to_content(image)
		var out := folder + "/" + file
		assert(cropped.save_png(ProjectSettings.globalize_path(out)) == OK, "No se pudo guardar " + out)
		print("  %s → %dx%d (fondo %s)" % [out.trim_prefix("res://assets/"), cropped.get_width(), cropped.get_height(), key.to_html(false)])


func _read_meta(folder: String) -> Dictionary:
	var path := folder + "/meta.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Mediana de las cuatro esquinas (parches de 12 px), para ignorar algún borde sucio.
func _corner_color(image: Image) -> Color:
	var w := image.get_width()
	var h := image.get_height()
	var samples: Array[Color] = []
	for corner in [Vector2i(0, 0), Vector2i(w - 12, 0), Vector2i(0, h - 12), Vector2i(w - 12, h - 12)]:
		for y in range(corner.y, corner.y + 12, 3):
			for x in range(corner.x, corner.x + 12, 3):
				samples.append(image.get_pixel(x, y))
	samples.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	return samples[samples.size() / 2]


func _key_out(image: Image, key: Color) -> void:
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	var kv := Vector3(key.r, key.g, key.b)
	# Relleno por inundación desde los bordes sobre píxeles "de fondo" (cerca del color clave,
	# con margen ancho para atravesar el borde difuminado).
	var visited := PackedByteArray()
	visited.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		if visited[idx] == 1:
			continue
		visited[idx] = 1
		var x := idx % w
		var y := idx / w
		var c := image.get_pixel(x, y)
		# Dominancia del canal del color clave (verde) sobre los otros dos: independiente del brillo,
		# así la sombra verdosa también cae. Para fondos no verdes se usa la distancia de color.
		var green_key := key.g > key.r + 0.15 and key.g > key.b + 0.15
		var d: float
		if green_key:
			var dominance := c.g - maxf(c.r, c.b)
			d = 0.0 if dominance > 0.22 else (TOL if dominance > 0.10 else 1.0)
			if dominance > 0.10 and dominance <= 0.22:
				d = TOL + (0.22 - dominance) / 0.12 * TOL * 0.6
		else:
			d = Vector3(c.r, c.g, c.b).distance_to(kv)
		if d >= TOL * 1.6:
			continue
		if d < TOL:
			image.set_pixel(x, y, Color(0, 0, 0, 0))
		else:
			var alpha := (d - TOL) / (TOL * 0.6)
			var g := minf(c.g, (c.r + c.b) * 0.5 + 0.05) if green_key else c.g
			image.set_pixel(x, y, Color(c.r, g, c.b, alpha))
		if x > 0:
			stack.append(idx - 1)
		if x < w - 1:
			stack.append(idx + 1)
		if y > 0:
			stack.append(idx - w)
		if y < h - 1:
			stack.append(idx + w)
	if green_key_color(key):
		_sweep_green(image)


static func green_key_color(key: Color) -> bool:
	return key.g > key.r + 0.15 and key.g > key.b + 0.15


## Segunda pasada: cualquier píxel verde-lima que haya quedado encerrado (entre la silla y la
## espalda, bajo la mesa, entre los dedos) también es fondo.
func _sweep_green(image: Image) -> void:
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var dominance := c.g - maxf(c.r, c.b)
			# Verde lima del croma: mucho verde, poco azul. La ropa/piel nunca cumple esto.
			if dominance > 0.18 and c.b < c.g * 0.75:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			elif dominance > 0.08 and c.b < c.g * 0.8 and c.a > 0.0:
				var alpha := clampf(1.0 - (dominance - 0.08) / 0.10, 0.0, 1.0) * c.a
				image.set_pixel(x, y, Color(c.r, minf(c.g, (c.r + c.b) * 0.5 + 0.03), c.b, alpha))


func _crop_to_content(image: Image) -> Image:
	var rect := image.get_used_rect()
	if rect.size == Vector2i.ZERO:
		return image
	rect = rect.grow(PADDING).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(rect)

class_name UIKit
## Fábrica de controles. Tema "oficina de noche": paneles grafito, acentos cálidos.

const BG := Color("#23262f")
const PANEL := Color("#2d3140")
const PANEL_LIGHT := Color("#3a3f52")
const TEXT := Color("#f3f1ea")
const TEXT_DIM := Color("#a7abb8")
const PRIMARY := Color("#e8557a")
const GOLD := Color("#f4c95d")
const OK := Color("#4ade80")
const BAD := Color("#ef4444")
const HEART := Color("#ff6b9d")


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func title(text: String, size: int = 40) -> Label:
	var node := label(text, size)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node


static func button(text: String, color: Color = PRIMARY, size: int = 22) -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size)
	node.custom_minimum_size = Vector2(0, 56)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		if state == "hover":
			style.bg_color = color.lightened(0.12)
		elif state == "pressed":
			style.bg_color = color.darkened(0.15)
		elif state == "disabled":
			style.bg_color = color.darkened(0.55)
		style.set_corner_radius_all(10)
		style.content_margin_left = 18
		style.content_margin_right = 18
		node.add_theme_stylebox_override(state, style)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", TEXT)
	node.add_theme_color_override("font_pressed_color", TEXT)
	node.add_theme_color_override("font_disabled_color", TEXT_DIM)
	return node


static func panel(color: Color = PANEL, radius: int = 14, margin: int = 18) -> PanelContainer:
	var node := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	node.add_theme_stylebox_override("panel", style)
	return node


static func vbox(separation: int = 10) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func hbox(separation: int = 10) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func spacer() -> Control:
	var node := Control.new()
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


static func fill_background(parent: Control, color: Color = BG) -> void:
	var bg := ColorRect.new()
	bg.color = color
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)


# --- Avatares ----------------------------------------------------------------------

const CIRCLE_MASK := preload("res://assets/shaders/circle_mask.gdshader")


## Foto de perfil circular de un compañero: la cabeza recortada de su sprite
## (assets/coworkers/<id>.png). Sin sprite, un círculo de su color con la inicial.
static func avatar(id: String, size: float) -> Control:
	var data := Catalog.coworker(id)
	var color := Color.html(data.get("color", "#888888"))
	var photo := "res://assets/avatars/%s.png" % id
	if ResourceLoader.exists(photo):
		# Foto de perfil dibujada a propósito (cuadrada): se recorta en círculo tal cual.
		var rect := TextureRect.new()
		rect.texture = load(photo)
		rect.custom_minimum_size = Vector2(size, size)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		var material := ShaderMaterial.new()
		material.shader = CIRCLE_MASK
		rect.material = material
		return rect
	var path := "res://assets/coworkers/%s.png" % id
	if ResourceLoader.exists(path):
		var sprite: Texture2D = load(path)
		var atlas := AtlasTexture.new()
		atlas.atlas = sprite
		atlas.region = head_region(path, sprite)
		var rect := TextureRect.new()
		rect.texture = atlas
		rect.custom_minimum_size = Vector2(size, size)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		var material := ShaderMaterial.new()
		material.shader = CIRCLE_MASK
		rect.material = material
		# Fondo de color detrás de la cabeza recortada.
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(size, size)
		var disc := Control.new()
		disc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		disc.draw.connect(func() -> void: disc.draw_circle(Vector2(size, size) * 0.5, size * 0.5, color.darkened(0.35)))
		holder.add_child(disc)
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.add_child(rect)
		return holder
	var fallback := Control.new()
	fallback.custom_minimum_size = Vector2(size, size)
	var initial: String = data.get("name", id).substr(0, 1)
	fallback.draw.connect(func() -> void:
		fallback.draw_circle(Vector2(size, size) * 0.5, size * 0.5, color)
		fallback.draw_string(ThemeDB.fallback_font, Vector2(0, size * 0.68), initial, HORIZONTAL_ALIGNMENT_CENTER, size, int(size * 0.5), TEXT))
	return fallback


static var _head_cache: Dictionary = {}


## Cuadrado que encierra la cabeza del sprite: caja de píxeles opacos del tercio superior,
## ampliada un 15 %. Se calcula una vez por sprite.
static func head_region(path: String, sprite: Texture2D) -> Rect2:
	if _head_cache.has(path):
		return _head_cache[path]
	var image := sprite.get_image()
	var w := image.get_width()
	var h := image.get_height()
	var min_x := w
	var max_x := 0
	var min_y := h
	var max_y := 0
	var limit := int(h * 0.30)
	for y in range(0, limit, 2):
		for x in range(0, w, 2):
			if image.get_pixel(x, y).a > 0.5:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	var region: Rect2
	if max_x <= min_x:
		region = Rect2(0, 0, w, w)
	else:
		var side := maxf(max_x - min_x, max_y - min_y) * 1.15
		var center := Vector2((min_x + max_x) * 0.5, min_y + (max_y - min_y) * 0.5)
		region = Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	_head_cache[path] = region
	return region


## Botón plano sin fondo (iconos del teléfono).
static func icon_button(text: String, size: int = 22) -> Button:
	var node := Button.new()
	node.text = text
	node.flat = true
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", Color("#00a884"))
	return node


# --- Iconos --------------------------------------------------------------------------
# Tabler Icons (MIT), SVG de 24 px con trazo en currentColor: se tintan con `modulate`.
# Godot importa los SVG a la escala del import; para que no salgan borrosos al agrandar la
# ventana se rasterizan a 96 px (ver assets/icons/*.svg.import, scale=4).

const ICON_DIR := "res://assets/icons/"


static func icon(name: String, size: float = 20.0, color: Color = TEXT) -> TextureRect:
	var rect := TextureRect.new()
	var path := ICON_DIR + name + ".svg"
	if ResourceLoader.exists(path):
		rect.texture = load(path)
	rect.custom_minimum_size = Vector2(size, size)
	rect.size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.modulate = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Botón con icono (y texto opcional a la derecha). El icono hereda el color del texto.
static func icon_text_button(icon_name: String, text: String, color: Color = PANEL_LIGHT, size: int = 20, icon_size: float = 22.0) -> Button:
	var node := button(text, color, size)
	node.icon = load(ICON_DIR + icon_name + ".svg") if ResourceLoader.exists(ICON_DIR + icon_name + ".svg") else null
	node.expand_icon = true
	node.add_theme_constant_override("icon_max_width", int(icon_size))
	node.add_theme_constant_override("h_separation", 8 if text != "" else 0)
	if text == "":
		# Icono solo: el relleno horizontal del botón se reduce para que el icono quede centrado y grande.
		for state in ["normal", "hover", "pressed", "disabled"]:
			var style: StyleBoxFlat = node.get_theme_stylebox(state).duplicate()
			style.content_margin_left = 8
			style.content_margin_right = 8
			node.add_theme_stylebox_override(state, style)
	node.add_theme_color_override("icon_normal_color", TEXT)
	node.add_theme_color_override("icon_hover_color", TEXT)
	node.add_theme_color_override("icon_pressed_color", TEXT)
	node.add_theme_color_override("icon_disabled_color", TEXT_DIM)
	if text == "":
		node.custom_minimum_size = Vector2(node.custom_minimum_size.y, node.custom_minimum_size.y)
	return node


## Botón plano solo con icono (cabeceras del teléfono).
static func flat_icon_button(icon_name: String, size: float = 22.0, color: Color = TEXT) -> Button:
	var node := Button.new()
	node.flat = true
	node.icon = load(ICON_DIR + icon_name + ".svg") if ResourceLoader.exists(ICON_DIR + icon_name + ".svg") else null
	node.expand_icon = true
	node.custom_minimum_size = Vector2(size + 12, size + 12)
	node.add_theme_constant_override("icon_max_width", int(size))
	node.add_theme_color_override("icon_normal_color", color)
	node.add_theme_color_override("icon_hover_color", Color("#00a884"))
	node.add_theme_color_override("icon_pressed_color", color)
	return node


## Fila de N estrellas (llenas hasta `filled`), para puntuaciones.
static func stars(filled: int, total: int = 3, size: float = 28.0) -> HBoxContainer:
	var row := hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in total:
		row.add_child(icon("star-filled" if i < filled else "star", size, GOLD if i < filled else TEXT_DIM))
	return row

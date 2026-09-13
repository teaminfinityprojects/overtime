extends Control
## Menú de inicio: splash art a pantalla completa (Candela a la derecha) y el menú en una columna
## a la izquierda, sobre un degradado para que se lea.

const SPLASH := "res://assets/ui/title_splash.png"
const LOGO := "res://assets/ui/logo.png"
const COLUMN_WIDTH := 400.0


func _ready() -> void:
	UIKit.fill_background(self)
	_backdrop()
	var column := UIKit.vbox(12)
	column.anchor_left = 0.0
	column.anchor_right = 0.0
	column.anchor_top = 0.0
	column.anchor_bottom = 1.0
	column.offset_left = 56
	column.offset_right = 56 + COLUMN_WIDTH
	column.offset_top = 0
	column.offset_bottom = 0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(column)

	# Logotipo (assets/ui/logo.png, recortado sobre verde) o, si falta, el título en texto.
	if ResourceLoader.exists(LOGO):
		var logo := TextureRect.new()
		logo.texture = load(LOGO)
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		var tex_size: Vector2 = logo.texture.get_size()
		logo.custom_minimum_size = Vector2(COLUMN_WIDTH, COLUMN_WIDTH * tex_size.y / tex_size.x)
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		column.add_child(logo)
	else:
		var title := UIKit.title("OVERTIME", 84)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		title.add_theme_constant_override("outline_size", 10)
		column.add_child(title)
	var subtitle := UIKit.label("Termina el informe. Atiende a la oficina.", 20, UIKit.TEXT_DIM)
	column.add_child(subtitle)
	var hearts := UIKit.hbox(6)
	hearts.add_child(UIKit.icon("heart-filled", 20, UIKit.HEART))
	hearts.add_child(UIKit.bold(str(Meta.hearts), 20, UIKit.HEART))
	hearts.add_child(UIKit.label("corazones", 14, UIKit.TEXT_DIM))
	column.add_child(hearts)
	column.add_child(_gap(10))

	for id in Catalog.level_order:
		var level := Catalog.level(id)
		var best: Dictionary = Meta.best.get(id, {})
		var n_stars := int(best.get("stars", 0))
		var unlocked := Meta.level_unlocked(id)
		var button := UIKit.icon_text_button("player-play" if unlocked else "lock", level["name"], UIKit.PRIMARY if unlocked else UIKit.PANEL_LIGHT, 24, 24)
		button.custom_minimum_size = Vector2(0, 60)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not unlocked
		button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/game.tscn"))
		column.add_child(button)
		if n_stars > 0:
			var row := UIKit.hbox(8)
			row.add_child(UIKit.stars(n_stars, 3, 18))
			row.add_child(UIKit.label("mejor jornada · informe %.0f %%" % float(best.get("report", 0.0)), 12, UIKit.TEXT_DIM))
			column.add_child(row)
	column.add_child(_gap(6))

	# Los ajustes (volumen, pantalla completa) viven en el juego (⚙); aquí solo lo esencial.
	var quit := UIKit.icon_text_button("x", "Salir del juego", UIKit.PANEL, 14)
	quit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)
	if OS.is_debug_build():
		var reset := UIKit.button("DEV · borrar progreso", UIKit.PANEL, 12)
		reset.pressed.connect(func() -> void:
			Meta.reset()
			get_tree().reload_current_scene())
		column.add_child(reset)
	var version := UIKit.label("v%s · +18 · TeamSquad" % ProjectSettings.get_setting("application/config/version", "0.1"), 12, UIKit.TEXT_DIM)
	column.add_child(version)


## Splash art a pantalla completa (Candela a la derecha) o, si falta, la escena base atenuada.
## Sobre él, un degradado oscuro a la izquierda para que el menú se lea.
func _backdrop() -> void:
	var path := SPLASH if ResourceLoader.exists(SPLASH) else "res://assets/scenes/desk_tuesday/work_top_bottom_none.png"
	if ResourceLoader.exists(path):
		var art := TextureRect.new()
		art.texture = load(path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if path != SPLASH:
			art.modulate = Color(0.55, 0.55, 0.6, 1.0)
		add_child(art)
		move_child(art, 1)
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(UIKit.BG, 0.92))
	gradient.set_color(1, Color(UIKit.BG, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(1.0, 0.0)
	tex.width = 256
	tex.height = 4
	shade.texture = tex
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.anchor_left = 0.0
	shade.anchor_right = 0.0
	shade.anchor_top = 0.0
	shade.anchor_bottom = 1.0
	shade.offset_right = 640
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	move_child(shade, 2)


func _gap(height: float) -> Control:
	var node := Control.new()
	node.custom_minimum_size = Vector2(0, height)
	return node


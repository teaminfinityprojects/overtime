extends Control
class_name Game
## Pantalla de jornada: a la izquierda el teléfono de Candela (chats + widget de trabajo) y los
## controles; a la derecha la escena con la ficha del visitante encima. Toda la lógica está en
## Day; aquí solo se muestra y se manda.

const PANEL_WIDTH := 430.0

var day: Day
var level_id: String = "desk_tuesday"

var _phone: Phone
var _visitor_panel: PanelContainer
var _visitor_box: VBoxContainer
var _mode_button: Button
var _top_button: Button
var _bottom_button: Button
var _speed_button: Button
var _scene: Control
var _flash: ColorRect
var _toast: Label
var _dialogue: PanelContainer
var _dialogue_label: Label
var _dialogue_tween: Tween
var _ring: Control


func _ready() -> void:
	UIKit.fill_background(self)
	day = Day.new()
	add_child(day)
	_build()
	day.visit_started.connect(func(id: String) -> void: _toast_show("%s se acerca a tu mesa" % Catalog.coworker(id)["name"], Color.html(Catalog.coworker(id)["color"])))
	day.visit_satisfied.connect(func(id: String) -> void:
		_toast_show("“%s”" % Catalog.coworker(id).get("finish", ""), UIKit.OK)
		_flash_color(Color(1.0, 0.6, 0.75, 0.35)))
	day.visit_aggravated.connect(func(id: String) -> void: _toast_show("%s se está impacientando…" % Catalog.coworker(id)["name"], UIKit.BAD))
	day.productivity_hit.connect(func(_amount: float, reason: String) -> void:
		_toast_show(reason, UIKit.BAD)
		_flash_color(Color(0.9, 0.1, 0.1, 0.4)))
	day.dress_check.connect(func(passed: bool) -> void:
		if passed:
			_toast_show("El cliente ha pasado. Ibas presentable.", UIKit.OK))
	day.day_ended.connect(_on_day_ended)
	day.line_spoken.connect(_on_line)
	day.climax.connect(func(_id: String) -> void: _flash_color(Color(1.0, 1.0, 1.0, 0.7)))
	day.distracted.connect(func(started: bool) -> void:
		if started:
			_toast_show("Candela se toma un descanso… el informe puede esperar.", UIKit.HEART))
	_phone.bind(day)
	_phone.reply_chosen.connect(func(message: Dictionary, option: Dictionary) -> void: day.answer(message, option))
	day.start(Catalog.level(level_id))
	_scene.day = day


func _process(_delta: float) -> void:
	_refresh()


# --- Construcción ------------------------------------------------------------

func _build() -> void:
	var root := UIKit.hbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var left := UIKit.panel(UIKit.PANEL, 0, 14)
	left.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	root.add_child(left)
	var column := UIKit.vbox(10)
	left.add_child(column)

	# Teléfono.
	_phone = Phone.new()
	_phone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_phone)

	# Controles.
	_mode_button = UIKit.button("Follar", UIKit.PRIMARY, 24)
	_mode_button.custom_minimum_size = Vector2(0, 58)
	_mode_button.pressed.connect(func() -> void: day.set_mode(Day.Mode.WORK if day.mode == Day.Mode.FUCK else Day.Mode.FUCK))
	column.add_child(_mode_button)
	var clothes := UIKit.hbox(10)
	_top_button = UIKit.icon_text_button("shirt", "Blusa", UIKit.PANEL_LIGHT, 20)
	_top_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_button.pressed.connect(day.toggle_top)
	_bottom_button = UIKit.icon_text_button("hanger", "Falda", UIKit.PANEL_LIGHT, 20)
	_bottom_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_button.pressed.connect(day.toggle_bottom)
	clothes.add_child(_top_button)
	clothes.add_child(_bottom_button)
	column.add_child(clothes)
	var footer := UIKit.hbox(10)
	_speed_button = UIKit.button("x1", UIKit.PANEL_LIGHT, 16)
	_speed_button.custom_minimum_size = Vector2(0, 40)
	_speed_button.pressed.connect(func() -> void: day.speed = 2.0 if day.speed == 1.0 else 1.0)
	footer.add_child(_speed_button)
	var fullscreen := UIKit.icon_text_button("maximize", "", UIKit.PANEL_LIGHT, 16, 22)
	fullscreen.custom_minimum_size = Vector2(44, 40)
	fullscreen.pressed.connect(func() -> void: Screen.set_fullscreen(not Screen.is_fullscreen()))
	footer.add_child(fullscreen)
	footer.add_child(UIKit.spacer())
	var menu := UIKit.button("Menú", UIKit.PANEL_LIGHT, 16)
	menu.custom_minimum_size = Vector2(0, 40)
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	footer.add_child(menu)
	column.add_child(footer)

	# Escena.
	var scene_holder := Control.new()
	scene_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene_holder.clip_contents = true
	root.add_child(scene_holder)
	_scene = Control.new()
	_scene.set_script(load("res://scripts/game/scene_view.gd"))
	_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene_holder.add_child(_scene)

	# Ficha del visitante, flotando sobre la escena.
	_visitor_panel = UIKit.panel(Color(0.05, 0.05, 0.08, 0.78), 14, 12)
	_visitor_panel.anchor_left = 1.0
	_visitor_panel.anchor_right = 1.0
	_visitor_panel.offset_left = -340
	_visitor_panel.offset_right = -24
	_visitor_panel.offset_top = 24
	_visitor_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_visitor_box = UIKit.vbox(6)
	_visitor_panel.add_child(_visitor_box)
	scene_holder.add_child(_visitor_panel)

	# Barra de diálogo del compañero, sobre la escena.
	_dialogue = UIKit.panel(Color(0.05, 0.05, 0.08, 0.82), 12, 14)
	_dialogue.anchor_left = 0.0
	_dialogue.anchor_right = 1.0
	_dialogue.anchor_top = 1.0
	_dialogue.anchor_bottom = 1.0
	_dialogue.offset_left = 24
	_dialogue.offset_right = -24
	_dialogue.offset_top = -100
	_dialogue.offset_bottom = -24
	_dialogue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_label = UIKit.label("", 24)
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.add_child(_dialogue_label)
	_dialogue.modulate.a = 0.0
	scene_holder.add_child(_dialogue)

	_toast = UIKit.label("", 22)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.position = Vector2(24, 24)
	_toast.modulate.a = 0.0
	scene_holder.add_child(_toast)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	# Anillo de progreso al quitarse o ponerse una prenda, sobre los botones de ropa.
	_ring = Control.new()
	_ring.set_script(load("res://scripts/ui/progress_ring.gd"))
	_ring.anchor_top = 1.0
	_ring.anchor_bottom = 1.0
	_ring.offset_top = -190
	_ring.offset_bottom = -80
	_ring.offset_left = PANEL_WIDTH * 0.5 - 55
	_ring.offset_right = PANEL_WIDTH * 0.5 + 55
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)


func _bar(color: Color, height: float = 12.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


# --- Refresco ----------------------------------------------------------------

func _refresh() -> void:
	var solo := day.visitor.is_empty()
	var exposed := not day.top_on or not day.bottom_on
	var label := "Trabajar"
	if day.mode != Day.Mode.FUCK:
		if solo:
			label = "Tocarse · %s" % ("tetas" if not day.top_on and day.bottom_on else ("suave" if day.top_on else "a fondo")) if exposed else "Follar"
		else:
			label = "Follar · %s" % Day.act_label(day.current_act())
	_mode_button.text = label
	_mode_button.disabled = day.changing != "" or (solo and not exposed)
	# El estado de cada prenda se lee por color: clara puesta, apagada quitada, dorada en transición.
	_top_button.text = "Blusa"
	_bottom_button.text = "Falda"
	for pair in [[_top_button, day.top_on, day.changing == "top"], [_bottom_button, day.bottom_on, day.changing == "bottom"]]:
		var b: Button = pair[0]
		var tint: Color = UIKit.GOLD if pair[2] else (UIKit.TEXT if pair[1] else UIKit.TEXT_DIM)
		b.add_theme_color_override("icon_normal_color", tint)
		b.add_theme_color_override("icon_hover_color", tint)
		b.add_theme_color_override("font_color", tint)
		b.add_theme_color_override("font_hover_color", tint)
	_top_button.disabled = day.changing != ""
	_bottom_button.disabled = day.changing != ""
	_ring.visible = day.changing != ""
	if _ring.visible:
		_ring.set("progress", day.changing_progress())
		_ring.set("label", "%.1f" % day.changing_left)
		_ring.set("icon", "shirt" if day.changing == "top" else "hanger")
		_ring.queue_redraw()
	_speed_button.text = "x%d" % int(day.speed)
	_refresh_visitor()


func _refresh_visitor() -> void:
	for child in _visitor_box.get_children():
		child.queue_free()
	if day.visitor.is_empty():
		_visitor_panel.visible = not day.queue.is_empty()
		if _visitor_panel.visible:
			_visitor_box.add_child(UIKit.label("Alguien viene de camino…", 16, UIKit.TEXT_DIM))
		return
	_visitor_panel.visible = true
	var data := Catalog.coworker(day.visitor["id"])
	var head := UIKit.hbox(10)
	head.add_child(UIKit.avatar(day.visitor["id"], 36))
	var who := UIKit.vbox(0)
	who.add_child(UIKit.label(data["name"], 20, Color.html(data["color"]).lightened(0.3)))
	var wants: Dictionary = data.get("wants", {})
	var wanted_act := Day.act_for(bool(wants.get("top", true)), bool(wants.get("bottom", true)))
	who.add_child(UIKit.label("quiere: %s" % Day.act_label(wanted_act), 14, UIKit.OK if day.wants_met(data) else UIKit.TEXT_DIM))
	head.add_child(who)
	if not day.queue.is_empty():
		head.add_child(UIKit.spacer())
		head.add_child(UIKit.label("+%d esperando" % day.queue.size(), 14, UIKit.BAD))
	_visitor_box.add_child(head)
	var arousal := _bar(UIKit.HEART)
	arousal.value = day.visitor["arousal"]
	_visitor_box.add_child(arousal)
	var patience_ratio := clampf(1.0 - day.visitor["waited"] / float(data["patience"]), 0.0, 1.0)
	var patience := _bar(UIKit.BAD if day.visitor.get("aggravated", false) else UIKit.GOLD, 6.0)
	patience.value = patience_ratio * 100.0
	_visitor_box.add_child(patience)
	_visitor_box.add_child(UIKit.label("%d %% · %s" % [int(day.visitor["arousal"]), "¡impaciente!" if day.visitor.get("aggravated", false) else "paciencia"], 12, UIKit.TEXT_DIM))


# --- Feedback ----------------------------------------------------------------

func _on_line(who: String, text: String) -> void:
	if text == "":
		return
	var data := Catalog.coworker(who)
	_dialogue_label.text = text
	_dialogue_label.add_theme_color_override("font_color", Color.html(data.get("color", "#ffffff")).lightened(0.45))
	if _dialogue_tween:
		_dialogue_tween.kill()
	_dialogue_tween = create_tween()
	_dialogue_tween.tween_property(_dialogue, "modulate:a", 1.0, 0.15)
	_dialogue_tween.tween_interval(4.0)
	_dialogue_tween.tween_property(_dialogue, "modulate:a", 0.0, 0.5)


func _toast_show(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, 0.1)
	tween.tween_interval(2.2)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _flash_color(color: Color) -> void:
	_flash.color = color
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)


func _on_day_ended(won: bool, stars: int) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.75)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var card := UIKit.panel(UIKit.PANEL, 20, 28)
	var box := UIKit.vbox(12)
	box.custom_minimum_size = Vector2(560, 0)
	card.add_child(box)
	box.add_child(UIKit.title("Informe entregado" if won else "Se acabó la jornada", 40))
	box.add_child(UIKit.stars(stars, 3, 44))
	box.add_child(UIKit.title("Informe %.0f %% · %d compañeros atendidos · %d cabreados" % [day.report, day.satisfied_count, day.aggravated_count], 20))
	if won:
		var reward := UIKit.hbox(6)
		reward.alignment = BoxContainer.ALIGNMENT_CENTER
		reward.add_child(UIKit.icon("heart-filled", 22, UIKit.HEART))
		reward.add_child(UIKit.label("+%d corazones" % (10 * stars), 22))
		box.add_child(reward)
	var buttons := UIKit.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := UIKit.button("Otra jornada", UIKit.PRIMARY)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	buttons.add_child(again)
	var menu := UIKit.button("Menú", UIKit.PANEL_LIGHT)
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	buttons.add_child(menu)
	box.add_child(buttons)
	center.add_child(card)
	add_child(overlay)

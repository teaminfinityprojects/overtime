extends Control
class_name Game
## Pantalla de jornada. Izquierda: el teléfono de Candela y la tarjeta de acciones. Derecha: la
## escena con el HUD (reloj, informe, productividad), la ficha del visitante y la barra de diálogo.
## Toda la lógica está en Day; aquí solo se muestra y se manda.

const PANEL_WIDTH := 430.0

var day: Day
var level_id: String = "desk_tuesday"

var _phone: Phone
var _mode_button: Button
var _mode_hint: Label
var _top_button: Button
var _bottom_button: Button
var _top_state: Label
var _bottom_state: Label
var _speed_button: Button
var _scene: Control
var _flash: ColorRect
var _toast: PanelContainer
var _toast_label: Label
var _toast_icon: TextureRect
var _toast_tween: Tween
var _dialogue: PanelContainer
var _dialogue_avatar: Control
var _dialogue_name: Label
var _dialogue_label: Label
var _dialogue_tween: Tween
var _ring: Control
var _overlay_node: Control

# HUD sobre la escena.
var _hud_clock: Label
var _hud_left: Label
var _hud_report_bar: ProgressBar
var _hud_report_label: Label
var _hud_pips: HBoxContainer
var _hud_state: PanelContainer

# Ficha del visitante.
var _visitor_panel: PanelContainer
var _visitor_box: VBoxContainer
var _visitor_id: String = ""
var _visitor_arousal: ProgressBar
var _visitor_patience: ProgressBar
var _visitor_status: Label
var _visitor_wants: Label
var _visitor_queue: Label


func _ready() -> void:
	UIKit.fill_background(self)
	day = Day.new()
	add_child(day)
	_build()
	day.visit_started.connect(func(id: String) -> void:
		Sfx.play("steps")
		_toast_show("%s se acerca a tu mesa" % Catalog.coworker(id)["name"], Color.html(Catalog.coworker(id)["color"]), "steps"))
	day.message_received.connect(func(_m: Dictionary) -> void: Sfx.play("notify"))
	day.message_answered.connect(func(_m: Dictionary, _o: Dictionary) -> void: Sfx.play("send"))
	day.visit_satisfied.connect(func(id: String) -> void:
		_toast_show("“%s”" % Catalog.coworker(id).get("finish", ""), UIKit.OK, "mood-smile")
		_flash_color(Color(1.0, 0.6, 0.75, 0.35)))
	day.visit_aggravated.connect(func(id: String) -> void:
		Sfx.play("knock")
		_toast_show("%s se está impacientando…" % Catalog.coworker(id)["name"], UIKit.BAD, "hourglass"))
	day.visit_left.connect(func(id: String) -> void:
		Sfx.play("steps", -6.0)
		_toast_show("%s se ha ido sin esperar más." % Catalog.coworker(id)["name"], UIKit.BAD, "alert-triangle"))
	day.productivity_hit.connect(func(_amount: float, reason: String) -> void:
		Sfx.play("fail")
		_toast_show(reason, UIKit.BAD, "alert-triangle")
		_flash_color(Color(0.9, 0.1, 0.1, 0.4)))
	day.dress_check.connect(func(passed: bool) -> void:
		if passed:
			Sfx.play("reward")
			_toast_show("El cliente ha pasado. Ibas presentable.", UIKit.OK, "check"))
	day.day_ended.connect(_on_day_ended)
	day.line_spoken.connect(_on_line)
	day.climax.connect(func(_id: String) -> void:
		Sfx.play("success")
		_flash_color(Color(1.0, 1.0, 1.0, 0.7)))
	day.distracted.connect(func(started: bool) -> void:
		if started:
			_toast_show("Candela se toma un descanso… el informe puede esperar.", UIKit.HEART, "flame"))
	_phone.bind(day)
	_phone.reply_chosen.connect(func(message: Dictionary, option: Dictionary) -> void: day.answer(message, option))
	day.start(Catalog.level(level_id))
	_scene.day = day
	# Fundido de entrada.
	_flash.color = Color(UIKit.BG, 1.0)
	create_tween().tween_property(_flash, "color:a", 0.0, 0.6)


func _process(_delta: float) -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not day.finished:
		if _overlay_node:
			_close_overlay()
		else:
			_open_pause()


# --- Construcción ------------------------------------------------------------

func _build() -> void:
	var root := UIKit.hbox(0)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var left := UIKit.panel(UIKit.PANEL, 0, 14)
	left.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	root.add_child(left)
	var column := UIKit.vbox(12)
	left.add_child(column)

	# Teléfono.
	_phone = Phone.new()
	_phone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_phone)

	# Tarjeta de acciones: acción principal + ropa.
	var actions := UIKit.panel(UIKit.BG, 16, 12)
	var actions_box := UIKit.vbox(8)
	actions.add_child(actions_box)
	_mode_button = UIKit.icon_text_button("heart", "Follar", UIKit.PRIMARY, 22, 26)
	_mode_button.custom_minimum_size = Vector2(0, 56)
	_mode_button.pressed.connect(func() -> void: day.set_mode(Day.Mode.WORK if day.mode == Day.Mode.FUCK else Day.Mode.FUCK))
	actions_box.add_child(_mode_button)
	_mode_hint = UIKit.label("", 12, UIKit.TEXT_DIM)
	_mode_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	actions_box.add_child(_mode_hint)
	var clothes := UIKit.hbox(8)
	_top_button = UIKit.icon_text_button("shirt", "Blusa", UIKit.PANEL_LIGHT, 18)
	_top_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_button.custom_minimum_size = Vector2(0, 50)
	_top_button.pressed.connect(func() -> void:
		day.toggle_top()
		if day.changing == "top":
			Sfx.play("cloth"))
	_bottom_button = UIKit.icon_text_button("hanger", "Falda", UIKit.PANEL_LIGHT, 18)
	_bottom_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_button.custom_minimum_size = Vector2(0, 50)
	_bottom_button.pressed.connect(func() -> void:
		day.toggle_bottom()
		if day.changing == "bottom":
			Sfx.play("cloth"))
	clothes.add_child(_top_button)
	clothes.add_child(_bottom_button)
	actions_box.add_child(clothes)
	var states := UIKit.hbox(8)
	_top_state = UIKit.label("puesta", 11, UIKit.TEXT_DIM)
	_top_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_top_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_state = UIKit.label("puesta", 11, UIKit.TEXT_DIM)
	_bottom_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	states.add_child(_top_state)
	states.add_child(_bottom_state)
	actions_box.add_child(states)
	column.add_child(actions)

	# Pie: velocidad, pausa, pantalla completa, ajustes.
	var footer := UIKit.hbox(8)
	_speed_button = UIKit.icon_text_button("player-track-next", "x1", UIKit.PANEL_LIGHT, 15, 18)
	_speed_button.custom_minimum_size = Vector2(0, 44)
	_speed_button.tooltip_text = "Velocidad de la jornada"
	_speed_button.pressed.connect(func() -> void: day.speed = 2.0 if day.speed == 1.0 else 1.0)
	footer.add_child(_speed_button)
	var pause := UIKit.round_icon_button("player-pause", "Pausa (Esc): congela la jornada, no la reinicia")
	pause.pressed.connect(_open_pause)
	footer.add_child(pause)
	footer.add_child(UIKit.spacer())
	var fullscreen := UIKit.round_icon_button("maximize", "Pantalla completa (F11)")
	fullscreen.pressed.connect(func() -> void: Screen.set_fullscreen(not Screen.is_fullscreen()))
	footer.add_child(fullscreen)
	var settings := UIKit.round_icon_button("settings", "Ajustes: volumen y salir al menú")
	settings.pressed.connect(_open_settings)
	footer.add_child(settings)
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

	# HUD: reloj e informe, arriba a la izquierda de la escena.
	var hud := UIKit.card()
	hud.anchor_left = 0.0
	hud.anchor_right = 0.0
	hud.offset_left = 20
	hud.offset_top = 20
	hud.offset_right = 20 + 360
	var hud_box := UIKit.vbox(6)
	hud.add_child(hud_box)
	var hud_top := UIKit.hbox(10)
	hud_top.add_child(UIKit.icon("clock", 20, UIKit.TEXT_DIM))
	_hud_clock = UIKit.bold("09:00", 28)
	hud_top.add_child(_hud_clock)
	hud_top.add_child(UIKit.spacer())
	_hud_left = UIKit.label("quedan 8 h", 12, UIKit.TEXT_DIM)
	_hud_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_top.add_child(_hud_left)
	hud_box.add_child(hud_top)
	var report_row := UIKit.hbox(8)
	report_row.add_child(UIKit.icon("file-text", 16, UIKit.GOLD))
	report_row.add_child(UIKit.label("Informe", 13, UIKit.TEXT_DIM))
	report_row.add_child(UIKit.spacer())
	_hud_report_label = UIKit.bold("0 %", 13, UIKit.GOLD)
	report_row.add_child(_hud_report_label)
	hud_box.add_child(report_row)
	_hud_report_bar = UIKit.bar(UIKit.GOLD, 8)
	hud_box.add_child(_hud_report_bar)
	var prod_row := UIKit.hbox(8)
	prod_row.add_child(UIKit.icon("briefcase", 16, UIKit.OK))
	prod_row.add_child(UIKit.label("Productividad", 13, UIKit.TEXT_DIM))
	prod_row.add_child(UIKit.spacer())
	_hud_pips = UIKit.hbox(3)
	for i: int in 10:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(14, 8)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_pips.add_child(pip)
	prod_row.add_child(_hud_pips)
	hud_box.add_child(prod_row)
	scene_holder.add_child(hud)

	# Estado de Candela (píldora bajo el HUD).
	_hud_state = UIKit.card(Color(0.09, 0.1, 0.14, 0.7), 999, 6)
	_hud_state.offset_left = 20
	_hud_state.offset_top = 150
	scene_holder.add_child(_hud_state)

	# Ficha del visitante, arriba a la derecha.
	_visitor_panel = UIKit.card()
	_visitor_panel.anchor_left = 1.0
	_visitor_panel.anchor_right = 1.0
	_visitor_panel.offset_left = -340
	_visitor_panel.offset_right = -20
	_visitor_panel.offset_top = 20
	_visitor_box = UIKit.vbox(8)
	_visitor_panel.add_child(_visitor_box)
	_visitor_panel.visible = false
	scene_holder.add_child(_visitor_panel)

	# Barra de diálogo del compañero, abajo.
	_dialogue = UIKit.card(Color(0.09, 0.1, 0.14, 0.88), 16, 12)
	_dialogue.anchor_left = 0.0
	_dialogue.anchor_right = 1.0
	_dialogue.anchor_top = 1.0
	_dialogue.anchor_bottom = 1.0
	_dialogue.offset_left = 20
	_dialogue.offset_right = -20
	_dialogue.offset_top = -104
	_dialogue.offset_bottom = -20
	var dialogue_row := UIKit.hbox(12)
	_dialogue_avatar = Control.new()
	_dialogue_avatar.custom_minimum_size = Vector2(56, 56)
	dialogue_row.add_child(_dialogue_avatar)
	var dialogue_col := UIKit.vbox(2)
	dialogue_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_name = UIKit.bold("", 14)
	dialogue_col.add_child(_dialogue_name)
	_dialogue_label = UIKit.label("", 21)
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_col.add_child(_dialogue_label)
	dialogue_row.add_child(dialogue_col)
	_dialogue.add_child(dialogue_row)
	_dialogue.modulate.a = 0.0
	scene_holder.add_child(_dialogue)

	# Aviso (píldora) centrado, por debajo del HUD y de la ficha para no taparlos.
	_toast = UIKit.card(Color(0.09, 0.1, 0.14, 0.9), 999, 8)
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_top = 190
	var toast_row := UIKit.hbox(8)
	_toast_icon = UIKit.icon("check", 18, UIKit.TEXT)
	toast_row.add_child(_toast_icon)
	_toast_label = UIKit.bold("", 15)
	toast_row.add_child(_toast_label)
	_toast.add_child(toast_row)
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
	_ring.offset_top = -215
	_ring.offset_bottom = -105
	_ring.offset_left = PANEL_WIDTH * 0.5 - 55
	_ring.offset_right = PANEL_WIDTH * 0.5 + 55
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)


# --- Refresco ----------------------------------------------------------------

func _refresh() -> void:
	var solo := day.visitor.is_empty()
	var exposed := not day.top_on or not day.bottom_on
	# Acción principal.
	var label := "Volver al informe"
	var icon := "briefcase"
	var hint := "Ella deja el portátil: el informe no avanza"
	if day.mode != Day.Mode.FUCK:
		icon = "heart"
		if solo:
			if exposed:
				label = "Tocarse · %s" % ("tetas" if not day.top_on and day.bottom_on else ("suave" if day.top_on else "a fondo"))
				hint = "Sola y desvestida: se toca y no trabaja"
			else:
				label = "Follar"
				hint = "Nadie en la mesa. Quítate algo o espera visita"
		else:
			label = "Dejar el informe · %s" % Day.act_label(day.current_act())
			hint = ("%s la está tocando mientras teclea" % Catalog.coworker(day.visitor["id"])["name"]) if day.is_touching() else "Sigue trabajando mientras él espera"
	_mode_button.text = label
	_mode_button.icon = load(UIKit.ICON_DIR + icon + ".svg")
	_mode_button.disabled = day.changing != "" or (solo and not exposed)
	_mode_hint.text = hint
	# Ropa: color y estado.
	for pair in [[_top_button, _top_state, day.top_on, day.changing == "top"], [_bottom_button, _bottom_state, day.bottom_on, day.changing == "bottom"]]:
		var b: Button = pair[0]
		var st: Label = pair[1]
		var tint: Color = UIKit.GOLD if pair[3] else (UIKit.TEXT if pair[2] else UIKit.TEXT_DIM)
		b.add_theme_color_override("icon_normal_color", tint)
		b.add_theme_color_override("icon_hover_color", tint)
		b.add_theme_color_override("font_color", tint)
		b.add_theme_color_override("font_hover_color", tint)
		st.text = "cambiando…" if pair[3] else ("puesta" if pair[2] else "quitada")
		st.add_theme_color_override("font_color", tint)
	_top_button.disabled = day.changing != ""
	_bottom_button.disabled = day.changing != ""
	_ring.visible = day.changing != ""
	if _ring.visible:
		_ring.set("progress", day.changing_progress())
		_ring.set("label", "%.1f" % day.changing_left)
		_ring.set("icon", "shirt" if day.changing == "top" else "hanger")
		_ring.queue_redraw()
	_speed_button.text = "x%d" % int(day.speed)
	_refresh_hud()
	_refresh_visitor()


func _refresh_hud() -> void:
	_hud_clock.text = Catalog.format_clock(day.clock)
	var left := day.minutes_left()
	_hud_left.text = "quedan %dh %02dm" % [int(left) / 60, int(left) % 60] if left >= 60.0 else "quedan %d min" % int(left)
	_hud_left.add_theme_color_override("font_color", UIKit.BAD if left < 60.0 and not day.finished else UIKit.TEXT_DIM)
	_hud_report_label.text = "%.0f %%" % day.report
	_hud_report_bar.value = day.report
	for i: int in 10:
		var pip: ColorRect = _hud_pips.get_child(i)
		if i >= int(day.productivity_cap()):
			pip.color = Color(UIKit.TEXT_DIM, 0.2)
		else:
			var lit := day.productivity >= i + 0.5
			pip.color = (UIKit.OK if day.productivity > 4.0 else UIKit.GOLD) if lit else Color(UIKit.BAD, 0.45)
	# Píldora de estado.
	var state := "Trabajando"
	var color := UIKit.OK
	if day.changing != "":
		state = "Cambiándose…"
		color = UIKit.GOLD
	elif day.climaxing != "":
		state = "…"
		color = UIKit.HEART
	elif day.is_distracted:
		state = "Tocándose · productividad 0"
		color = UIKit.HEART
	elif day.mode == Day.Mode.FUCK and not day.visitor.is_empty():
		state = "Follando · el informe espera"
		color = UIKit.HEART
	elif day.is_touching():
		state = "Trabajando mientras la tocan"
		color = UIKit.GOLD
	elif not day.pending_messages.is_empty():
		state = "%d mensaje%s sin contestar" % [day.pending_messages.size(), "" if day.pending_messages.size() == 1 else "s"]
		color = UIKit.GOLD
	if _hud_state.get_child_count() == 0 or (_hud_state.get_child(0) as Label).text != state:
		for child in _hud_state.get_children():
			child.queue_free()
		_hud_state.add_child(UIKit.bold(state, 12, color))


func _refresh_visitor() -> void:
	if day.visitor.is_empty():
		_visitor_id = ""
		_visitor_panel.visible = not day.queue.is_empty()
		if _visitor_panel.visible and (_visitor_box.get_child_count() == 0 or _visitor_box.get_meta("mode", "") != "queue"):
			_clear(_visitor_box)
			_visitor_box.set_meta("mode", "queue")
			var row := UIKit.hbox(8)
			row.add_child(UIKit.icon("hourglass", 18, UIKit.TEXT_DIM))
			row.add_child(UIKit.label("%s viene de camino…" % Catalog.coworker(day.queue[0])["name"], 15, UIKit.TEXT_DIM))
			_visitor_box.add_child(row)
		return
	_visitor_panel.visible = true
	var id: String = day.visitor["id"]
	var data := Catalog.coworker(id)
	if id != _visitor_id or _visitor_box.get_meta("mode", "") != "visitor":
		# Reconstruye la ficha solo al cambiar de visitante; los valores se actualizan cada frame.
		_visitor_id = id
		_clear(_visitor_box)
		_visitor_box.set_meta("mode", "visitor")
		var head := UIKit.hbox(10)
		head.add_child(UIKit.avatar(id, 44))
		var who := UIKit.vbox(0)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_child(UIKit.bold(data["name"], 20, Color.html(data["color"]).lightened(0.35)))
		var wants: Dictionary = data.get("wants", {})
		var wanted_act := Day.act_for(bool(wants.get("top", true)), bool(wants.get("bottom", true)))
		_visitor_wants = UIKit.label("quiere: %s" % Day.act_label(wanted_act), 13, UIKit.TEXT_DIM)
		who.add_child(_visitor_wants)
		head.add_child(who)
		_visitor_queue = UIKit.bold("", 12, UIKit.BAD)
		head.add_child(_visitor_queue)
		_visitor_box.add_child(head)
		var arousal_row := UIKit.hbox(8)
		arousal_row.add_child(UIKit.icon("flame", 16, UIKit.HEART))
		_visitor_arousal = UIKit.bar(UIKit.HEART, 10)
		arousal_row.add_child(_visitor_arousal)
		_visitor_box.add_child(arousal_row)
		var patience_row := UIKit.hbox(8)
		patience_row.add_child(UIKit.icon("hourglass", 16, UIKit.GOLD))
		_visitor_patience = UIKit.bar(UIKit.GOLD, 6)
		patience_row.add_child(_visitor_patience)
		_visitor_box.add_child(patience_row)
		_visitor_status = UIKit.label("", 12, UIKit.TEXT_DIM)
		_visitor_box.add_child(_visitor_status)
	_visitor_wants.add_theme_color_override("font_color", UIKit.OK if day.wants_met(data) else UIKit.TEXT_DIM)
	_visitor_queue.text = "+%d esperando" % day.queue.size() if not day.queue.is_empty() else ""
	_visitor_arousal.value = day.visitor["arousal"]
	var aggravated: bool = day.visitor.get("aggravated", false)
	_visitor_patience.value = clampf(1.0 - day.visitor["waited"] / float(data["patience"]), 0.0, 1.0) * 100.0
	(_visitor_patience.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = UIKit.BAD if aggravated else UIKit.GOLD
	var status := "¡impaciente!" if aggravated else ("disfrutando" if day.mode == Day.Mode.FUCK or day.is_touching() else "esperando")
	_visitor_status.text = "%d %% · %s" % [int(day.visitor["arousal"]), status]
	_visitor_status.add_theme_color_override("font_color", UIKit.BAD if aggravated else UIKit.TEXT_DIM)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# --- Feedback ----------------------------------------------------------------

func _on_line(who: String, text: String) -> void:
	if text == "":
		return
	var data := Catalog.coworker(who)
	_clear(_dialogue_avatar)
	_dialogue_avatar.add_child(UIKit.avatar(who, 56))
	_dialogue_name.text = data.get("name", who)
	_dialogue_name.add_theme_color_override("font_color", Color.html(data.get("color", "#ffffff")).lightened(0.35))
	_dialogue_label.text = text
	if _dialogue_tween:
		_dialogue_tween.kill()
	_dialogue_tween = create_tween()
	_dialogue_tween.tween_property(_dialogue, "modulate:a", 1.0, 0.15)
	_dialogue_tween.tween_interval(4.0)
	_dialogue_tween.tween_property(_dialogue, "modulate:a", 0.0, 0.5)


func _toast_show(text: String, color: Color, icon_name: String = "check") -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	var path := UIKit.ICON_DIR + icon_name + ".svg"
	_toast_icon.texture = load(path) if ResourceLoader.exists(path) else null
	_toast_icon.modulate = color
	_toast.reset_size()
	_toast.offset_left = -_toast.size.x * 0.5
	_toast.offset_right = _toast.size.x * 0.5
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.1)
	_toast_tween.tween_interval(2.4)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _flash_color(color: Color) -> void:
	_flash.color = color
	create_tween().tween_property(_flash, "color:a", 0.0, 0.5)


# --- Pausa y ajustes ---------------------------------------------------------

## Capa modal: congela el árbol (jornada, vídeo y sonido de escena) sin reiniciar nada.
## La música y los clics siguen (Sfx va en PROCESS_MODE_ALWAYS). Devuelve la caja donde poner el contenido.
func _open_overlay(min_width: float = 420.0) -> VBoxContainer:
	get_tree().paused = true
	_overlay_node = Control.new()
	_overlay_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_node.add_child(veil)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_node.add_child(center)
	var card := UIKit.panel(UIKit.PANEL, 20, 28)
	var box := UIKit.vbox(12)
	box.custom_minimum_size = Vector2(min_width, 0)
	card.add_child(box)
	center.add_child(card)
	add_child(_overlay_node)
	return box


func _close_overlay() -> void:
	if _overlay_node:
		_overlay_node.queue_free()
		_overlay_node = null
	get_tree().paused = false


## Pausa: solo congela. "Seguir" retoma exactamente donde estaba.
func _open_pause() -> void:
	if _overlay_node or day.finished:
		return
	var box := _open_overlay(380.0)
	var head := UIKit.hbox(10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(UIKit.icon("player-pause", 30, UIKit.TEXT))
	head.add_child(UIKit.title("Pausa", 36))
	box.add_child(head)
	box.add_child(UIKit.title("%s · informe %.0f %% · %d atendidos" % [Catalog.format_clock(day.clock), day.report, day.satisfied_count], 14))
	var resume := UIKit.icon_text_button("player-play", "Seguir", UIKit.PRIMARY, 22, 24)
	resume.pressed.connect(_close_overlay)
	box.add_child(resume)


## Ajustes: volúmenes, pantalla completa y abandonar la jornada (con aviso).
func _open_settings() -> void:
	if _overlay_node:
		return
	var box := _open_overlay(440.0)
	var head := UIKit.hbox(10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(UIKit.icon("settings", 30, UIKit.TEXT))
	head.add_child(UIKit.title("Ajustes", 36))
	box.add_child(head)
	for pair in [["Escena", Sfx.scene_volume, Sfx.set_scene_volume], ["Interfaz", Sfx.ui_volume, Sfx.set_ui_volume], ["Música", Sfx.music_volume, Sfx.set_music_volume]]:
		var row := UIKit.hbox(10)
		var name := UIKit.label(pair[0], 14, UIKit.TEXT_DIM)
		name.custom_minimum_size = Vector2(80, 0)
		row.add_child(name)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = pair[1]
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(0, 24)
		slider.value_changed.connect(func(v: float) -> void: (pair[2] as Callable).call(v))
		row.add_child(slider)
		box.add_child(row)
	var fullscreen := UIKit.icon_text_button("maximize", "Pantalla completa (F11)", UIKit.PANEL_LIGHT, 16)
	fullscreen.pressed.connect(func() -> void: Screen.set_fullscreen(not Screen.is_fullscreen()))
	box.add_child(fullscreen)
	var back := UIKit.icon_text_button("player-play", "Volver a la jornada", UIKit.PRIMARY, 20, 22)
	back.pressed.connect(_close_overlay)
	box.add_child(back)
	var quit := UIKit.button("Abandonar la jornada", UIKit.PANEL_LIGHT, 16)
	quit.pressed.connect(func() -> void:
		_close_overlay()
		_confirm_quit())
	box.add_child(quit)


func _confirm_quit() -> void:
	var box := _open_overlay(420.0)
	box.add_child(UIKit.title("¿Abandonar la jornada?", 30))
	box.add_child(UIKit.title("Se pierde el progreso de hoy (informe %.0f %%)." % day.report, 14))
	var stay := UIKit.button("Seguir jugando", UIKit.PRIMARY)
	stay.pressed.connect(_close_overlay)
	box.add_child(stay)
	var quit := UIKit.button("Salir al menú", UIKit.PANEL_LIGHT)
	quit.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	box.add_child(quit)


# --- Fin de jornada ----------------------------------------------------------

func _on_day_ended(won: bool, stars: int) -> void:
	Sfx.play("bell")
	get_tree().create_timer(0.9).timeout.connect(func() -> void: Sfx.play("reward" if won else "fail"))
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.75)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(veil)
	# Ilustración del final (assets/scenes/<nivel>/end_win.png / end_lose.png): splash art.
	var end_path := "res://assets/scenes/%s/%s.png" % [level_id, "end_win" if won else "end_lose"]
	var has_art := ResourceLoader.exists(end_path)
	if has_art:
		var art := TextureRect.new()
		art.texture = load(end_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.modulate.a = 0.0
		overlay.add_child(art)
		create_tween().tween_property(art, "modulate:a", 1.0, 0.8)
		veil.color = Color(0, 0, 0, 0.25)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if has_art:
		center.anchor_top = 0.45
	overlay.add_child(center)
	var card := UIKit.panel(Color(UIKit.PANEL, 0.92), 20, 28)
	var box := UIKit.vbox(12)
	box.custom_minimum_size = Vector2(560, 0)
	card.add_child(box)
	box.add_child(UIKit.title("Informe entregado" if won else "Se acabó la jornada", 40))
	box.add_child(UIKit.stars(stars, 3, 44))
	box.add_child(UIKit.title("Informe %.0f %% · %d compañeros atendidos · %d cabreados" % [day.report, day.satisfied_count, day.aggravated_count], 18))
	if won:
		var reward := UIKit.hbox(6)
		reward.alignment = BoxContainer.ALIGNMENT_CENTER
		reward.add_child(UIKit.icon("heart-filled", 22, UIKit.HEART))
		reward.add_child(UIKit.bold("+%d corazones" % (10 * stars), 22, UIKit.HEART))
		box.add_child(reward)
	var buttons := UIKit.hbox(10)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	var again := UIKit.icon_text_button("player-play", "Otra jornada", UIKit.PRIMARY, 20, 22)
	again.pressed.connect(func() -> void: get_tree().reload_current_scene())
	buttons.add_child(again)
	var menu := UIKit.button("Menú", UIKit.PANEL_LIGHT)
	menu.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	buttons.add_child(menu)
	box.add_child(buttons)
	center.add_child(card)
	add_child(overlay)

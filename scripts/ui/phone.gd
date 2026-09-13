extends Control
class_name Phone
## El teléfono de Candela: una app de mensajería estilo WhatsApp con lista de chats, fotos de
## perfil, hilos con burbujas, respuestas rápidas y notificaciones. Arriba, el widget de trabajo
## (hora, informe, productividad). Toda la lógica está en Day; aquí solo se muestra y se manda.

signal reply_chosen(message: Dictionary, option: Dictionary)

const BG := Color("#0b141a")
const HEADER := Color("#202c33")
const BUBBLE_IN := Color("#202c33")
const BUBBLE_OUT := Color("#005c4b")
const ACCENT := Color("#00a884")
const TEXT := Color("#e9edef")
const DIM := Color("#8696a0")

var day: Day
## Hilos por remitente: lista de {text, mine, time}.
var _threads: Dictionary = {}
var _last_time: Dictionary = {}
var _open_chat: String = ""

var _clock: Label
var _report_bar: ProgressBar
var _report_label: Label
var _pips: HBoxContainer
var _header: PanelContainer
var _header_box: HBoxContainer
var _body: ScrollContainer
var _list: VBoxContainer
var _footer: PanelContainer
var _banner: PanelContainer
var _banner_tween: Tween
var _dirty := true


func bind(day_node: Day) -> void:
	day = day_node
	day.message_received.connect(_on_message)
	_build()


var _last_can_answer := true


func _process(_delta: float) -> void:
	if day and day.can_answer() != _last_can_answer:
		_last_can_answer = day.can_answer()
		_dirty = true
	if day == null:
		return
	_clock.text = Catalog.format_clock(day.clock)
	_report_label.text = "Informe %.0f %%" % day.report
	_report_bar.value = day.report
	for i: int in 10:
		var pip: ColorRect = _pips.get_child(i)
		if i >= int(day.productivity_cap()):
			pip.color = Color(DIM, 0.25)
		else:
			var lit := day.productivity >= i + 0.5
			pip.color = (ACCENT if day.productivity > 4.0 else UIKit.GOLD) if lit else Color(UIKit.BAD, 0.55)
	if _dirty:
		_dirty = false
		_render()


# --- Construcción ---------------------------------------------------------------------

func _build() -> void:
	# Carcasa.
	var bezel := UIKit.panel(Color("#0d0d10"), 40, 12)
	bezel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bezel)
	var screen := UIKit.panel(BG, 30, 0)
	bezel.add_child(screen)
	var column := UIKit.vbox(0)
	screen.add_child(column)

	# Barra de estado + widget de trabajo.
	var status := UIKit.panel(BG, 0, 10)
	var status_box := UIKit.vbox(6)
	status.add_child(status_box)
	var top := UIKit.hbox(8)
	_clock = UIKit.label("09:00", 22, TEXT)
	top.add_child(_clock)
	top.add_child(UIKit.spacer())
	top.add_child(UIKit.icon("signal-4g", 18, DIM))
	top.add_child(UIKit.icon("wifi", 18, DIM))
	top.add_child(UIKit.icon("battery-3", 18, DIM))
	_report_label = UIKit.label("Informe 0 %", 16, UIKit.GOLD)
	_report_label.visible = false
	top.add_child(_report_label)
	status_box.add_child(top)
	_report_bar = _bar(UIKit.GOLD, 8)
	_report_bar.visible = false
	status_box.add_child(_report_bar)
	# El informe y la productividad viven ahora en el HUD sobre la escena; el móvil es solo móvil.
	var prod := UIKit.hbox(6)
	prod.visible = false
	prod.add_child(UIKit.label("Productividad", 13, DIM))
	prod.add_child(UIKit.spacer())
	_pips = UIKit.hbox(3)
	for i: int in 10:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 10)
		_pips.add_child(pip)
	prod.add_child(_pips)
	status_box.add_child(prod)
	column.add_child(status)

	# Cabecera de la app.
	_header = UIKit.panel(HEADER, 0, 10)
	_header_box = UIKit.hbox(10)
	_header.add_child(_header_box)
	column.add_child(_header)

	# Cuerpo.
	_body = ScrollContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list = UIKit.vbox(0)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_list)
	column.add_child(_body)

	# Pie (respuestas rápidas o caja de texto).
	_footer = UIKit.panel(HEADER, 0, 8)
	column.add_child(_footer)

	# Notificación (encima de todo, dentro de la pantalla).
	_banner = UIKit.panel(Color("#2a3942"), 14, 10)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.offset_left = 22
	_banner.offset_right = -22
	_banner.offset_top = -110
	_banner.offset_bottom = -30
	_banner.modulate.a = 0.0
	add_child(_banner)


func _bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false
	bar.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(DIM, 0.25)
	bg.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


# --- Mensajes -------------------------------------------------------------------------

func _on_message(message: Dictionary) -> void:
	var from: String = message["from"]
	var time := Catalog.format_clock(day.clock)
	_threads[from] = _threads.get(from, []) + [{"text": message["text"], "mine": false, "time": time}]
	_last_time[from] = time
	if _open_chat == "":
		# Desde la lista, el teléfono salta directamente al chat que acaba de sonar.
		_open_chat = from
	elif _open_chat != from:
		_notify(from, message["text"])
	_dirty = true
	Metrics.track("phone_message", {"from": from, "open": _open_chat == from})


func _choose(message: Dictionary, option: Dictionary) -> void:
	if not day.can_answer():
		_dirty = true
		return
	var from: String = message["from"]
	var time := Catalog.format_clock(day.clock)
	_threads[from] = _threads.get(from, []) + [{"text": option["label"], "mine": true, "time": time}]
	_last_time[from] = time
	reply_chosen.emit(message, option)
	_dirty = true


func _pending_for(from: String) -> Array:
	return day.pending_messages.filter(func(m: Dictionary) -> bool: return m["from"] == from)


func _open(from: String) -> void:
	_open_chat = from
	_hide_banner()
	_dirty = true
	Metrics.track("phone_open_chat", {"from": from})


func _back() -> void:
	_open_chat = ""
	_dirty = true


# --- Render ---------------------------------------------------------------------------

func _render() -> void:
	for child in _header_box.get_children():
		child.queue_free()
	for child in _list.get_children():
		child.queue_free()
	for child in _footer.get_children():
		child.queue_free()
	if _open_chat == "":
		_render_list()
	else:
		_render_thread(_open_chat)


func _contacts() -> Array:
	# Todos los compañeros y el jefe; primero los que tienen actividad más reciente.
	var ids: Array = Catalog.coworkers.keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ta: String = _last_time.get(a, "")
		var tb: String = _last_time.get(b, "")
		if ta == tb:
			return a < b
		return ta > tb)
	return ids


func _render_list() -> void:
	_header_box.add_child(UIKit.label("Chats", 24, TEXT))
	_header_box.add_child(UIKit.spacer())
	_header_box.add_child(UIKit.flat_icon_button("camera", 20, DIM))
	_header_box.add_child(UIKit.flat_icon_button("search", 20, DIM))
	_header_box.add_child(UIKit.avatar("candela", 34))
	for id: String in _contacts():
		var data := Catalog.coworker(id)
		var thread: Array = _threads.get(id, [])
		var unread := _pending_for(id).size()
		var row := Button.new()
		row.flat = true
		row.custom_minimum_size = Vector2(0, 76)
		row.pressed.connect(_open.bind(id))
		var hbox := UIKit.hbox(12)
		hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(UIKit.avatar(id, 54))
		var text := UIKit.vbox(2)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		var name_row := UIKit.hbox(6)
		name_row.add_child(UIKit.label(data.get("name", id), 19, TEXT))
		name_row.add_child(UIKit.spacer())
		name_row.add_child(UIKit.label(_last_time.get(id, ""), 13, ACCENT if unread > 0 else DIM))
		text.add_child(name_row)
		var preview_row := UIKit.hbox(6)
		var last: String = thread[-1]["text"] if not thread.is_empty() else "Toca para escribir"
		if not thread.is_empty() and thread[-1]["mine"]:
			preview_row.add_child(UIKit.icon("checks", 15, ACCENT))
		var preview := UIKit.label(last, 15, DIM)
		preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preview_row.add_child(preview)
		if unread > 0:
			var badge := UIKit.label(str(unread), 13, BG)
			badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			badge.custom_minimum_size = Vector2(24, 24)
			var style := StyleBoxFlat.new()
			style.bg_color = ACCENT
			style.set_corner_radius_all(12)
			badge.add_theme_stylebox_override("normal", style)
			preview_row.add_child(badge)
		text.add_child(preview_row)
		hbox.add_child(text)
		row.add_child(hbox)
		_list.add_child(row)
		var sep := ColorRect.new()
		sep.color = Color(DIM, 0.15)
		sep.custom_minimum_size = Vector2(0, 1)
		_list.add_child(sep)
	var hint_row := UIKit.hbox(4)
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_row.add_child(UIKit.icon("lock", 11, DIM))
	hint_row.add_child(UIKit.label("Tus mensajes personales están cifrados de extremo a extremo", 11, DIM))
	_list.add_child(hint_row)
	var fake := UIKit.label("", 1)
	_footer.add_child(fake)


func _render_thread(from: String) -> void:
	var data := Catalog.coworker(from)
	var back := UIKit.flat_icon_button("arrow-left", 22, TEXT)
	back.pressed.connect(_back)
	_header_box.add_child(back)
	_header_box.add_child(UIKit.avatar(from, 40))
	var who := UIKit.vbox(0)
	who.add_child(UIKit.label(data.get("name", from), 19, TEXT))
	var status := "escribiendo…" if not _pending_for(from).is_empty() else ("en tu mesa" if day.visitor.get("id", "") == from else "en línea")
	who.add_child(UIKit.label(status, 12, ACCENT if status != "en línea" else DIM))
	_header_box.add_child(who)
	_header_box.add_child(UIKit.spacer())
	_header_box.add_child(UIKit.flat_icon_button("phone", 20, DIM))
	_header_box.add_child(UIKit.flat_icon_button("dots-vertical", 20, DIM))

	var thread: Array = _threads.get(from, [])
	var bubbles := UIKit.vbox(6)
	bubbles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.add_child(bubbles)
	_list.add_child(pad)
	var day_tag := UIKit.label("HOY", 11, DIM)
	day_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubbles.add_child(day_tag)
	for entry in thread:
		bubbles.add_child(_bubble(entry))

	# Respuestas rápidas del mensaje pendiente más antiguo; si no hay, la caja de texto.
	var pending := _pending_for(from)
	if pending.is_empty():
		var input := UIKit.hbox(8)
		var box := UIKit.panel(Color("#2a3942"), 20, 8)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(UIKit.label("Escribe un mensaje", 15, DIM))
		input.add_child(box)
		input.add_child(UIKit.icon("microphone", 22, DIM))
		_footer.add_child(input)
	else:
		var message: Dictionary = pending[0]
		var options := UIKit.vbox(6)
		var can := day.can_answer()
		if not can:
			var why := "Deja de tocarte para contestar" if day.is_distracted else ("Espera a terminar de cambiarte" if day.changing != "" else "Vuelve a Trabajar para contestar")
			var hint := UIKit.label(why, 12, UIKit.GOLD)
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			options.add_child(hint)
		for option in message.get("options", []):
			var reject: bool = option.get("effects", {}).get("reject", false)
			var chip := UIKit.button(option["label"], UIKit.BAD.darkened(0.35) if reject else ACCENT.darkened(0.25), 16)
			chip.custom_minimum_size = Vector2(0, 42)
			chip.disabled = not can
			chip.pressed.connect(_choose.bind(message, option))
			options.add_child(chip)
		_footer.add_child(options)
	await get_tree().process_frame
	_body.scroll_vertical = int(_list.size.y)


func _bubble(entry: Dictionary) -> Control:
	var row := UIKit.hbox(0)
	var panel := UIKit.panel(BUBBLE_OUT if entry["mine"] else BUBBLE_IN, 10, 10)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END if entry["mine"] else Control.SIZE_SHRINK_BEGIN
	panel.custom_minimum_size = Vector2(0, 0)
	var box := UIKit.vbox(2)
	var text := UIKit.label(entry["text"], 16, TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(minf(320.0, entry["text"].length() * 9.0 + 24.0), 0)
	box.add_child(text)
	var meta_row := UIKit.hbox(4)
	meta_row.alignment = BoxContainer.ALIGNMENT_END
	meta_row.add_child(UIKit.label(entry["time"], 11, ACCENT.lightened(0.3) if entry["mine"] else DIM))
	if entry["mine"]:
		meta_row.add_child(UIKit.icon("checks", 13, ACCENT.lightened(0.3)))
	box.add_child(meta_row)
	panel.add_child(box)
	if entry["mine"]:
		row.add_child(UIKit.spacer())
		row.add_child(panel)
	else:
		row.add_child(panel)
		row.add_child(UIKit.spacer())
	return row


# --- Notificaciones -------------------------------------------------------------------

func _notify(from: String, text: String) -> void:
	for child in _banner.get_children():
		child.queue_free()
	var data := Catalog.coworker(from)
	var hbox := UIKit.hbox(10)
	hbox.add_child(UIKit.avatar(from, 40))
	var body := UIKit.vbox(0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(UIKit.label(data.get("name", from), 15, TEXT))
	var preview := UIKit.label(text, 13, DIM)
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.add_child(preview)
	hbox.add_child(body)
	hbox.add_child(UIKit.label("ahora", 11, DIM))
	_banner.add_child(hbox)
	var tap := Button.new()
	tap.flat = true
	tap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap.pressed.connect(_open.bind(from))
	_banner.add_child(tap)
	if _banner_tween:
		_banner_tween.kill()
	_banner.offset_top = -110
	_banner.offset_bottom = -30
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.15)
	_banner_tween.parallel().tween_property(_banner, "offset_top", 96.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.parallel().tween_property(_banner, "offset_bottom", 176.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(4.0)
	_banner_tween.tween_callback(_hide_banner)
	Metrics.track("phone_notification", {"from": from})


func _hide_banner() -> void:
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.2)
	_banner_tween.parallel().tween_property(_banner, "offset_top", -110.0, 0.2)
	_banner_tween.parallel().tween_property(_banner, "offset_bottom", -30.0, 0.2)

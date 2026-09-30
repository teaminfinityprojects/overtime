class_name Ads
## Publicidad del patrocinador. Por idioma (data/ads.json, ya resuelto por Catalog): en español amateur.tv y
## en inglés sugarcams, la misma red (regla de la skill infinity:amateur-cams). Aquí, la tarjeta y el banner con el
## estilo del juego, el avatar del chat patrocinado del móvil y la apertura del enlace con sus métricas.
## Con "url" vacío en el JSON no se muestra ningún anuncio.
## Variantes de banner: "variant" fija una; vacío = una al azar por sesión (test A/B), que va en las métricas.

## Id del chat patrocinado en el móvil (no es un compañero: no está en coworkers.json).
const ID := "sponsor"
const LIVE := Color("#ef2b4a")
## offer_slug de cada ubicación en Landing Metrics (con el prefijo de destino: amateur:banner-menu…).
const SLUGS := {"menu": "banner-menu", "end_win": "banner-end-win", "end_lose": "banner-end-lose", "phone": "phone-chat"}

static var _variant := ""


static func enabled() -> bool:
	return String(Catalog.ads.get("url", "")) != ""


static func config(placement: String) -> Dictionary:
	return Catalog.ads.get(placement, {})


## Variante de banner de esta sesión: la fijada en el JSON o una al azar, la misma en todas las pantallas.
static func variant() -> String:
	if _variant == "":
		var fixed: String = Catalog.ads.get("variant", "")
		var options: Array = Catalog.ads.get("banners", {}).keys()
		_variant = fixed if fixed != "" or options.is_empty() else String(options.pick_random())
	return _variant


static func sponsor() -> String:
	return Catalog.ads.get("sponsor", "amateur.tv")


## Plataforma de destino para el prefijo del offer_slug: "amateur" (es) o "sugarcams" (en).
static func destination() -> String:
	return Catalog.ads.get("destination", "amateur")


## Enlace de salida: los params del visitante (utm_*, a, gclid…) mandan; donde falten, los del JSON
## ("tracking") y la ubicación en utm_content; sin utm_source, el dominio del juego.
static func url(placement: String) -> String:
	var defaults: Dictionary = Catalog.ads.get("tracking", {}).duplicate()
	defaults["utm_content"] = SLUGS.get(placement, placement)
	return Metrics.outbound_url(Catalog.ads.get("url", ""), defaults)


## En web abre una pestaña nueva; se llama desde un clic, así que el navegador no la bloquea.
static func open(placement: String) -> void:
	Metrics.outbound(destination(), SLUGS.get(placement, placement), {"action": "ad", "variant": variant(), "lang": L10n.lang})
	Metrics.open_url(url(placement))


static func impression(placement: String) -> void:
	Metrics.track("ad_impression", {"placement": placement, "variant": variant(), "lang": L10n.lang})


## Tarjeta de anuncio. Normal: cabecera, titular, texto y botón. `compact`: una fila (titular + botón),
## para pantallas que ya van llenas como el fin de jornada.
static func card(placement: String, compact: bool = false) -> PanelContainer:
	var data := config(placement)
	var node := UIKit.panel(Color(UIKit.BG, 0.95), 14, 12 if compact else 14)
	var style: StyleBoxFlat = node.get_theme_stylebox("panel")
	style.border_width_left = 3
	style.border_color = LIVE
	var cta := UIKit.icon_text_button("external-link", data.get("cta", L10n.t("Ver")), LIVE, 16, 18)
	cta.custom_minimum_size = Vector2(0, 44)
	cta.pressed.connect(func() -> void: open(placement))
	var head := UIKit.hbox(8)
	head.add_child(live_pill())
	head.add_child(UIKit.label(L10n.t("Publicidad · %s") % sponsor(), 11, UIKit.TEXT_DIM))
	var title := UIKit.bold(data.get("title", ""), 16 if compact else 18)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if compact:
		var row := UIKit.hbox(12)
		var text := UIKit.vbox(4)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_child(head)
		text.add_child(title)
		row.add_child(text)
		cta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cta)
		node.add_child(row)
	else:
		var box := UIKit.vbox(8)
		box.add_child(head)
		box.add_child(title)
		var body := UIKit.label(data.get("text", ""), 13, UIKit.TEXT_DIM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(body)
		box.add_child(cta)
		node.add_child(box)
	impression(placement)
	return node


## Banner de imagen (assets/ads, generado con tools/ad_banner.py) de la variante de la sesión, clicable,
## con la etiqueta "Publicidad" encima. Sin imagen para esa ubicación, cae a la tarjeta de texto.
static func banner(placement: String, width: float) -> Control:
	var path: String = Catalog.ads.get("banners", {}).get(variant(), {}).get(placement, "")
	if path == "" or not ResourceLoader.exists(path):
		return card(placement, placement != "menu")
	var texture: Texture2D = load(path)
	var node := TextureButton.new()
	node.texture_normal = texture
	node.ignore_texture_size = true
	node.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	node.custom_minimum_size = Vector2(width, roundf(width * texture.get_height() / texture.get_width()))
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.tooltip_text = L10n.t("Publicidad · %s") % sponsor()
	node.mouse_entered.connect(func() -> void: node.modulate = Color(1.12, 1.12, 1.12))
	node.mouse_exited.connect(func() -> void: node.modulate = Color.WHITE)
	node.pressed.connect(func() -> void:
		Sfx.play("click")
		open(placement))
	var tag := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6
	style.content_margin_right = 6
	tag.add_theme_stylebox_override("panel", style)
	tag.add_child(UIKit.label(L10n.t("Publicidad"), 10, Color(1, 1, 1, 0.7)))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.anchor_left = 1.0
	tag.anchor_right = 1.0
	tag.offset_top = 6
	tag.offset_right = -6
	tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	node.add_child(tag)
	impression(placement)
	return node


## Píldora roja "EN DIRECTO" con el icono de emisión.
static func live_pill() -> PanelContainer:
	var node := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = LIVE
	style.set_corner_radius_all(999)
	style.content_margin_left = 8
	style.content_margin_right = 10
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	node.add_theme_stylebox_override("panel", style)
	var row := UIKit.hbox(4)
	row.add_child(UIKit.icon("broadcast", 13, UIKit.TEXT))
	row.add_child(UIKit.bold(L10n.t("EN DIRECTO"), 11))
	node.add_child(row)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Foto de perfil del chat patrocinado: círculo rojo con el icono de emisión.
static func avatar(size: float) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# En filas más altas que el avatar (la notificación) no debe estirarse; y el círculo se centra en el
	# tamaño real, igual que el icono del CenterContainer.
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.draw.connect(func() -> void: holder.draw_circle(holder.size * 0.5, size * 0.5, LIVE))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(UIKit.icon("broadcast", size * 0.55, UIKit.TEXT))
	holder.add_child(center)
	return holder

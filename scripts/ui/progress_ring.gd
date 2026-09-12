extends Control
## Anillo de progreso con icono (Tabler) y texto en el centro (transición de ropa).

var progress: float = 0.0
var label: String = ""
var icon: String = ""
var _icon_tex: Texture2D
var _icon_name: String = ""


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	draw_arc(center, radius, 0.0, TAU, 64, Color(0, 0, 0, 0.5), 12.0)
	draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 64, UIKit.PRIMARY, 12.0)
	if icon != _icon_name:
		_icon_name = icon
		var path := UIKit.ICON_DIR + icon + ".svg"
		_icon_tex = load(path) if ResourceLoader.exists(path) else null
	if _icon_tex:
		var s := radius * 0.9
		draw_texture_rect(_icon_tex, Rect2(center - Vector2(s * 0.5, s * 0.75), Vector2(s, s)), false, UIKit.TEXT)
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius, radius * 0.75), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 20, UIKit.TEXT)

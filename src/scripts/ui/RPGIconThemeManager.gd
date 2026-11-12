extends RefCounted
## Central visual theme for the classic RPG HUD and dynamically created menu buttons.
const GOLD := Color("#c99b4d")
const GOLD_HI := Color("#f3d58a")
const PANEL := Color(0.035, 0.045, 0.06, 0.94)
const ICON_ROOT := "res://assets/ui/icons/"

static func apply_to_tree(root: Node) -> void:
	for node in root.find_children("*", "Button", true, false):
		style_button(node as Button, str((node as Button).get_meta("rpg_icon", "")))

static func style_button(button: Button, icon_key: String = "") -> void:
	if not is_instance_valid(button):
		return
	button.add_theme_color_override("font_color", GOLD_HI)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD_HI)
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.46, 0.42, 0.72))
	button.add_theme_stylebox_override("normal", _box(PANEL, GOLD, 1, 7))
	button.add_theme_stylebox_override("hover", _box(Color(0.12, 0.095, 0.055, 0.98), GOLD_HI, 2, 7))
	button.add_theme_stylebox_override("pressed", _box(Color(0.02, 0.025, 0.035, 1.0), Color("#ffe5a6"), 2, 7))
	button.add_theme_stylebox_override("disabled", _box(Color(0.025, 0.03, 0.04, 0.82), Color(0.3, 0.27, 0.21, 0.7), 1, 7))
	if not icon_key.is_empty():
		var path := ICON_ROOT + icon_key + ".png"
		if ResourceLoader.exists(path):
			button.icon = load(path) as Texture2D
			button.expand_icon = true

static func frame_style() -> StyleBoxFlat:
	return _box(PANEL, GOLD, 1, 8)

static func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

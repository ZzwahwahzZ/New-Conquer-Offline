extends RefCounted
## Central RPG UI theme and asset lookup for the Kenney CC0 sprite library.
const GOLD := Color("#c99b4d")
const GOLD_HI := Color("#f3d58a")
const PANEL := Color(0.035, 0.045, 0.06, 0.94)
const UI_ROOT := "res://assets/ui/"

static func apply_to_tree(root: Node) -> void:
	for node in root.find_children("*", "Button", true, false):
		style_button(node as Button, str((node as Button).get_meta("rpg_icon", "")))

static func find_texture(category: String, hint: String = "") -> Texture2D:
	return _find_texture_recursive(UI_ROOT + category, hint.to_lower())

static func _find_texture_recursive(directory_path: String, hint: String) -> Texture2D:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return null
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		var lower := file_name.to_lower()
		if not (lower.ends_with(".png") or lower.ends_with(".svg") or lower.ends_with(".webp")):
			continue
		if hint.is_empty() or lower.contains(hint) or (directory_path + "/" + file_name).to_lower().contains(hint):
			var texture := load(directory_path + "/" + file_name) as Texture2D
			if texture != null:
				return texture
	var subdirectories := directory.get_directories()
	subdirectories.sort()
	for subdirectory in subdirectories:
		var texture := _find_texture_recursive(directory_path + "/" + subdirectory, hint)
		if texture != null:
			return texture
	return null

static func make_nine_patch(texture: Texture2D, margins: int = 14) -> NinePatchRect:
	if texture == null:
		return null
	var patch := NinePatchRect.new()
	patch.texture = texture
	patch.patch_margin_left = margins
	patch.patch_margin_top = margins
	patch.patch_margin_right = margins
	patch.patch_margin_bottom = margins
	patch.draw_center = true
	patch.modulate = Color("#d7b16a")
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return patch

static func frame_style() -> StyleBox:
	var texture := find_texture("frames", "brown")
	if texture == null:
		texture = find_texture("frames", "gold")
	if texture == null:
		texture = find_texture("frames", "panel")
	if texture == null:
		texture = find_texture("frames", "frame")
	if texture != null:
		var box := StyleBoxTexture.new()
		box.texture = texture
		box.texture_margin_left = 14
		box.texture_margin_top = 14
		box.texture_margin_right = 14
		box.texture_margin_bottom = 14
		box.modulate_color = Color(1.0, 0.94, 0.82, 1.0)
		return box
	return _box(PANEL, GOLD, 1, 8)

static func frame_underlay_style() -> StyleBoxFlat:
	return _box(Color("#24180f"), Color("#9f773d"), 2, 8)

static func make_orb_material(shader: Shader, tint: Color) -> ShaderMaterial:
	if shader == null:
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("orb_color", tint)
	material.set_shader_parameter("glow_strength", 0.48)
	return material

static func orb_well_style() -> StyleBoxFlat:
	var style := _box(Color(0.018, 0.023, 0.035, 0.98), Color("#8b6a36"), 1, 22)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 2)
	return style

static func style_button(button: Button, icon_key: String = "") -> void:
	if not is_instance_valid(button):
		return
	button.add_theme_color_override("font_color", GOLD_HI)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD_HI)
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.46, 0.42, 0.72))
	var normal_texture := find_texture("buttons", "button_rectangle_depth_border")
	if normal_texture == null:
		normal_texture = find_texture("buttons", "button_round_depth_border")
	var hover_texture := find_texture("buttons", "button_rectangle_depth_flat")
	var pressed_texture := find_texture("buttons", "button_square_depth_border")
	button.add_theme_stylebox_override("normal", _texture_box(normal_texture) if normal_texture != null else _box(PANEL, GOLD, 1, 7))
	button.add_theme_stylebox_override("hover", _texture_box(hover_texture) if hover_texture != null else _box(Color(0.12, 0.095, 0.055, 0.98), GOLD_HI, 2, 7))
	button.add_theme_stylebox_override("pressed", _texture_box(pressed_texture) if pressed_texture != null else _box(Color(0.02, 0.025, 0.035, 1.0), Color("#ffe5a6"), 2, 7))
	button.add_theme_stylebox_override("disabled", _box(Color(0.025, 0.03, 0.04, 0.82), Color(0.3, 0.27, 0.21, 0.7), 1, 7))
	if not icon_key.is_empty():
		var icon := find_texture("icons", icon_key)
		if icon != null:
			button.icon = icon
			button.expand_icon = true

static func _texture_box(texture: Texture2D) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = 8
	box.texture_margin_top = 8
	box.texture_margin_right = 8
	box.texture_margin_bottom = 8
	return box

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

extends RefCounted
## Central RPG UI theme and asset lookup for the Kenney CC0 sprite library.
const GOLD := Color("#D4AF37")
const GOLD_HI := Color("#FFE6A0")
const PANEL := Color(0.08, 0.06, 0.05, 0.94)
const UI_ROOT := "res://assets/ui/"

static func apply_to_tree(root: Node) -> void:
	var arabic_font := load("res://assets/ui/fonts/NotoSansArabic[wght].ttf") as Font
	if arabic_font == null:
		arabic_font = load("res://assets/ui/fonts/NotoSansArabic-Regular.ttf") as Font
	var ui_theme: Theme = null
	if arabic_font != null:
		ui_theme = Theme.new()
		ui_theme.default_font = arabic_font
	var scene_root := root.get_tree().current_scene
	var scope: Node = scene_root if scene_root != null else root
	if scope is Control:
		(scope as Control).layout_direction = Control.LAYOUT_DIRECTION_RTL
		if ui_theme != null:
			(scope as Control).theme = ui_theme
	for node in scope.find_children("*", "Control", true, false):
		var control := node as Control
		control.layout_direction = Control.LAYOUT_DIRECTION_RTL
		if ui_theme != null and control.theme == null:
			control.theme = ui_theme
	for node in scope.find_children("*", "Button", true, false):
		style_button(node as Button, str((node as Button).get_meta("rpg_icon", "")))
	# Preserve the bottom HUD's classic left-to-right composition inside the Arabic RTL scene.
	var main_row := scope.find_child("MainRow", true, false)
	if is_instance_valid(main_row) and main_row is Control:
		(main_row as Control).layout_direction = Control.LAYOUT_DIRECTION_LTR
	for node in scope.find_children("*", "HBoxContainer", true, false):
		if str(node.name).begins_with("EquipmentRow_"):
			(node as Control).layout_direction = Control.LAYOUT_DIRECTION_LTR
	# Apply the shared engraved frame to static and dynamically-created panel surfaces.
	var ornate := frame_style()
	for node in scope.find_children("*", "PanelContainer", true, false):
		(node as PanelContainer).add_theme_stylebox_override("panel", ornate)
	for node in scope.find_children("*", "Panel", true, false):
		if node.name in ["DarkBrownUnderlay", "GoldEngravedOrbRim"]:
			continue
		(node as Panel).add_theme_stylebox_override("panel", ornate)
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

static func ornate_frame_texture() -> Texture2D:
	var texture := load("res://assets/ui/frames/ornate_gold_9slice.svg") as Texture2D
	if texture == null:
		texture = find_texture("frames", "brown")
	return texture

static func orb_frame_texture() -> Texture2D:
	return load("res://assets/ui/frames/ornate_orb_ring.svg") as Texture2D

static func frame_style() -> StyleBox:
	var texture := ornate_frame_texture()
	if texture != null:
		var box := StyleBoxTexture.new()
		box.texture = texture
		box.texture_margin_left = 20
		box.texture_margin_top = 20
		box.texture_margin_right = 20
		box.texture_margin_bottom = 20
		box.content_margin_left = 16
		box.content_margin_top = 14
		box.content_margin_right = 16
		box.content_margin_bottom = 14
		box.modulate_color = Color(1.0, 0.98, 0.9, 1.0)
		return box
	return _box(PANEL, GOLD, 1, 8)

static func frame_underlay_style() -> StyleBoxFlat:
	var style := _box(Color(0.08, 0.06, 0.05, 0.94), Color("#D4AF37"), 2, 8)
	style.shadow_color = Color(0, 0, 0, 0.82)
	style.shadow_size = 7
	style.shadow_offset = Vector2(0, 3)
	return style

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

static func item_texture(item_id: String) -> Texture2D:
	var key := item_id.to_lower()
	var semantic_hints := {
		"bag": ["bag", "chest", "inventory"],
		"equip": ["armor", "helmet", "shield"],
		"skills": ["rune", "magic", "spell"],
		"mall": ["crystal", "gem", "shop"],
		"map": ["map", "compass", "world"],
		"settings": ["settings", "gear", "cog"],
		"xp": ["star", "spark", "magic"]
	}
	if semantic_hints.has(key):
		for hint in semantic_hints[key]:
			var semantic_texture := find_texture("icons/misc", hint)
			if semantic_texture == null:
				semantic_texture = find_texture("icons/skills", hint)
			if semantic_texture != null:
				return semantic_texture
		var fallback_texture := find_texture("icons/misc")
		if fallback_texture == null:
			fallback_texture = find_texture("icons/skills")
		return fallback_texture
	var category := "misc"
	var hint := key
	if "gem" in key or "crystal" in key or "jewel" in key or key in ["meteor", "dragonball", "rainbow"] or key.begins_with("dragon_") or key.begins_with("phoenix_") or key.begins_with("rainbow_") or key.begins_with("violet_") or key.begins_with("moon_") or key.begins_with("fury_") or key.begins_with("kylin_"):
		category = "gems"
		hint = key.get_slice("_", 0) if key.contains("_") else "gem"
		var family_texture := find_texture("icons/gems", hint)
		if family_texture != null:
			return family_texture
		hint = "gem"
	elif "potion" in key or "mana" in key or "health" in key or "flask" in key or key in ["hp", "mp"]:
		category = "potions"
		hint = "flask_full"
	elif "shield" in key or "armor" in key or "armour" in key or "helmet" in key or "boots" in key:
		category = "armor"
		hint = "shield"
	elif "weapon" in key or "sword" in key or "blade" in key or "dagger" in key or "knife" in key or "bow" in key or "katana" in key:
		category = "weapons"
		hint = "weapon"
	elif "rune" in key or "skill" in key or key in ["quest", "skills"]:
		category = "skills"
		hint = "rune"
	else:
		match key:
			"bag": category = "gems"; hint = "gem"
			"equip": category = "armor"; hint = "shield"
			"warehouse", "mall": category = "gems"; hint = "crystal"
			"jianghu", "interact": category = "weapons"; hint = "weapon"
	return find_texture("icons/" + category, hint)

static func style_button(button: Button, icon_key: String = "") -> void:
	if not is_instance_valid(button):
		return
	button.layout_direction = Control.LAYOUT_DIRECTION_RTL
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_color_override("font_outline_color", Color("#241509"))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_color_override("font_color", GOLD_HI)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", GOLD_HI)
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.46, 0.42, 0.72))
	var normal_texture := find_texture("buttons", "button_rectangle_depth_border")
	if normal_texture == null:
		normal_texture = find_texture("buttons", "button_round_depth_border")
	var hover_texture := find_texture("buttons", "button_rectangle_depth_flat")
	var pressed_texture := find_texture("buttons", "button_square_depth_border")
	button.add_theme_stylebox_override("normal", _box(Color(0.08, 0.06, 0.05, 0.96), Color("#8C642A"), 2, 5))
	button.add_theme_stylebox_override("hover", _box(Color("#392612"), GOLD_HI, 2, 5))
	button.add_theme_stylebox_override("pressed", _box(Color("#160F09"), Color("#FFE5A6"), 2, 5))
	button.add_theme_stylebox_override("disabled", _box(Color(0.025, 0.03, 0.04, 0.82), Color(0.3, 0.27, 0.21, 0.7), 1, 7))
	if not icon_key.is_empty():
		var icon := item_texture(icon_key)
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

extends Control
## Compact classic-MMORPG HUD. The legacy HUD remains available for safe rollback.
const ThemeManager = preload("res://src/scripts/ui/RPGIconThemeManager.gd")
const BAR_RATIO := 0.12
const HOTKEY_SKILLS := ["Jump", "Fly", "Scatter", "Path_of_Shadow", "XP_Mode"]
const HOTKEY_LABELS := ["JUMP", "FLY", "AOE", "SHADOW", "XP", "HP POT", "MP POT", "SLOT 8", "SLOT 9", "SLOT 10"]
const MENU_KEYS := ["Bag", "Equip", "Skills", "Mall", "JiangHu"]
var _bar: Control
var _hp_fill: TextureProgressBar
var _mp_fill: TextureProgressBar
var _hp_text: Label
var _mp_text: Label
var _xp: ProgressBar
var _xp_button: Button
var _quest_panel: Control
var _quest_title: Label
var _quest_progress: Label
var _quest_system: Node
var _hotkeys: Array[Button] = []
var _display_hp := 0.0
var _display_mp := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hide_legacy_hud()
	_build_bottom_bar()
	_build_quest_tracker()
	ThemeManager.apply_to_tree(self)
	if not ClassSystem.stats_changed.is_connected(_refresh_stats):
		ClassSystem.stats_changed.connect(_refresh_stats)
	if not ClassSystem.xp_skill_changed.is_connected(_refresh_xp_skill):
		ClassSystem.xp_skill_changed.connect(_refresh_xp_skill)
	if not GameState.inventory_changed.is_connected(_refresh_hotkeys):
		GameState.inventory_changed.connect(_refresh_hotkeys)
	_quest_system = get_tree().get_first_node_in_group("quest_system")
	if is_instance_valid(_quest_system) and _quest_system.has_signal("changed"):
		if not _quest_system.changed.is_connected(_refresh_quest):
			_quest_system.changed.connect(_refresh_quest)
	get_viewport().size_changed.connect(_layout)
	_refresh_stats()
	_refresh_xp_skill(ClassSystem.xp_skill, ClassSystem.xp_skill_max)
	_refresh_hotkeys()
	_refresh_quest()
	_layout()

func _hide_legacy_hud() -> void:
	var hud_root := get_parent().get_node_or_null("HUDRoot")
	if not is_instance_valid(hud_root):
		return
	for node_name in ["OrbHUD", "HotbarFrame", "ChatWindow", "ChatRestoreButton",
			"InventoryToggleButton", "UpgradeMarketToggleButton", "CharacterStatusButton",
			"SkillsBookButton", "WorldTravelButton", "XPBar", "XPSkillBar", "StaminaBar"]:
		var node := hud_root.get_node_or_null(node_name)
		if is_instance_valid(node):
			node.hide()

func _build_bottom_bar() -> void:
	_bar = Control.new()
	_bar.name = "ClassicConquerBottomBar"
	_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bar)
	var frame_texture := ThemeManager.find_texture("frames", "panel")
	if frame_texture == null:
		frame_texture = ThemeManager.find_texture("frames", "frame")
	var patch := ThemeManager.make_nine_patch(frame_texture, 14)
	if patch != null:
		patch.name = "NinePatchFrame"
		patch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bar.add_child(patch)
	else:
		var fallback := Panel.new()
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.add_theme_stylebox_override("panel", ThemeManager.frame_style())
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar.add_child(fallback)
	var row := HBoxContainer.new()
	row.name = "MainRow"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -4
	row.add_theme_constant_override("separation", 4)
	_bar.add_child(row)
	var hp_orb := _make_orb("HPOrb", Color("#e33a42"), "HP")
	row.add_child(hp_orb)
	var exp_caption := Label.new()
	exp_caption.text = "EXP"
	exp_caption.add_theme_color_override("font_color", Color("#f3d58a"))
	row.add_child(exp_caption)
	_xp = ProgressBar.new()
	_xp.name = "ClassicEXP"
	_xp.min_value = 0
	_xp.max_value = 100
	_xp.show_percentage = false
	_xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp.custom_minimum_size = Vector2(90, 9)
	_xp.add_theme_stylebox_override("background", _flat(Color(0.02,0.025,0.035,1), Color("#72572e"), 1))
	_xp.add_theme_stylebox_override("fill", _flat(Color("#d7a83e"), Color("#ffe3a0"), 1))
	row.add_child(_xp)
	_xp_button = Button.new()
	_xp_button.name = "XPModeButton"
	_xp_button.text = "XP"
	_xp_button.custom_minimum_size = Vector2(36, 34)
	_xp_button.pressed.connect(_use_xp_skill)
	row.add_child(_xp_button)
	for index in range(10):
		var button := Button.new()
		button.name = "HotkeyF%d" % (index + 1)
		button.text = "F%d\n%s" % [index + 1, HOTKEY_LABELS[index]]
		button.custom_minimum_size = Vector2(30, 34)
		button.add_theme_font_size_override("font_size", 8)
		button.tooltip_text = HOTKEY_LABELS[index]
		button.pressed.connect(_on_hotkey_pressed.bind(index))
		row.add_child(button)
		_hotkeys.append(button)
		if index >= 7:
			button.disabled = true
	for menu_key in MENU_KEYS:
		var menu := Button.new()
		menu.name = "Menu" + menu_key
		menu.text = {"Bag":"BAG","Equip":"EQ","Skills":"SK","Mall":"MALL","JiangHu":"JH"}[menu_key]
		menu.custom_minimum_size = Vector2(31, 34)
		menu.add_theme_font_size_override("font_size", 8)
		menu.set_meta("rpg_icon", menu_key.to_lower())
		menu.pressed.connect(_open_menu.bind(menu_key))
		row.add_child(menu)
	row.add_child(_make_orb("MPOrb", Color("#3389ef"), "MP"))

func _make_orb(node_name: String, tint: Color, caption: String) -> Control:
	var orb := Control.new()
	orb.name = node_name
	orb.custom_minimum_size = Vector2(44, 44)
	orb.size = orb.custom_minimum_size
	var ring := Panel.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.add_theme_stylebox_override("panel", _flat(Color(0.025,0.03,0.045,1), Color("#d4a95b"), 2, 22))
	orb.add_child(ring)
	var fill := TextureProgressBar.new()
	fill.name = caption + "Fill"
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.offset_left = 4
	fill.offset_top = 4
	fill.offset_right = -4
	fill.offset_bottom = -4
	fill.min_value = 0
	fill.max_value = 100
	fill.value = 100
	fill.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	fill.radial_initial_angle = 270
	fill.radial_fill_degrees = 360
	fill.texture_under = _solid(Color(0.07,0.075,0.09,1))
	fill.texture_progress = _solid(tint)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(fill)
	var label := Label.new()
	label.name = caption + "Value"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	orb.add_child(label)
	if caption == "HP":
		_hp_fill = fill
		_hp_text = label
	else:
		_mp_fill = fill
		_mp_text = label
	return orb

func _build_quest_tracker() -> void:
	_quest_panel = Control.new()
	_quest_panel.name = "LiveQuestTracker"
	_quest_panel.position = Vector2(16, 115)
	_quest_panel.custom_minimum_size = Vector2(250, 68)
	_quest_panel.size = Vector2(250, 68)
	var frame_texture := ThemeManager.find_texture("frames", "quest")
	if frame_texture == null:
		frame_texture = ThemeManager.find_texture("frames", "panel")
	var patch := ThemeManager.make_nine_patch(frame_texture, 12)
	if patch != null:
		patch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_quest_panel.add_child(patch)
	else:
		var fallback := Panel.new()
		fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fallback.add_theme_stylebox_override("panel", _flat(Color(0.025,0.035,0.05,0.82), Color("#c99b4d"), 1, 7))
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_quest_panel.add_child(fallback)
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 8
	body.offset_right = -8
	body.offset_top = 5
	body.offset_bottom = -5
	body.add_theme_constant_override("separation", 1)
	_quest_panel.add_child(body)
	_quest_title = Label.new()
	_quest_title.text = "المهمة الحالية"
	_quest_title.add_theme_color_override("font_color", Color("#f3d58a"))
	body.add_child(_quest_title)
	_quest_progress = Label.new()
	_quest_progress.text = "اضغط لتفعيل التتبع التلقائي"
	_quest_progress.add_theme_color_override("font_color", Color("#e7dfcf"))
	body.add_child(_quest_progress)
	_quest_panel.gui_input.connect(_on_quest_panel_input)
	add_child(_quest_panel)

func _layout() -> void:
	if not is_instance_valid(_bar):
		return
	var viewport := get_viewport_rect().size
	var bar_height := viewport.y * BAR_RATIO
	_bar.position = Vector2(4, viewport.y - bar_height)
	_bar.size = Vector2(viewport.x - 8, bar_height)
	var orb_size := maxf(34.0, bar_height - 8.0)
	for orb_name in ["HPOrb", "MPOrb"]:
		var orb := _bar.get_node_or_null("MainRow/" + orb_name)
		if is_instance_valid(orb):
			orb.custom_minimum_size = Vector2(orb_size, orb_size)
			orb.size = Vector2(orb_size, orb_size)
	_quest_panel.position = Vector2(16, maxf(104.0, viewport.y * 0.16))
	var hud_root := get_parent().get_node_or_null("HUDRoot")
	if is_instance_valid(hud_root):
		var joystick := hud_root.get_node_or_null("VirtualJoystick")
		if is_instance_valid(joystick):
			joystick.position = Vector2(18, viewport.y - bar_height - joystick.size.y - 10)

func _process(delta: float) -> void:
	_display_hp = lerpf(_display_hp, float(ClassSystem.hp), clampf(delta * 10.0, 0.0, 1.0))
	_display_mp = lerpf(_display_mp, float(ClassSystem.mp), clampf(delta * 10.0, 0.0, 1.0))
	if is_instance_valid(_hp_fill):
		_hp_fill.max_value = maxi(1, ClassSystem.max_hp)
		_hp_fill.value = _display_hp
		_hp_text.text = "%d\nHP" % int(round(_display_hp))
	if is_instance_valid(_mp_fill):
		_mp_fill.max_value = maxi(1, ClassSystem.max_mp)
		_mp_fill.value = _display_mp
		_mp_text.text = "%d\nMP" % int(round(_display_mp))
	if is_instance_valid(_xp):
		_xp.max_value = maxi(1, ClassSystem.get_required_xp())
		_xp.value = ClassSystem.experience

func _potion_count(item_id: String) -> int:
	for entry in GameState.profile.get("inventory", []):
		if str(entry.get("id", "")) == item_id:
			return int(entry.get("quantity", 1))
	return 0

func _refresh_hotkeys() -> void:
	if _hotkeys.size() >= 7:
		_hotkeys[5].disabled = _potion_count("HP_Potion") <= 0
		_hotkeys[6].disabled = _potion_count("Mana_Potion") <= 0

func _refresh_stats() -> void:
	if is_instance_valid(_xp):
		_xp.max_value = maxi(1, ClassSystem.get_required_xp())
		_xp.value = ClassSystem.experience

func _refresh_xp_skill(value: float, maximum: float) -> void:
	if not is_instance_valid(_xp_button):
		return
	var ready := value >= maximum
	_xp_button.disabled = not ready
	_xp_button.text = "XP!" if ready else "XP"
	_xp_button.modulate = Color("#fff0a6") if ready else Color("#b7a27b")

func _use_xp_skill() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and player.has_method("cast_skill"):
		player.call("cast_skill", "XP_Mode")

func _on_hotkey_pressed(index: int) -> void:
	if index == 5:
		GameState.use_consumable("HP_Potion")
		_refresh_hotkeys()
		return
	if index == 6:
		GameState.use_consumable("Mana_Potion")
		_refresh_hotkeys()
		return
	var player := get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		return
	if index < HOTKEY_SKILLS.size() and player.has_method("cast_skill"):
		player.call("cast_skill", HOTKEY_SKILLS[index])

func _open_menu(menu_key: String) -> void:
	var hud := get_parent()
	match menu_key:
		"Bag": hud.call("_toggle_inventory")
		"Equip": hud.call("_toggle_status_ui")
		"Skills": hud.call("_toggle_skills_ui")
		"Mall":
			var mall = hud.get("_mall_ui")
			if is_instance_valid(mall): mall.call("toggle")
		"JiangHu":
			var guild = hud.get("_guild_ui")
			if is_instance_valid(guild): guild.call("toggle")

func _refresh_quest() -> void:
	if not is_instance_valid(_quest_title):
		return
	if not is_instance_valid(_quest_system):
		_quest_system = get_tree().get_first_node_in_group("quest_system")
	if not is_instance_valid(_quest_system):
		_quest_title.text = "لا توجد مهمة نشطة"
		_quest_progress.text = "اضغط لبدء أقرب مهمة متاحة"
		return
	var active_id := str(_quest_system.get("active_quest"))
	var entries: Array = _quest_system.call("available")
	var selected: Dictionary = {}
	for entry in entries:
		if str(entry.get("id", "")) == active_id:
			selected = entry
			break
	if selected.is_empty():
		for entry in entries:
			if str(entry.get("state", "")) == "active":
				selected = entry
				active_id = str(entry.get("id", ""))
				break
	if selected.is_empty():
		_quest_title.text = "لا توجد مهمة نشطة"
		_quest_progress.text = "اضغط لبدء أقرب مهمة متاحة"
		return
	_quest_title.text = str(selected.get("title", "المهمة الحالية"))
	_quest_progress.text = "%d/%d  •  اضغط للتتبع التلقائي" % [int(selected.get("count", 0)), int(selected.get("goal", 1))]

func _on_quest_panel_input(event: InputEvent) -> void:
	var clicked := (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not clicked:
		return
	if not is_instance_valid(_quest_system):
		_quest_system = get_tree().get_first_node_in_group("quest_system")
	if not is_instance_valid(_quest_system):
		return
	var active_id := str(_quest_system.get("active_quest"))
	if active_id.is_empty():
		for entry in _quest_system.call("available"):
			if str(entry.get("state", "")) == "active":
				active_id = str(entry.get("id", ""))
				break
			if str(entry.get("state", "")) == "ready":
				continue
			if _quest_system.call("accept", str(entry.get("id", ""))):
				active_id = str(entry.get("id", ""))
				break
	if not active_id.is_empty():
		_quest_system.call("track", active_id)
		_refresh_quest()
	accept_event()

func _flat(bg: Color, border: Color, width: int, radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style

func _solid(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, color.darkened(0.28))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	return texture

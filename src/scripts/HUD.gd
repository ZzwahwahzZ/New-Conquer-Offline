extends CanvasLayer
## Landscape MMORPG HUD. Named texture nodes are reserved for the final art pass.

const JOYSTICK_SIZE := Vector2(164.0, 164.0)
const JOYSTICK_RADIUS := 57.0
const HOTBAR_SIZE := Vector2(500.0, 78.0)
const ORB_SIZE := Vector2(176.0, 176.0)
const SKILL_COST_LABELS := {"Jump":"MP 0 / STA 7","Fly":"MP 20 / STA 0","Scatter":"MP 15 / STA 5","Rapid_Fire":"MP 10 / STA 4","Kinetic_Spark":"MP 10 / STA 4","Path_of_Shadow":"MP 0 / STA 0","XP_Mode":"MP 0 / STA 0"}

var _root: Control
var _joystick: Control
var _joystick_knob: Panel
var _joystick_vector := Vector2.ZERO
var _joystick_touch_index := -1
var _joystick_mouse_active := false
var _player: Node3D
var _gold_label: Label
var _hp_bar: TextureProgressBar
var _mp_bar: TextureProgressBar
var _xp_bar: ProgressBar
var _xp_skill_bar: ProgressBar
var _stamina_bar: ProgressBar
var _chat_window: PanelContainer
var _chat_restore_button: Button
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _inventory_ui: CanvasLayer
var _inventory_button: Button
var _upgrade_ui: CanvasLayer
var _upgrade_button: Button
var _promotion_button: Button
var _status_ui: Control
var _skills_ui: Control
var _status_button: Button
var _skills_button: Button
var _world_button: Button
var _world_panel: PanelContainer
var _world_manager: Node
var _minimap: Control
var _skill_buttons: Array[Button] = []
var _skill_ids := ["Jump", "Fly", "Scatter", "Path_of_Shadow", "XP_Mode"]
var _active_skill_mode := ""
var _quest_ui: CanvasLayer
var _shop_ui: CanvasLayer
var _mall_ui: CanvasLayer
var _warehouse_ui: CanvasLayer
var _guild_ui: CanvasLayer
var _last_bot_milestone_class := ""
var _last_bot_milestone_plus := 0


func _ready() -> void:
	add_to_group("game_hud")
	_build_hud()
	_connect_economy()
	_connect_game_state()
	_find_player()
	get_viewport().size_changed.connect(_layout_hud)
	_layout_hud()


func _build_hud() -> void:
	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_joystick()
	_build_orb()
	_build_hotbar()
	_build_chat()
	_build_xp_bar()
	_build_xp_skill_bar()
	_build_stamina_bar()
	_build_inventory_toggle()
	_inventory_ui = load("res://src/scenes/InventoryUI.tscn").instantiate() as CanvasLayer
	add_child(_inventory_ui)
	_build_upgrade_toggle()
	_upgrade_ui = load("res://src/scenes/UpgradeMarketUI.tscn").instantiate() as CanvasLayer
	add_child(_upgrade_ui)
	_build_promotion_button()
	_status_ui = load("res://src/scenes/CharacterStatusUI.tscn").instantiate() as Control
	add_child(_status_ui)
	_skills_ui = load("res://src/scenes/SkillsUI.tscn").instantiate() as Control
	add_child(_skills_ui)
	_build_character_window_buttons()
	_build_world_widgets()
	_build_step12_widgets()
	if not ClassSystem.level_up.is_connected(_on_level_up): ClassSystem.level_up.connect(_on_level_up)
	if not ClassSystem.character_changed.is_connected(_on_bot_milestone_check): ClassSystem.character_changed.connect(_on_bot_milestone_check)
	if not GearSystem.equipment_changed.is_connected(_on_bot_milestone_check): GearSystem.equipment_changed.connect(_on_bot_milestone_check)
	_last_bot_milestone_class = ClassSystem.current_class
	_last_bot_milestone_plus = _get_equipment_plus_max()


func _build_joystick() -> void:
	_joystick = Control.new()
	_joystick.name = "VirtualJoystick"
	_joystick.custom_minimum_size = JOYSTICK_SIZE
	_joystick.size = JOYSTICK_SIZE
	_joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_joystick)

	var base := Panel.new()
	base.name = "JoystickBase"
	base.size = JOYSTICK_SIZE
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.055, 0.075, 0.78), Color(0.72, 0.53, 0.25, 0.95), 5, 82))
	_joystick.add_child(base)

	var inner_ring := Panel.new()
	inner_ring.name = "JoystickInnerRing"
	inner_ring.position = Vector2(17, 17)
	inner_ring.size = JOYSTICK_SIZE - Vector2(34, 34)
	inner_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_ring.add_theme_stylebox_override("panel", _panel_style(Color(0.12, 0.16, 0.19, 0.38), Color(0.42, 0.34, 0.23, 0.9), 2, 70))
	_joystick.add_child(inner_ring)

	_joystick_knob = Panel.new()
	_joystick_knob.name = "JoystickKnob"
	_joystick_knob.size = Vector2(68, 68)
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.31, 0.24, 0.15, 0.96), Color(0.94, 0.72, 0.34, 1.0), 3, 40))
	_joystick.add_child(_joystick_knob)
	_reset_joystick_knob()
	_joystick.gui_input.connect(_on_joystick_gui_input)


func _build_orb() -> void:
	var orb := Control.new()
	orb.name = "OrbHUD"
	orb.custom_minimum_size = ORB_SIZE
	orb.size = ORB_SIZE
	_root.add_child(orb)

	var backing := Panel.new()
	backing.name = "OrbBacking"
	backing.position = Vector2(12, 12)
	backing.size = Vector2(152, 152)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.055, 0.96), Color(0.86, 0.62, 0.24, 1.0), 5, 76))
	orb.add_child(backing)

	_hp_bar = _make_orb_bar("HPBar", Color(0.82, 0.12, 0.12, 0.98), 270.0)
	_hp_bar.position = Vector2(23, 23)
	_hp_bar.size = Vector2(130, 130)
	orb.add_child(_hp_bar)

	_mp_bar = _make_orb_bar("MPBar", Color(0.12, 0.39, 0.92, 0.98), 90.0)
	_mp_bar.position = Vector2(23, 23)
	_mp_bar.size = Vector2(130, 130)
	orb.add_child(_mp_bar)

	var center := Panel.new()
	center.name = "OrbCenter"
	center.position = Vector2(54, 54)
	center.size = Vector2(68, 68)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.055, 0.07, 1.0), Color(0.59, 0.43, 0.21, 1.0), 2, 36))
	orb.add_child(center)

	var border := TextureRect.new()
	border.name = "OrbBorder"
	border.position = Vector2.ZERO
	border.size = ORB_SIZE
	border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	border.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb.add_child(border)

	_gold_label = Label.new()
	_gold_label.name = "GoldLabel"
	_gold_label.text = "GOLD  0"
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_label.position = Vector2(-18, -25)
	_gold_label.size = Vector2(212, 28)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.43))
	_gold_label.add_theme_color_override("font_shadow_color", Color(0.05, 0.035, 0.02, 1.0))
	_gold_label.add_theme_constant_override("shadow_offset_x", 1)
	_gold_label.add_theme_constant_override("shadow_offset_y", 1)
	_gold_label.add_theme_font_size_override("font_size", 15)
	_gold_label.add_to_group("gold_counter")
	orb.add_child(_gold_label)
	set_gold(GlobalEconomy.current_gold)


func _make_orb_bar(node_name: String, tint: Color, start_angle: float) -> TextureProgressBar:
	var bar := TextureProgressBar.new()
	bar.name = node_name
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	bar.radial_initial_angle = start_angle
	bar.radial_fill_degrees = 180.0
	bar.radial_center_offset = Vector2.ZERO
	bar.texture_under = _solid_texture(Color(0.07, 0.075, 0.09, 0.95))
	bar.texture_progress = _solid_texture(tint)
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _build_hotbar() -> void:
	var frame := Panel.new()
	frame.name = "HotbarFrame"
	frame.custom_minimum_size = HOTBAR_SIZE
	frame.size = HOTBAR_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.052, 0.065, 0.92), Color(0.78, 0.57, 0.29, 1.0), 3, 10))
	_root.add_child(frame)

	var panel_texture := TextureRect.new()
	panel_texture.name = "HotbarPanel"
	panel_texture.position = Vector2(5, 5)
	panel_texture.size = HOTBAR_SIZE - Vector2(10, 10)
	panel_texture.texture = _solid_texture(Color(0.11, 0.105, 0.09, 0.76))
	panel_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel_texture.stretch_mode = TextureRect.STRETCH_SCALE
	panel_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(panel_texture)

	var skills := HBoxContainer.new()
	skills.name = "SkillButtons"
	skills.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skills.offset_left = 12
	skills.offset_top = 9
	skills.offset_right = -12
	skills.offset_bottom = -9
	skills.alignment = BoxContainer.ALIGNMENT_CENTER
	skills.add_theme_constant_override("separation", 8)
	frame.add_child(skills)

	for index in range(8):
		var skill := Button.new()
		skill.name = "Skill%d" % (index + 1)
		skill.text = str(index + 1)
		skill.custom_minimum_size = Vector2(48, 54)
		skill.add_theme_font_size_override("font_size", 18)
		skill.add_theme_color_override("font_color", Color(1.0, 0.88, 0.64))
		skill.add_theme_stylebox_override("normal", _panel_style(Color(0.12, 0.13, 0.15, 0.98), Color(0.65, 0.49, 0.27, 1.0), 2, 7))
		skill.add_theme_stylebox_override("hover", _panel_style(Color(0.22, 0.19, 0.13, 1.0), Color(1.0, 0.79, 0.39, 1.0), 2, 7))
		skill.add_theme_stylebox_override("pressed", _panel_style(Color(0.07, 0.08, 0.1, 1.0), Color(0.95, 0.67, 0.27, 1.0), 2, 7))
		skills.add_child(skill)
		if index < _skill_ids.size():
			_skill_buttons.append(skill)
			skill.text = ["JUMP", "FLY", "AOE", "SHADOW", "XP"][index]
			skill.pressed.connect(_on_hotbar_skill_pressed.bind(index))


func _build_chat() -> void:
	_chat_window = PanelContainer.new()
	_chat_window.name = "ChatWindow"
	_chat_window.custom_minimum_size = Vector2(500, 132)
	_chat_window.mouse_filter = Control.MOUSE_FILTER_STOP
	_chat_window.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.035, 0.05, 0.88), Color(0.66, 0.49, 0.25, 0.95), 2, 8))
	_root.add_child(_chat_window)

	var body := VBoxContainer.new()
	body.name = "ChatBody"
	body.add_theme_constant_override("separation", 4)
	_chat_window.add_child(body)

	var header := HBoxContainer.new()
	header.name = "ChatTabs"
	header.add_theme_constant_override("separation", 5)
	body.add_child(header)

	for tab_name in ["عام", "فريق", "نقابة", "خاص"]:
		var tab := Button.new()
		tab.name = "ChatTab_" + tab_name
		tab.text = tab_name
		tab.custom_minimum_size = Vector2(58, 25)
		tab.add_theme_font_size_override("font_size", 13)
		tab.add_theme_stylebox_override("normal", _panel_style(Color(0.12, 0.105, 0.085, 0.95), Color(0.53, 0.4, 0.23, 0.9), 1, 4))
		header.add_child(tab)

	var minimize := Button.new()
	minimize.name = "ChatMinimizeButton"
	minimize.text = "—"
	minimize.custom_minimum_size = Vector2(28, 25)
	minimize.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minimize.pressed.connect(_minimize_chat)
	header.add_child(minimize)

	_chat_log = RichTextLabel.new()
	_chat_log.name = "ChatLog"
	_chat_log.bbcode_enabled = true
	_chat_log.fit_content = false
	_chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_log.scroll_following = true
	_chat_log.text = "[color=#d8c49c]مرحباً بك في عالم نيو كونكر.[/color]"
	body.add_child(_chat_log)

	_chat_input = LineEdit.new()
	_chat_input.name = "ChatInput"
	_chat_input.placeholder_text = "اكتب رسالة..."
	_chat_input.custom_minimum_size.y = 27
	_chat_input.text_submitted.connect(_on_chat_submitted)
	body.add_child(_chat_input)

	_chat_restore_button = Button.new()
	_chat_restore_button.name = "ChatRestoreButton"
	_chat_restore_button.text = "CHAT  +"
	_chat_restore_button.custom_minimum_size = Vector2(100, 28)
	_chat_restore_button.pressed.connect(_restore_chat)
	_root.add_child(_chat_restore_button)
	_chat_restore_button.hide()



func _build_inventory_toggle() -> void:
	_inventory_button = Button.new()
	var button := _inventory_button
	button.name = "InventoryToggleButton"
	button.text = "الحقيبة  [I]"
	button.custom_minimum_size = Vector2(118, 42)
	button.position = Vector2(18, 18)
	button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.61))
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.045, 0.052, 0.065, 0.94), Color(0.78, 0.57, 0.29, 1.0), 2, 8))
	button.pressed.connect(_toggle_inventory)
	_root.add_child(button)


func _build_promotion_button() -> void:
	_promotion_button = get_node_or_null("PathOfShadowButton") as Button
	if _promotion_button == null:
		_promotion_button = Button.new()
		_promotion_button.name = "PathOfShadowButton"
		_root.add_child(_promotion_button)
	else:
		_promotion_button.reparent(_root)
	_promotion_button.text = "Path of Shadow"
	_promotion_button.custom_minimum_size = Vector2(190, 42)
	_promotion_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.61))
	_promotion_button.add_theme_stylebox_override("normal", _panel_style(Color(0.08, 0.12, 0.16, 0.96), Color(0.2, 0.78, 0.95, 1.0), 2, 8))
	_promotion_button.pressed.connect(_on_promote_archer)
	_promotion_button.hide()

func _on_promote_archer() -> void:
	if ClassSystem.is_path_shadow_unlocked():
		ClassSystem.toggle_path_of_shadow()
	elif ClassSystem.can_evolve_to("Oriental_Assassin"):
		ClassSystem.evolve_to("Oriental_Assassin")

func _build_character_window_buttons() -> void:
	_status_button = Button.new()
	_status_button.name = "CharacterStatusButton"
	_status_button.text = "الشخصية [C]"
	_status_button.custom_minimum_size = Vector2(118,42)
	_status_button.pressed.connect(_toggle_status_ui)
	_root.add_child(_status_button)
	_skills_button = Button.new()
	_skills_button.name = "SkillsBookButton"
	_skills_button.text = "المهارات [K]"
	_skills_button.custom_minimum_size = Vector2(118,42)
	_skills_button.pressed.connect(_toggle_skills_ui)
	_root.add_child(_skills_button)

func _build_world_widgets() -> void:
	_world_manager = get_tree().get_first_node_in_group("world_manager")
	_world_button = Button.new()
	_world_button.name = "WorldTravelButton"
	_world_button.text = "العالم  [M]"
	_world_button.custom_minimum_size = Vector2(118,42)
	_world_button.pressed.connect(_toggle_world_panel)
	_root.add_child(_world_button)
	_world_panel = PanelContainer.new()
	_world_panel.name = "WorldTravelPanel"
	_world_panel.size = Vector2(210,270)
	_world_panel.add_theme_stylebox_override("panel",_panel_style(Color(0.025,0.04,0.055,0.96),Color(0.78,0.57,0.29,1.0),2,8))
	_root.add_child(_world_panel)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation",4)
	_world_panel.add_child(list)
	var title := Label.new()
	title.text = "الانتقال بين المستوطنات"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list.add_child(title)
	if is_instance_valid(_world_manager):
		for settlement_id in _world_manager.call("get_settlement_ids"):
			var button := Button.new()
			button.text = "%s  (%s)" % [_world_manager.call("get_settlement_name",settlement_id),_world_manager.call("get_settlement_level_range",settlement_id)]
			button.pressed.connect(_travel_to_settlement.bind(str(settlement_id)))
			list.add_child(button)
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(_toggle_world_panel)
	list.add_child(close)
	_world_panel.hide()
	_minimap = load("res://src/scripts/MiniMapUI.gd").new()
	_minimap.name = "MiniMapUI"
	_root.add_child(_minimap)
	_minimap.call("configure",_world_manager,get_tree().get_first_node_in_group("player"))

func _toggle_world_panel() -> void:
	if is_instance_valid(_world_panel): _world_panel.visible = not _world_panel.visible

func _travel_to_settlement(settlement_id: String) -> void:
	if is_instance_valid(_world_manager): _world_manager.call("change_settlement",settlement_id)
	if is_instance_valid(_world_panel): _world_panel.hide()

func _toggle_status_ui() -> void:
	if is_instance_valid(_status_ui): _status_ui.call("toggle")

func _toggle_skills_ui() -> void:
	if is_instance_valid(_skills_ui): _skills_ui.call("toggle")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			_toggle_world_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_C:
			_toggle_status_ui()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_K:
			_toggle_skills_ui()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_G and is_instance_valid(_guild_ui):
			_guild_ui.call("toggle")
			get_viewport().set_input_as_handled()

func _on_level_up(new_level: int) -> void:
	# The actual per-level increments are recorded by ClassSystem.
	var last: Dictionary = ClassSystem.get_meta("last_auto_allocation", {"strength":0,"agility":0,"vitality":0,"spirit":0})
	notify_auto_allocation(new_level, last)

func notify_auto_allocation(new_level: int, allocation: Dictionary) -> void:
	if not is_instance_valid(_chat_log): return
	var message := "تم رفع المستوى إلى %d — توزيع تلقائي: STR +%d | AGI +%d | VIT +%d | SPI +%d" % [new_level,int(allocation.get("strength",0)),int(allocation.get("agility",0)),int(allocation.get("vitality",0)),int(allocation.get("spirit",0))]
	_chat_log.append_text("\\n[color=#f4d58a][نظام] [/color]" + message)

func _build_upgrade_toggle() -> void:
	_upgrade_button = Button.new()
	_upgrade_button.name = "UpgradeMarketToggleButton"
	_upgrade_button.text = "التطوير  [U]"
	_upgrade_button.custom_minimum_size = Vector2(118, 42)
	_upgrade_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.61))
	_upgrade_button.add_theme_stylebox_override("normal", _panel_style(Color(0.045, 0.052, 0.065, 0.94), Color(0.78, 0.57, 0.29, 1.0), 2, 8))
	_upgrade_button.pressed.connect(_toggle_upgrade_market)
	_root.add_child(_upgrade_button)

func _toggle_upgrade_market() -> void:
	if is_instance_valid(_upgrade_ui) and _upgrade_ui.has_method("toggle"):
		_upgrade_ui.toggle()

func _toggle_inventory() -> void:
	if is_instance_valid(_inventory_ui) and _inventory_ui.has_method("toggle"):
		_inventory_ui.toggle()

func _build_xp_bar() -> void:
	_xp_bar = ProgressBar.new()
	_xp_bar.name = "XPBar"
	_xp_bar.min_value = 0
	_xp_bar.max_value = 100
	_xp_bar.value = 0
	_xp_bar.show_percentage = false
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar.add_theme_stylebox_override("background", _panel_style(Color(0.025, 0.03, 0.04, 0.95), Color(0.3, 0.26, 0.2, 1.0), 1, 0))
	_xp_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.73, 0.53, 0.15, 1.0), Color(0.92, 0.75, 0.34, 1.0), 0, 0))
	_root.add_child(_xp_bar)


func _build_xp_skill_bar() -> void:
	_xp_skill_bar = ProgressBar.new()
	_xp_skill_bar.name = "XPSkillBar"
	_xp_skill_bar.min_value = 0
	_xp_skill_bar.max_value = 100
	_xp_skill_bar.value = 0
	_xp_skill_bar.show_percentage = false
	_xp_skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_skill_bar.add_theme_stylebox_override("background", _panel_style(Color(0.025,0.03,0.04,0.95), Color(0.18,0.35,0.48,1.0), 1, 0))
	_xp_skill_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.1,0.68,0.92,1.0), Color(0.55,0.9,1.0,1.0), 0, 0))
	_root.add_child(_xp_skill_bar)

func _build_stamina_bar() -> void:
	_stamina_bar = ProgressBar.new()
	_stamina_bar.name = "StaminaBar"
	_stamina_bar.min_value = 0
	_stamina_bar.max_value = ClassSystem.max_stamina
	_stamina_bar.value = ClassSystem.stamina
	_stamina_bar.show_percentage = false
	_stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bar.add_theme_stylebox_override("background", _panel_style(Color(0.025,0.03,0.04,0.95), Color(0.25,0.38,0.2,1.0), 1, 0))
	_stamina_bar.add_theme_stylebox_override("fill", _panel_style(Color(0.35,0.78,0.22,1.0), Color(0.7,0.95,0.45,1.0), 0, 0))
	_root.add_child(_stamina_bar)

func _layout_hud() -> void:
	if not is_instance_valid(_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var width := viewport_size.x
	var height := viewport_size.y
	# Keep the mobile joystick above the 12% classic bottom bar and clear of its HP/MP orb.
	var classic_bar_height := height * 0.12
	_joystick.position = Vector2(18, height - classic_bar_height - JOYSTICK_SIZE.y - 10)
	if is_instance_valid(_inventory_button):
		_inventory_button.position = Vector2(width - 142.0, 18.0)
	if is_instance_valid(_upgrade_button):
		_upgrade_button.position = Vector2(width - 270.0, 18.0)
	if is_instance_valid(_status_button): _status_button.position = Vector2(18.0,68.0)
	if is_instance_valid(_skills_button): _skills_button.position = Vector2(146.0,68.0)
	if is_instance_valid(_world_button): _world_button.position = Vector2(width - 398.0,18.0)
	if is_instance_valid(_world_panel): _world_panel.position = Vector2(18.0,206.0)
	if is_instance_valid(_minimap): _minimap.position = Vector2(width - 210.0,118.0)
	if is_instance_valid(_promotion_button):
		_promotion_button.position = Vector2(width - 210.0, 68.0)

	var orb := _root.get_node("OrbHUD") as Control
	orb.position = Vector2(width - ORB_SIZE.x - 20, height - ORB_SIZE.y - 20)

	var frame := _root.get_node("HotbarFrame") as Control
	var hotbar_width := minf(HOTBAR_SIZE.x, maxf(300.0, width - 420.0))
	frame.size = Vector2(hotbar_width, HOTBAR_SIZE.y)
	frame.position = Vector2((width - hotbar_width) * 0.5, height - HOTBAR_SIZE.y - 18)

	var chat_width := minf(500.0, maxf(280.0, width - 40.0))
	_chat_window.position = Vector2((width - chat_width) * 0.5, height - 228.0)
	_chat_window.size = Vector2(chat_width, 132)
	_chat_restore_button.position = Vector2((width - 100.0) * 0.5, height - 258.0)

	_xp_bar.position = Vector2(0, height - 4)
	_xp_bar.size = Vector2(width, 3)
	_xp_skill_bar.position = Vector2(0, height - 8)
	_xp_skill_bar.size = Vector2(width, 3)
	_stamina_bar.position = Vector2(0, height - 12)
	_stamina_bar.size = Vector2(width, 3)


func _on_joystick_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _joystick_touch_index == -1:
			_joystick_touch_index = event.index
			_update_joystick(event.position)
			_joystick.accept_event()
		elif not event.pressed and event.index == _joystick_touch_index:
			_joystick_touch_index = -1
			_release_joystick()
			_joystick.accept_event()
	elif event is InputEventScreenDrag and event.index == _joystick_touch_index:
		_update_joystick(event.position)
		_joystick.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_joystick_mouse_active = event.pressed
		if event.pressed:
			_update_joystick(event.position)
		else:
			_release_joystick()
		_joystick.accept_event()
	elif event is InputEventMouseMotion and _joystick_mouse_active:
		_update_joystick(event.position)
		_joystick.accept_event()


func _update_joystick(local_position: Vector2) -> void:
	var center := JOYSTICK_SIZE * 0.5
	var offset := local_position - center
	_joystick_vector = (offset / JOYSTICK_RADIUS).limit_length(1.0)
	_joystick_knob.position = center - _joystick_knob.size * 0.5 + _joystick_vector * JOYSTICK_RADIUS
	_send_joystick_to_player(true)


func _release_joystick() -> void:
	_joystick_vector = Vector2.ZERO
	_joystick_mouse_active = false
	_reset_joystick_knob()
	_send_joystick_to_player(false)


func _reset_joystick_knob() -> void:
	if is_instance_valid(_joystick_knob):
		_joystick_knob.position = (JOYSTICK_SIZE - _joystick_knob.size) * 0.5


func _send_joystick_to_player(active: bool) -> void:
	if not is_instance_valid(_player):
		_find_player()
	if is_instance_valid(_player) and _player.has_method("set_virtual_joystick_input"):
		_player.call("set_virtual_joystick_input", _joystick_vector, active)


func _find_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as Node3D
	if not is_instance_valid(_player):
		_player = get_node_or_null("../LocalPlayer") as Node3D


func _connect_economy() -> void:
	if not GlobalEconomy.gold_changed.is_connected(set_gold):
		GlobalEconomy.gold_changed.connect(set_gold)
	set_gold(GlobalEconomy.current_gold)


func set_gold(amount: int) -> void:
	if is_instance_valid(_gold_label):
		_gold_label.text = "GOLD  %s" % _format_number(amount)


func _format_number(value: int) -> String:
	var raw := str(maxi(0, value))
	var formatted := ""
	for index in range(raw.length()):
		if index > 0 and (raw.length() - index) % 3 == 0:
			formatted += ","
		formatted += raw[index]
	return formatted


func _connect_game_state() -> void:
	if not GameState.stats_changed.is_connected(_refresh_stats):
		GameState.stats_changed.connect(_refresh_stats)
	if not ClassSystem.stats_changed.is_connected(_refresh_stats):
		ClassSystem.stats_changed.connect(_refresh_stats)
	_refresh_stats()


func _on_skill_pressed(skill_id: String) -> void:
	if not is_instance_valid(_player): _find_player()
	if is_instance_valid(_player) and _player.has_method("cast_skill"):
		_player.cast_skill(skill_id)

func _on_hotbar_skill_pressed(index: int) -> void:
	if index >= 0 and index < _skill_ids.size():
		_on_skill_pressed(_skill_ids[index])

func _refresh_active_skillbar() -> void:
	var mode: String = ClassSystem.current_class
	if mode == _active_skill_mode:
		return
	_active_skill_mode = mode
	_skill_ids = ["Jump", "Fly", "Scatter", "Path_of_Shadow", "XP_Mode"] if mode == "Archer" else ["Jump", "Rapid_Fire", "Kinetic_Spark", "Path_of_Shadow", "XP_Mode"]
	var labels := ["JUMP", "FLY", "SCATTER", "SHADOW", "XP"] if mode == "Archer" else ["JUMP", "RAPID", "SPARK", "SHADOW", "XP"]
	for index in range(mini(_skill_buttons.size(), _skill_ids.size())):
		_skill_buttons[index].text = labels[index]
		_skill_buttons[index].tooltip_text = _skill_ids[index] + " | " + str(SKILL_COST_LABELS.get(_skill_ids[index], ""))

func _process(_delta: float) -> void:
	if not is_instance_valid(_player): _find_player()
	if is_instance_valid(_promotion_button):
		_promotion_button.visible = ClassSystem.can_evolve_to("Oriental_Assassin") or ClassSystem.is_path_shadow_unlocked()
		_promotion_button.text = "تفعيل Path of Shadow" if ClassSystem.current_class == "Archer" else "العودة إلى الآرتشر"
	_refresh_active_skillbar()
	if is_instance_valid(_xp_skill_bar):
		_xp_skill_bar.value = ClassSystem.xp_skill
	if is_instance_valid(_stamina_bar):
		_stamina_bar.max_value = ClassSystem.max_stamina
		_stamina_bar.value = ClassSystem.stamina
	for i in range(mini(_skill_buttons.size(), _skill_ids.size())):
		var cooldown := float(_player.call("get_skill_cooldown", _skill_ids[i])) if is_instance_valid(_player) and _player.has_method("get_skill_cooldown") else 0.0
		var can_use := bool(_player.call("can_use_skill", _skill_ids[i])) if is_instance_valid(_player) and _player.has_method("can_use_skill") else false
		_skill_buttons[i].disabled = not can_use
		var labels := ["JUMP", "FLY", "SCATTER", "SHADOW", "XP"] if ClassSystem.current_class == "Archer" else ["JUMP", "RAPID", "SPARK", "SHADOW", "XP"]
		_skill_buttons[i].text = "%s\n%.1f" % [labels[i], cooldown] if cooldown > 0.0 else labels[i]
		var cost_label := str(SKILL_COST_LABELS.get(_skill_ids[i], ""))
		_skill_buttons[i].tooltip_text = "%s | %s | CD %.1fs" % [_skill_ids[i], cost_label, cooldown]

func _refresh_stats() -> void:
	if not is_instance_valid(_root):
		return
	var profile: Dictionary = GameState.profile
	var max_hp := maxi(1, ClassSystem.max_hp)
	var max_mp := maxi(1, ClassSystem.max_mp)
	_hp_bar.max_value = max_hp
	_hp_bar.value = clampi(ClassSystem.hp, 0, max_hp)
	_mp_bar.max_value = max_mp
	_mp_bar.value = clampi(ClassSystem.mp, 0, max_mp)
	var level := maxi(1, ClassSystem.level)
	_xp_bar.max_value = ClassSystem.get_required_xp()
	_xp_bar.value = ClassSystem.experience


func _minimize_chat() -> void:
	_chat_window.hide()
	_chat_restore_button.show()


func _restore_chat() -> void:
	_chat_window.show()
	_chat_restore_button.hide()


func push_simulated_chat(message: String, channel: String = "عام") -> void:
	if not is_instance_valid(_chat_log):
		return
	var tint := "#e8d7b0" if channel == "عام" else "#83d9a8"
	_chat_log.append_text("\n[color=%s]%s [/color]%s" % [tint,channel,message])

func _get_equipment_plus_max() -> int:
	var best := 0
	var equipment: Dictionary = GearSystem.get("equipment")
	for slot in equipment:
		var item = equipment[slot]
		if item is Dictionary:
			best = maxi(best,int(item.get("plus",0)))
	return best

func _on_bot_milestone_check() -> void:
	var current_class := str(ClassSystem.current_class)
	if current_class == "Oriental_Assassin" and _last_bot_milestone_class != "Oriental_Assassin" and ClassSystem.level >= 40:
		_push_bot_milestone("assassin_promotion")
	_last_bot_milestone_class = current_class
	var current_plus := _get_equipment_plus_max()
	if current_plus >= 12 and _last_bot_milestone_plus < 12:
		_push_bot_milestone("gear_plus_12")
	elif current_plus >= 9 and _last_bot_milestone_plus < 9:
		_push_bot_milestone("gear_plus_9")
	_last_bot_milestone_plus = current_plus

func _push_bot_milestone(milestone: String) -> void:
	var roster_script := load("res://src/scripts/VirtualPlayerRoster.gd")
	var roster = roster_script.new()
	for message in roster.record_player_milestone(milestone):
		push_simulated_chat(message,"عام")

func _on_chat_submitted(message: String) -> void:
	var clean_message := message.strip_edges()
	if clean_message.is_empty():
		return
	_chat_log.append_text("\n[color=#e8d7b0][عام] [/color]" + clean_message)
	_chat_input.clear()


func _panel_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _solid_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, color)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 128
	texture.height = 128
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2.RIGHT
	return texture

func _build_step12_widgets() -> void:
	_quest_ui=load("res://src/scenes/QuestUI.tscn").instantiate(); _shop_ui=load("res://src/scenes/ShopUI.tscn").instantiate(); _mall_ui=load("res://src/scenes/ShoppingMallUI.tscn").instantiate(); _warehouse_ui=load("res://src/scenes/WarehouseUI.tscn").instantiate()
	add_child(_quest_ui); add_child(_shop_ui); add_child(_mall_ui); add_child(_warehouse_ui)
	_guild_ui = load("res://src/scenes/GuildUI.tscn").instantiate() as CanvasLayer
	add_child(_guild_ui)
	# Quest, warehouse, mall and NPC interaction are exposed in the classic bottom bar.
func _interact_nearest_npc() -> void:
	if not is_instance_valid(_player): _find_player()
	if not is_instance_valid(_player): return
	var nearest:Node=null; var best:=4.5
	for npc in get_tree().get_nodes_in_group("npcs"):
		var d:=_player.global_position.distance_to(npc.global_position)
		if d<best: best=d; nearest=npc
	if is_instance_valid(nearest): nearest.call("interact")
func on_npc_interacted(role:String) -> void:
	if role == "guild_director" and is_instance_valid(_guild_ui):
		_guild_ui.call("open_ui")
	elif role=="warehouseman": _warehouse_ui.call("toggle")
	elif role in ["blacksmith","armorer","pharmacist","class_trainer"]: _shop_ui.call("open_shop",role)

extends CanvasLayer
var _system: Node
var _window: PanelContainer
var _tabs: TabContainer
var _status: Label
var _guild_name_input: LineEdit
var _donation_input: LineEdit
var _bulletin_input: LineEdit
var _guild_select: OptionButton
var _members_list: ItemList
var _guild_list: ItemList
var _overview_label: RichTextLabel
var _war_label: RichTextLabel

func _ready() -> void:
	visible = false
	_build_ui()
	_connect_system()
	refresh()

func _process(_delta: float) -> void:
	if not is_instance_valid(_system):
		_connect_system()

func _connect_system() -> void:
	_system = get_tree().get_first_node_in_group("guild_system")
	if not is_instance_valid(_system): return
	if not _system.guild_changed.is_connected(refresh):
		_system.guild_changed.connect(refresh)
	if not _system.guild_chat.is_connected(_on_guild_chat):
		_system.guild_chat.connect(_on_guild_chat)

func toggle() -> void:
	visible = not visible
	if visible: refresh()

func open_ui() -> void:
	visible = true
	refresh()

func _build_ui() -> void:
	_window = PanelContainer.new()
	_window.name = "GuildWindow"
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.position = Vector2(-390,-270)
	_window.size = Vector2(780,540)
	_window.add_theme_stylebox_override("panel",_style(Color(0.055,0.065,0.085,0.98),Color(0.76,0.55,0.25)))
	add_child(_window)
	var layout := VBoxContainer.new()
	_window.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "CLASSIC GUILD HALL  |  العشائر"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "X"
	close.pressed.connect(func(): visible = false)
	header.add_child(close)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_tabs)
	_build_overview_tab()
	_build_members_tab()
	_build_diplomacy_tab()
	_build_war_tab()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(_status)

func _build_overview_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Overview"
	_tabs.add_child(page)
	_overview_label = RichTextLabel.new()
	_overview_label.bbcode_enabled = true
	_overview_label.custom_minimum_size = Vector2(0,170)
	page.add_child(_overview_label)
	var create_row := HBoxContainer.new()
	page.add_child(create_row)
	_guild_name_input = LineEdit.new()
	_guild_name_input.placeholder_text = "Guild name (level 40+, 1,000,000 Gold)"
	create_row.add_child(_guild_name_input)
	var create_button := Button.new()
	create_button.text = "تأسيس عشيرة"
	create_button.pressed.connect(_create_guild)
	create_row.add_child(create_button)
	var bulletin_row := HBoxContainer.new()
	page.add_child(bulletin_row)
	_bulletin_input = LineEdit.new()
	_bulletin_input.placeholder_text = "Guild bulletin (Leader only)"
	bulletin_row.add_child(_bulletin_input)
	var bulletin_button := Button.new()
	bulletin_button.text = "حفظ الرسالة"
	bulletin_button.pressed.connect(_save_bulletin)
	bulletin_row.add_child(bulletin_button)
	var donate_row := HBoxContainer.new()
	page.add_child(donate_row)
	_donation_input = LineEdit.new()
	_donation_input.placeholder_text = "Gold donation amount"
	_donation_input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	donate_row.add_child(_donation_input)
	var donate_button := Button.new()
	donate_button.text = "تبرع"
	donate_button.pressed.connect(_donate)
	donate_row.add_child(donate_button)
	var challenge := Button.new()
	challenge.text = "Challenge Guild Leader"
	challenge.pressed.connect(_challenge)
	page.add_child(challenge)

func _build_members_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Members"
	_tabs.add_child(page)
	_members_list = ItemList.new()
	_members_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_members_list)

func _build_diplomacy_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Guilds & Diplomacy"
	_tabs.add_child(page)
	_guild_select = OptionButton.new()
	page.add_child(_guild_select)
	var actions := HBoxContainer.new()
	page.add_child(actions)
	var join := Button.new()
	join.text = "طلب الانضمام"
	join.pressed.connect(_join_selected)
	actions.add_child(join)
	var ally := Button.new()
	ally.text = "Ally"
	ally.pressed.connect(func(): _set_relation("Ally"))
	actions.add_child(ally)
	var enemy := Button.new()
	enemy.text = "Enemy"
	enemy.pressed.connect(func(): _set_relation("Enemy"))
	actions.add_child(enemy)
	var neutral := Button.new()
	neutral.text = "Neutral"
	neutral.pressed.connect(func(): _set_relation("Neutral"))
	actions.add_child(neutral)
	_guild_list = ItemList.new()
	_guild_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_guild_list)

func _build_war_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Guild War"
	_tabs.add_child(page)
	_war_label = RichTextLabel.new()
	_war_label.custom_minimum_size = Vector2(0,220)
	page.add_child(_war_label)
	var start := Button.new()
	start.text = "دخول ساحة حرب العشائر"
	start.pressed.connect(_start_war)
	page.add_child(start)

func refresh() -> void:
	if not is_instance_valid(_system): return
	var guild_name := str(_system.get("player_guild_name"))
	var guild: Dictionary = _system.call("get_player_guild")
	var buffs: Dictionary = _system.call("get_guild_buffs")
	if guild_name.is_empty():
		_overview_label.text = "[b]أنت بلا عشيرة.[/b]\nالمستوى الحالي: %d\nالانضمام متاح للعشائر القائمة. التأسيس يتطلب المستوى 40 ومليون ذهب." % ClassSystem.level
	else:
		var leader := "غير معروف"
		for member in _system.call("get_members",guild_name):
			if str(member.get("guild_rank","")) == "Guild Leader": leader = str(member.get("name","")); break
		_overview_label.text = "[b]%s[/b]\nالقائد: %s\nرتبتك: %s\nتبرعاتك: %s Gold\nصندوق العشيرة: %s Gold\nالرسالة: %s\n[b]Guild Buffs[/b] Attack +%.1f%% | Defense +%.1f%% | XP +%.1f%%" % [guild_name,leader,str(_system.get("player_guild_rank")),_format_gold(int(_system.get("player_guild_donation"))),_format_gold(int(guild.get("guild_fund",0))),str(guild.get("bulletin","")),float(buffs.attack_pct)*100.0,float(buffs.defense_pct)*100.0,float(buffs.xp_pct)*100.0]
		_bulletin_input.text = str(guild.get("bulletin",""))
	_members_list.clear()
	if not guild_name.is_empty():
		for member in _system.call("get_members",guild_name):
			var online := "Online" if bool(member.get("online",false)) else "Offline"
			_members_list.add_item("%s  | Lv.%d | %s | Donate %s | %s" % [str(member.get("name","")),int(member.get("level",1)),str(member.get("guild_rank","Member")),_format_gold(int(member.get("guild_donation",0))),online])
	_guild_select.clear()
	_guild_list.clear()
	for name in _system.call("get_guild_names"):
		_guild_select.add_item(str(name))
		var data: Dictionary = _system.call("get_guild",str(name))
		_guild_list.add_item("%s | Fund %s | Allies %d | Enemies %d" % [str(name),_format_gold(int(data.get("guild_fund",0))),Array(data.get("allies",[])).size(),Array(data.get("enemies",[])).size()])
	_war_label.text = "[b]المسيطرة حالياً:[/b] %s\n[b]فوزك السابق:[/b] %s\n[b]Buffs:[/b] Attack %.1f%% | Defense %.1f%% | XP %.1f%%\n\nدمّر البوابتين لفتح العمود المركزي. أعلى مساهمة ضرر عند سقوط Guild Pole تحدد الفائز." % [str(_system.call("get_war_winner")),str(GameState.profile.get("guild_war_title","—")),float(buffs.attack_pct)*100.0,float(buffs.defense_pct)*100.0,float(buffs.xp_pct)*100.0]

func _create_guild() -> void:
	_set_status("تعذر التأسيس. تأكد من المستوى 40، الاسم غير مستخدم، وامتلاك مليون ذهب.") if not _system.call("create_guild",_guild_name_input.text) else _set_status("تم تأسيس العشيرة بقيادتك.")

func _donate() -> void:
	var amount := int(_donation_input.text)
	_set_status("تم التبرع بنجاح.") if _system.call("donate_gold",amount) else _set_status("تعذر التبرع؛ راجع الرصيد وعضوية العشيرة.")

func _save_bulletin() -> void:
	_set_status("تم تحديث الرسالة.") if _system.call("set_bulletin",_bulletin_input.text) else _set_status("تعديل الرسالة متاح للقائد فقط.")

func _challenge() -> void:
	_set_status("أصبحت قائد العشيرة!") if _system.call("challenge_guild_leader") else _set_status("التحدي غير مستحق بعد: يلزم التفوق على القائد في المستوى والتبرعات.")

func _join_selected() -> void:
	if _guild_select.item_count == 0: return
	_set_status("تم قبولك في العشيرة.") if _system.call("join_guild",_guild_select.get_item_text(_guild_select.selected)) else _set_status("لا يمكن الانضمام: أنت عضو بالفعل أو وصلت العشيرة للحد الأقصى.")

func _set_relation(relation: String) -> void:
	if _guild_select.item_count == 0: return
	_set_status("تم تحديث الدبلوماسية.") if _system.call("set_diplomacy",_guild_select.get_item_text(_guild_select.selected),relation) else _set_status("تعديل الدبلوماسية متاح لقائد العشيرة فقط.")

func _start_war() -> void:
	if str(_system.get("player_guild_name")).is_empty():
		_set_status("انضم إلى عشيرة أو أسس عشيرة أولاً.")
		return
	var world := get_tree().get_first_node_in_group("world_manager")
	if is_instance_valid(world):
		visible = false
		_system.call("set_war_active",true)
		world.call("change_settlement","GuildWarArena",false)

func _on_guild_chat(message: String) -> void:
	var hud := get_tree().get_first_node_in_group("game_hud")
	if is_instance_valid(hud): hud.call("push_simulated_chat",message,"عشيرة")

func _set_status(message: String) -> void:
	_status.text = message
	refresh()

func _format_gold(amount: int) -> String:
	var raw := str(maxi(0,amount)); var formatted := ""
	for index in range(raw.length()):
		if index > 0 and (raw.length()-index)%3 == 0: formatted += ","
		formatted += raw[index]
	return formatted

func _style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	return style

extends CanvasLayer
## Three-tab gold-only upgrade market. GearSystem owns all item mutation and persistence.

const SLOT_AR := {"RightHand":"اليد اليمنى", "LeftHand":"اليد اليسرى", "Armor":"الدرع", "Helmet":"الخوذة", "Necklace":"القلادة", "Boots":"الحذاء", "Ring":"الخاتم"}
const QUALITY_AR := {"Normal":"عادي", "Refined":"مُحسّن", "Unique":"فريد", "Elite":"نخبوي", "Super":"خارق"}
const GEM_AR := {"Dragon":"التنين", "Phoenix":"العنقاء", "Rainbow":"قوس قزح", "Violet":"البنفسجي", "Moon":"القمر", "Fury":"الغضب", "Kylin":"كيلين"}
const GEM_QUALITY_AR := {"Normal":"عادية", "Refined":"مُحسّنة", "Super":"خارقة"}

var _tabs: TabContainer
var _level_item: OptionButton
var _level_info: RichTextLabel
var _level_button: Button
var _quality_item: OptionButton
var _quality_info: RichTextLabel
var _quality_button: Button
var _compose_item: OptionButton
var _minor_one: OptionButton
var _minor_two: OptionButton
var _compose_progress: ProgressBar
var _compose_label: Label
var _compose_button: Button
var _socket_item: OptionButton
var _socket_info: RichTextLabel
var _socket_index: OptionButton
var _gem_choice: OptionButton
var _socket_button: Button
var _gem_button: Button
var _gold_label: Label
var _status: Label

func _ready() -> void:
	add_to_group("upgrade_market_ui")
	_build_ui()
	_connect_signals()
	_refresh_all()
	hide()

func toggle() -> void:
	if not visible:
		var inventory_ui := get_tree().get_first_node_in_group("inventory_ui")
		if is_instance_valid(inventory_ui) and inventory_ui.has_method("close"):
			inventory_ui.call("close")
		visible = true
		_refresh_all()
	else:
		visible = false

func open() -> void:
	show()
	_refresh_all()

func close() -> void:
	hide()

func _connect_signals() -> void:
	if not GearSystem.inventory_changed.is_connected(_refresh_all):
		GearSystem.inventory_changed.connect(_refresh_all)
	if not GearSystem.equipment_changed.is_connected(_refresh_all):
		GearSystem.equipment_changed.connect(_refresh_all)
	if not GearSystem.gear_operation_completed.is_connected(_on_operation_message):
		GearSystem.gear_operation_completed.connect(_on_operation_message)
	if not GlobalEconomy.gold_changed.is_connected(_on_gold_changed):
		GlobalEconomy.gold_changed.connect(_on_gold_changed)

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "MarketDim"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.012, 0.02, 0.84)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var frame := PanelContainer.new()
	frame.name = "UpgradeMarketFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 100
	frame.offset_top = 35
	frame.offset_right = -100
	frame.offset_bottom = -35
	frame.add_theme_stylebox_override("panel", _style(Color("#171b25"), Color("#c49a4a"), 3, 12))
	add_child(frame)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	frame.add_child(body)
	var header := HBoxContainer.new()
	body.add_child(header)
	var title := Label.new()
	title.text = "سوق تطوير العتاد"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#f3d18d"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label = Label.new()
	_gold_label.add_theme_color_override("font_color", Color("#f7d36f"))
	header.add_child(_gold_label)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_tabs = TabContainer.new()
	_tabs.name = "UpgradeTabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_tabs)
	_build_artisan_tab()
	_build_compose_tab()
	_build_socket_tab()

	_status = Label.new()
	_status.text = "اختر قطعة لبدء التطوير."
	_status.add_theme_color_override("font_color", Color("#e5d2a8"))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_status)

func _build_artisan_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "MagicArtisan"
	page.add_theme_constant_override("separation", 12)
	_tabs.add_child(page)
	_tabs.set_tab_title(0, "الحداد السحري")
	var intro := Label.new()
	intro.text = "ترقية المستوى والجودة — النجاح احتمالي، والفشل يخصم الذهب فقط."
	intro.add_theme_color_override("font_color", Color("#d6c39e"))
	page.add_child(intro)

	var level_panel := _section_panel("ترقية المستوى (Level Up)")
	page.add_child(level_panel)
	var lv_box := level_panel.get_child(0) as VBoxContainer
	_level_item = _new_item_option()
	lv_box.add_child(_labelled("القطعة المستهدفة", _level_item))
	_level_info = _new_rich_text()
	lv_box.add_child(_level_info)
	_level_button = Button.new()
	_level_button.text = "ترقية المستوى"
	_level_button.pressed.connect(_on_level_upgrade)
	lv_box.add_child(_level_button)

	var quality_panel := _section_panel("ترقية الجودة (Quality Up)")
	page.add_child(quality_panel)
	var q_box := quality_panel.get_child(0) as VBoxContainer
	_quality_item = _new_item_option()
	q_box.add_child(_labelled("القطعة المستهدفة", _quality_item))
	_quality_info = _new_rich_text()
	q_box.add_child(_quality_info)
	_quality_button = Button.new()
	_quality_button.text = "ترقية الجودة"
	_quality_button.pressed.connect(_on_quality_upgrade)
	q_box.add_child(_quality_button)
	_level_item.item_selected.connect(func(_index): _refresh_artisan())
	_quality_item.item_selected.connect(func(_index): _refresh_artisan())

func _build_compose_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "Composition"
	page.add_theme_constant_override("separation", 10)
	_tabs.add_child(page)
	_tabs.set_tab_title(1, "التوليف والبلس")
	var intro := Label.new()
	intro.text = "اختر قطعة رئيسية وحجرَي توليف كحد أقصى. لا يوجد كسر أو فقد للقطعة."
	intro.add_theme_color_override("font_color", Color("#d6c39e"))
	page.add_child(intro)
	_compose_item = _new_item_option()
	page.add_child(_labelled("Main Item — القطعة الرئيسية", _compose_item))
	var stones := HBoxContainer.new()
	page.add_child(stones)
	_minor_one = _new_stone_option()
	_minor_two = _new_stone_option()
	var minor_a := VBoxContainer.new()
	minor_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minor_a.add_child(_label_text("Minor Item 1"))
	minor_a.add_child(_minor_one)
	stones.add_child(minor_a)
	var minor_b := VBoxContainer.new()
	minor_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	minor_b.add_child(_label_text("Minor Item 2"))
	minor_b.add_child(_minor_two)
	stones.add_child(minor_b)

	var shop := HBoxContainer.new()
	page.add_child(shop)
	var buy_one := Button.new()
	buy_one.text = "شراء حجر +1 (1,000 ذهب)"
	buy_one.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_one.pressed.connect(func(): _buy_stone(1))
	shop.add_child(buy_one)
	var buy_two := Button.new()
	buy_two.text = "شراء حجر +2 (1,800 ذهب)"
	buy_two.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_two.pressed.connect(func(): _buy_stone(2))
	shop.add_child(buy_two)

	_compose_progress = ProgressBar.new()
	_compose_progress.min_value = 0
	_compose_progress.max_value = 1
	_compose_progress.show_percentage = false
	_compose_progress.custom_minimum_size.y = 25
	page.add_child(_compose_progress)
	_compose_label = _label_text("اختر القطعة الرئيسية لعرض نقاط التوليف.")
	page.add_child(_compose_label)
	_compose_button = Button.new()
	_compose_button.text = "توليف (Compose)"
	_compose_button.pressed.connect(_on_compose)
	page.add_child(_compose_button)
	_compose_item.item_selected.connect(func(_index): _refresh_compose())

func _build_socket_tab() -> void:
	var page := VBoxContainer.new()
	page.name = "ArtisanWind"
	page.add_theme_constant_override("separation", 10)
	_tabs.add_child(page)
	_tabs.set_tab_title(2, "صانع المقابس والجواهر")
	var intro := Label.new()
	intro.text = "افتح حتى مقبسين، ثم ركّب جوهرة أو استبدلها. الجوهرة القديمة تتلف عند الاستبدال."
	intro.add_theme_color_override("font_color", Color("#d6c39e"))
	page.add_child(intro)
	_socket_item = _new_item_option()
	page.add_child(_labelled("القطعة", _socket_item))
	_socket_info = _new_rich_text()
	page.add_child(_socket_info)
	_socket_button = Button.new()
	_socket_button.text = "فتح مقبس"
	_socket_button.pressed.connect(_on_open_socket)
	page.add_child(_socket_button)

	var gem_row := HBoxContainer.new()
	page.add_child(gem_row)
	_socket_index = OptionButton.new()
	_socket_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_socket_index.add_item("المقبس الأول")
	_socket_index.add_item("المقبس الثاني")
	gem_row.add_child(_socket_index)
	_gem_choice = OptionButton.new()
	_gem_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gem_row.add_child(_gem_choice)
	_gem_button = Button.new()
	_gem_button.text = "تركيب / استبدال الجوهرة"
	_gem_button.pressed.connect(_on_socket_gem)
	page.add_child(_gem_button)
	_socket_item.item_selected.connect(func(_index): _refresh_sockets())
	_socket_index.item_selected.connect(func(_index): _refresh_sockets())

func _section_panel(title_text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("#202631"), Color("#806b48"), 2, 8))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("#f0cf88"))
	box.add_child(title)
	return panel

func _labelled(caption: String, control: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(_label_text(caption))
	box.add_child(control)
	return box

func _label_text(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", Color("#d8c49c"))
	return label

func _new_item_option() -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return option

func _new_stone_option() -> OptionButton:
	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return option

func _new_rich_text() -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.custom_minimum_size.y = 58
	return rich

func _refresh_all() -> void:
	_gold_label.text = "الذهب: %s" % _format_gold(GlobalEconomy.current_gold)
	_refresh_item_options()
	_refresh_stone_options()
	_refresh_gem_options()
	_refresh_artisan()
	_refresh_compose()
	_refresh_sockets()

func _refresh_item_options() -> void:
	for option in [_level_item, _quality_item, _compose_item, _socket_item]:
		var previous := _selected_instance(option)
		option.clear()
		for entry in _get_upgrade_items():
			var item: Dictionary = entry["item"]
			var label := "%s  (+%d | %s)" % [str(item.get("name", item.get("id", "قطعة"))), int(item.get("plus", 0)), str(item.get("quality", "Normal"))]
			option.add_item(label)
			option.set_item_metadata(option.item_count - 1, str(item.get("instance_id", "")))
			if str(item.get("instance_id", "")) == previous:
				option.select(option.item_count - 1)
		if option.item_count > 0 and option.selected < 0:
			option.select(0)

func _get_upgrade_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in GearSystem.inventory:
		if str(item.get("item_type", "")) in ["gem", "plus_stone"]:
			continue
		result.append({"item": item, "equipped": false})
	for slot in GearSystem.equipment:
		var item: Dictionary = GearSystem.equipment[slot]
		if not item.is_empty():
			result.append({"item": item, "equipped": true, "slot": slot})
	return result

func _refresh_stone_options() -> void:
	for option in [_minor_one, _minor_two]:
		var previous := _selected_instance(option)
		option.clear()
		option.add_item("— بدون حجر —")
		option.set_item_metadata(0, "")
		for item in GearSystem.inventory:
			if str(item.get("item_type", "")) == "plus_stone" and int(item.get("quantity", 0)) > 0:
				option.add_item("%s ×%d" % [str(item.get("name", "Plus Stone")), int(item.get("quantity", 1))])
				option.set_item_metadata(option.item_count - 1, str(item.get("instance_id", "")))
				if str(item.get("instance_id", "")) == previous:
					option.select(option.item_count - 1)
		if option.selected < 0:
			option.select(0)

func _refresh_gem_options() -> void:
	var previous := ""
	if _gem_choice.item_count > 0 and _gem_choice.selected >= 0:
		previous = str(_gem_choice.get_item_metadata(_gem_choice.selected))
	_gem_choice.clear()
	for gem_id in GearDatabase.get_all_gem_ids():
		var parts := str(gem_id).split("_")
		var title := "%s — %s" % [GEM_AR.get(parts[0], parts[0]), GEM_QUALITY_AR.get(parts[1], parts[1])]
		var quantity := _gem_quantity(str(gem_id))
		if quantity > 0:
			_gem_choice.add_item("%s ×%d" % [title, quantity])
			_gem_choice.set_item_metadata(_gem_choice.item_count - 1, gem_id)
			if gem_id == previous:
				_gem_choice.select(_gem_choice.item_count - 1)
	if _gem_choice.item_count > 0 and _gem_choice.selected < 0:
		_gem_choice.select(0)

func _refresh_artisan() -> void:
	var level_id := _selected_instance(_level_item)
	var level_item := GearSystem.get_item_by_instance_id(level_id)
	if level_item.is_empty():
		_level_info.text = "لا توجد قطعة متاحة."
		_level_button.disabled = true
	else:
		var level := int(level_item.get("required_level", 15))
		var tier := GearDatabase.LEVEL_TIERS.find(level)
		var can_level := tier >= 0 and tier < GearDatabase.LEVEL_TIERS.size() - 1
		var cost := int(GearSystem.LEVEL_UPGRADE_COSTS.get(level, 0))
		var rate := float(GearSystem.LEVEL_UPGRADE_RATES.get(level, 0.0)) * 100.0
		var next_level := GearDatabase.LEVEL_TIERS[tier + 1] if can_level else level
		_level_info.text = "[b]%s[/b]\nالمستوى الحالي: %d  ←  التالي: %d\nالتكلفة: %s ذهب  |  النجاح: %.0f%%" % [str(level_item.get("name", "قطعة")), level, next_level, _format_gold(cost), rate]
		_level_button.disabled = not can_level or cost <= 0 or GlobalEconomy.current_gold < cost

	var quality_id := _selected_instance(_quality_item)
	var quality_item := GearSystem.get_item_by_instance_id(quality_id)
	if quality_item.is_empty():
		_quality_info.text = "لا توجد قطعة متاحة."
		_quality_button.disabled = true
	else:
		var next_quality := GearDatabase.get_quality_upgrade(str(quality_item.get("quality", "Normal")))
		if next_quality.is_empty():
			_quality_info.text = "وصلت القطعة إلى أعلى جودة: Super."
			_quality_button.disabled = true
		else:
			_quality_info.text = "[b]%s[/b]\nالجودة: %s  ←  %s\nالتكلفة: %s ذهب  |  النجاح: %.0f%%\nالفشل يخصم الذهب فقط." % [
				str(quality_item.get("name", "قطعة")), QUALITY_AR.get(str(quality_item["quality"]), str(quality_item["quality"])),
				QUALITY_AR.get(str(next_quality["quality"]), str(next_quality["quality"])),
				_format_gold(int(next_quality["cost"])), float(next_quality["chance"]) * 100.0
			]
			_quality_button.disabled = GlobalEconomy.current_gold < int(next_quality["cost"])

func _refresh_compose() -> void:
	var item := GearSystem.get_item_by_instance_id(_selected_instance(_compose_item))
	var progress := GearSystem.get_compose_progress(str(item.get("instance_id", ""))) if not item.is_empty() else {}
	if progress.is_empty():
		_compose_progress.value = 0
		_compose_progress.max_value = 1
		_compose_label.text = "اختر قطعة رئيسية."
		_compose_button.disabled = true
		return
	var required := int(progress["required"])
	var current := int(progress["current"])
	_compose_progress.max_value = maxf(1.0, float(required))
	_compose_progress.value = minf(float(current), float(required))
	_compose_label.text = "البلس +%d  |  نقاط التوليف: %d / %d  |  رسوم المحاولة: %s ذهب" % [int(progress["plus"]), current, required, _format_gold(GearSystem.COMPOSE_GOLD_COST)]
	_compose_button.disabled = required <= 0 or GlobalEconomy.current_gold < GearSystem.COMPOSE_GOLD_COST or (_selected_instance(_minor_one).is_empty() and _selected_instance(_minor_two).is_empty())

func _refresh_sockets() -> void:
	var item := GearSystem.get_item_by_instance_id(_selected_instance(_socket_item))
	if item.is_empty():
		_socket_info.text = "اختر قطعة لعرض المقابس."
		_socket_button.disabled = true
		_gem_button.disabled = true
		return
	var count := int(item.get("socket_count", item.get("sockets", []).size()))
	var sockets: Array = item.get("sockets", [])
	var first := str(sockets[0]) if count > 0 and sockets.size() > 0 else "مغلق"
	var second := str(sockets[1]) if count > 1 and sockets.size() > 1 else "مغلق"
	_socket_info.text = "[b]%s[/b]\nالمقابس المفتوحة: %d / 2\nالمقبس 1: %s\nالمقبس 2: %s" % [str(item.get("name", "قطعة")), count, first, second]
	_socket_button.text = "فتح المقبس التالي (%s ذهب)" % _format_gold(GearSystem.SOCKET_OPEN_COSTS[count]) if count < 2 else "اكتمل فتح المقبسين"
	_socket_button.disabled = count >= 2 or GlobalEconomy.current_gold < GearSystem.SOCKET_OPEN_COSTS[count]
	var selected_socket := _socket_index.selected
	_gem_button.disabled = count <= selected_socket or _gem_choice.item_count == 0 or GlobalEconomy.current_gold < GearSystem.GEM_SOCKET_COST

func _selected_instance(option: OptionButton) -> String:
	if not is_instance_valid(option) or option.item_count == 0 or option.selected < 0:
		return ""
	return str(option.get_item_metadata(option.selected))

func _on_level_upgrade() -> void:
	var id := _selected_instance(_level_item)
	if id.is_empty():
		return
	GearSystem.upgrade_item_level_by_id(id)
	_refresh_all()

func _on_quality_upgrade() -> void:
	var id := _selected_instance(_quality_item)
	if id.is_empty():
		return
	GearSystem.upgrade_quality_by_id(id)
	_refresh_all()

func _buy_stone(level: int) -> void:
	if GearSystem.buy_plus_stone(level):
		_set_status("تمت إضافة حجر التوليف إلى الحقيبة.")
	_refresh_all()

func _on_compose() -> void:
	var main_id := _selected_instance(_compose_item)
	var minors: Array[String] = []
	var one := _selected_instance(_minor_one)
	var two := _selected_instance(_minor_two)
	if not one.is_empty():
		minors.append(one)
	if not two.is_empty():
		minors.append(two)
	if GearSystem.compose_item(main_id, minors):
		_set_status("تم استهلاك أحجار التوليف وتحديث القطعة.")
	_refresh_all()

func _on_open_socket() -> void:
	var id := _selected_instance(_socket_item)
	if id.is_empty():
		return
	GearSystem.open_socket_by_id(id)
	_refresh_all()

func _on_socket_gem() -> void:
	var id := _selected_instance(_socket_item)
	if id.is_empty() or _gem_choice.item_count == 0 or _gem_choice.selected < 0:
		return
	var gem_id := str(_gem_choice.get_item_metadata(_gem_choice.selected))
	GearSystem.socket_gem_by_id(id, _socket_index.selected, gem_id)
	_refresh_all()

func _gem_quantity(gem_id: String) -> int:
	for item in GearSystem.inventory:
		if str(item.get("gem_id", "")) == gem_id:
			return int(item.get("quantity", 0))
	return 0

func _on_operation_message(message: String) -> void:
	_set_status(message)
	_refresh_all()

func _on_gold_changed(amount: int) -> void:
	_gold_label.text = "الذهب: %s" % _format_gold(amount)
	_refresh_all()

func _set_status(message: String) -> void:
	_status.text = message

func _format_gold(amount: int) -> String:
	var raw := str(maxi(0, amount))
	var output := ""
	for i in range(raw.length()):
		if i > 0 and (raw.length() - i) % 3 == 0:
			output += ","
		output += raw[i]
	return output

func _style(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

extends Control
## Classic character status window backed by local character and gear data.
var _labels: Dictionary = {}
var _promote: Button

func _ready() -> void:
	name = "CharacterStatusUI"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.position = Vector2(24,36)
	panel.size = Vector2(440,590)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel",_panel_style())
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",5)
	panel.add_child(body)
	var heading := Label.new()
	heading.text = "CHARACTER STATUS  |  حالة الشخصية"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color",Color(1.0,0.82,0.46))
	body.add_child(heading)
	for key in ["name","class","title","level","hp","mp","pk","strength","agility","vitality","spirit","attack","defense","magic_attack","magic_defense","dodge","battle_power"]:
		var label := Label.new()
		label.add_theme_color_override("font_color",Color(0.9,0.86,0.77))
		body.add_child(label)
		_labels[key] = label
	_promote = Button.new()
	_promote.text = "PROMOTE"
	_promote.pressed.connect(_on_promote)
	body.add_child(_promote)
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(func(): hide())
	body.add_child(close)
	ClassSystem.stats_changed.connect(refresh)
	ClassSystem.character_changed.connect(refresh)
	GearSystem.equipment_changed.connect(refresh)
	refresh()
	hide()

func toggle() -> void:
	visible = not visible
	if visible: refresh()

func refresh() -> void:
	if not is_instance_valid(_promote): return
	var profile: Dictionary = GameState.profile
	var attrs: Dictionary = ClassSystem.attributes
	var gems: Dictionary = GearSystem.get_equipment_bonus()
	var gear_stats := {"physical_attack":0.0,"magic_attack":0.0,"defense":0.0,"magic_defense":0.0}
	for slot in GearSystem.equipment:
		var item: Dictionary = GearSystem.equipment[slot]
		if item.is_empty(): continue
		var final_stats: Dictionary = GearSystem.get_item_final_stats(item)
		for stat in gear_stats:
			gear_stats[stat] = float(gear_stats[stat]) + float(final_stats.get(stat,0.0))
	var physical := float(ClassSystem.get_physical_attack_bonus()) + float(gear_stats.physical_attack)
	var attack_pct := float(gems.get("physical_attack_pct",0.0))
	var min_attack := int(round(physical*(1.0+attack_pct/100.0)))
	var max_attack := int(round((physical+12.0+float(attrs.agility)*0.15)*(1.0+attack_pct/100.0)))
	var magic_attack := int(round((float(attrs.spirit)*2.0+float(gear_stats.magic_attack))*(1.0+float(gems.get("magic_attack_pct",0.0))/100.0)))
	var defense := int(round((float(attrs.vitality)*2.0+float(gear_stats.defense))*(1.0+float(gems.get("defense_pct",0.0))/100.0)))
	var magic_defense := int(round((float(attrs.spirit)+float(attrs.vitality)*0.5+float(gear_stats.magic_defense))*(1.0+float(gems.get("magic_defense_pct",0.0))/100.0)))
	var dodge := float(attrs.agility)*0.15+float(gems.get("dodge_pct",0.0))
	var potency := ClassSystem.level*2+int(attrs.strength)+int(attrs.agility)+int(attrs.vitality)+int(attrs.spirit)+min_attack+defense+magic_defense
	_set_stat_text("name","الاسم: %s" % str(profile.get("character_name","Player")))
	_set_stat_text("class","الفئة: %s" % ClassSystem.get_class_name_ar())
	_set_stat_text("title","الرتبة: %s" % ClassSystem.get_title())
	_set_stat_text("level","المستوى: %d" % ClassSystem.level)
	_set_stat_text("hp","HP: %d / %d" % [ClassSystem.hp,ClassSystem.max_hp])
	_set_stat_text("mp","MP: %d / %d" % [ClassSystem.mp,ClassSystem.max_mp])
	_set_stat_text("pk","PK: %s" % str(profile.get("pk_points",0)))
	_set_stat_text("strength","Strength: %d" % int(attrs.strength))
	_set_stat_text("agility","Agility: %d" % int(attrs.agility))
	_set_stat_text("vitality","Vitality: %d" % int(attrs.vitality))
	_set_stat_text("spirit","Spirit: %d" % int(attrs.spirit))
	_set_stat_text("attack","الهجوم الفيزيائي: %d - %d" % [min_attack,max_attack])
	_set_stat_text("defense","الدفاع الفيزيائي: %d" % defense)
	_set_stat_text("magic_attack","الهجوم السحري: %d" % magic_attack)
	_set_stat_text("magic_defense","الدفاع السحري: %d" % magic_defense)
	_set_stat_text("dodge","التفادي: %.1f%%" % dodge)
	_set_stat_text("battle_power","Battle Power / Potency: %d" % potency)
	_promote.disabled = not ClassSystem.can_promote()
	_promote.text = "PROMOTE — المستوى %d" % ClassSystem.get_next_promotion_reward_level() if not _promote.disabled else "لا توجد ترقية متاحة"

func _set_stat_text(key: String, value: String) -> void:
	if _labels.has(key): _labels[key].text = value

func _on_promote() -> void:
	if ClassSystem.promote(): refresh()

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.045,0.06,0.97)
	style.border_color = Color(0.78,0.57,0.29)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

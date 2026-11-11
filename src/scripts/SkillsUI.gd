extends Control
## Independent classic skill book with per-skill proficiency progress.
const SKILL_NAMES := {"Jump":"Classic Jump","Fly":"Fly","Scatter":"Scatter","Rapid_Fire":"Rapid Fire","Kinetic_Spark":"Kinetic Spark","Path_of_Shadow":"Path of Shadow","Double_Slash":"Double Slash","XP_Mode":"XP Skill"}
const CLASS_SKILLS := {
	"Archer":["Jump","Fly","Scatter","Path_of_Shadow","XP_Mode"],
	"Oriental_Assassin":["Jump","Rapid_Fire","Kinetic_Spark","Path_of_Shadow","Double_Slash","XP_Mode"],
	"Trojan":["Jump","Double_Slash","XP_Mode"],"Warrior":["Jump","Double_Slash","XP_Mode"],
	"Water_Taoist":["Jump","XP_Mode"],"Fire_Taoist":["Jump","XP_Mode"],"Ninja":["Jump","Double_Slash","XP_Mode"]
}
var _list: VBoxContainer

func _ready() -> void:
	name = "SkillsUI"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	panel.position = Vector2(480,36)
	panel.size = Vector2(400,520)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.045,0.06,0.97)
	style.border_color = Color(0.78,0.57,0.29)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	var heading := Label.new()
	heading.text = "SKILL BOOK  |  كتاب المهارات"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color",Color(1.0,0.82,0.46))
	body.add_child(heading)
	_list = VBoxContainer.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_list)
	var close := Button.new()
	close.text = "إغلاق"
	close.pressed.connect(func(): hide())
	body.add_child(close)
	ClassSystem.stats_changed.connect(refresh)
	ClassSystem.character_changed.connect(refresh)
	refresh()
	hide()

func toggle() -> void:
	visible = not visible
	if visible: refresh()

func refresh() -> void:
	if not is_instance_valid(_list): return
	for child in _list.get_children(): child.queue_free()
	for skill_id in CLASS_SKILLS.get(ClassSystem.current_class,["Jump","XP_Mode"]):
		var data := ClassSystem.get_skill_proficiency(skill_id)
		var skill_level := int(data.get("level",1))
		var xp := int(data.get("xp",0))
		var required := maxi(1,skill_level*20)
		var row := HBoxContainer.new()
		var icon := Label.new()
		icon.text = {"Jump":"↟","Fly":"✦","Scatter":"❖","Rapid_Fire":"➶","Kinetic_Spark":"⚡","Path_of_Shadow":"◈","Double_Slash":"⚔","XP_Mode":"★"}.get(skill_id,"✧")
		icon.custom_minimum_size.x = 34
		row.add_child(icon)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.text = "%s  Lv.%d" % [str(SKILL_NAMES.get(skill_id,skill_id)),skill_level]
		details.add_child(title)
		var progress := ProgressBar.new()
		progress.min_value = 0
		progress.max_value = required
		progress.value = xp
		progress.show_percentage = false
		progress.custom_minimum_size.y = 12
		details.add_child(progress)
		var percent := Label.new()
		percent.text = "Skill XP: %d%%" % int(round(float(xp)/float(required)*100.0))
		details.add_child(percent)
		row.add_child(details)
		_list.add_child(row)

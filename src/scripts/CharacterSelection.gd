extends Control
## Runtime-generated Arabic-first selector for every classic base class.
signal character_confirmed(character_data: Dictionary)
const WORLD_SCENE := "res://scenes/main.tscn"
const CLASS_CHOICES := [
	{"id":"Archer","ar":"الآرتشر","en":"Archer","style":"قوس وهجمات بعيدة المدى"},
	{"id":"Trojan","ar":"التروجان","en":"Trojan","style":"قتال جسدي مباشر"},
	{"id":"Warrior","ar":"المحارب","en":"Warrior","style":"دفاع وتحمل مرتفع"},
	{"id":"Water_Taoist","ar":"حاوي الماء","en":"Water Taoist","style":"سحر الماء والدعم"},
	{"id":"Fire_Taoist","ar":"حاوي النار","en":"Fire Taoist","style":"هجمات سحرية نارية"},
	{"id":"Ninja","ar":"النينجا","en":"Ninja","style":"قتال سريع بالسيوف"}
]
var selected_class := "Archer"
var _class_buttons: Dictionary = {}
@onready var name_input: LineEdit = $Character_Data_Panel/PanelContent/PlayerNameInput
@onready var start_button: Button = $Character_Data_Panel/PanelContent/StartGameButton
@onready var details_label: Label = $Character_Data_Panel/PanelContent/ClassDetails
@onready var gallery: ScrollContainer = $ClassGallery
@onready var class_track: HBoxContainer = $ClassGallery/ClassTrack

func _ready() -> void:
	_setup_landscape_layout()
	_build_class_cards()
	_select_class("Archer")
	start_button.pressed.connect(_on_start_game_pressed)
	name_input.text_submitted.connect(func(_value: String) -> void: _on_start_game_pressed())
	name_input.grab_focus()

func _setup_landscape_layout() -> void:
	get_viewport().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	gallery.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	gallery.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func _build_class_cards() -> void:
	for child in class_track.get_children():
		class_track.remove_child(child)
		child.free()
	for entry in CLASS_CHOICES:
		var card := PanelContainer.new()
		card.name = str(entry["id"]) + "Card"
		card.custom_minimum_size = Vector2(220, 250)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 12)
		card.add_child(content)
		var title := Label.new()
		title.text = "%s\n%s" % [str(entry["ar"]), str(entry["en"])]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.size_flags_vertical = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
		content.add_child(title)
		var style := Label.new()
		style.text = str(entry["style"])
		style.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		style.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(style)
		var button := Button.new()
		button.text = "اختيار الفئة"
		button.toggle_mode = true
		button.pressed.connect(_select_class.bind(str(entry["id"])))
		content.add_child(button)
		_class_buttons[str(entry["id"])] = button
		class_track.add_child(card)

func _select_class(class_id: String) -> void:
	if not ClassSystem.CLASS_DATA.has(class_id): return
	selected_class = class_id
	for key in _class_buttons:
		var button: Button = _class_buttons[key]
		button.button_pressed = key == class_id
	var data: Dictionary = ClassSystem.CLASS_DATA[class_id]
	var stats: Dictionary = data["base"]
	details_label.text = "الفئة: %s — %s\nSTR %d  AGI %d  VIT %d  SPI %d\nتُمنح 3 نقاط خصائص مع كل مستوى. مراحل الترقية: 15 / 40 / 70 / 100 / 110." % [str(data["name_ar"]),str(data["name"]),int(stats["strength"]),int(stats["agility"]),int(stats["vitality"]),int(stats["spirit"])]

func _on_start_game_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		name_input.placeholder_text = "اكتب اسم الشخصية أولاً"
		name_input.grab_focus()
		return
	if player_name.length() > 20: player_name = player_name.substr(0, 20)
	if not ClassSystem.choose_class(selected_class):
		push_error("CharacterSelection: class selection was rejected: " + selected_class)
		return
	GameState.profile["character_name"] = player_name
	GameState.profile["class_id"] = selected_class
	GameState.profile["class_level"] = ClassSystem.level
	GameState.profile["level"] = ClassSystem.level
	GameState.profile["experience"] = ClassSystem.experience
	GameState.profile["combat_profile"] = {"class_id":selected_class,"display_name":ClassSystem.get_class_name(),"weapon_families":ClassSystem.CLASS_DATA[selected_class]["weapon_families"].duplicate()}
	if not GameState.save_local():
		push_error("CharacterSelection: failed to save the local character profile.")
		return
	GlobalEconomy.save_gold()
	character_confirmed.emit({"character_name":player_name,"class_id":selected_class,"class_level":ClassSystem.level,"combat_profile":GameState.profile["combat_profile"]})
	var error := get_tree().change_scene_to_file(WORLD_SCENE)
	if error != OK: push_error("CharacterSelection: Could not open world scene. Error: %s" % error)

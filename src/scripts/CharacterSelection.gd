extends Control
## Landscape character selection. Art slots are intentionally texture-ready placeholders.

signal character_confirmed(character_data: Dictionary)

const WORLD_SCENE := "res://scenes/main.tscn"
const ASSASSIN_PROMOTION_LEVEL := 70

const CLASS_DATA := {
	"archer": {
		"display_name": "Archer",
		"arabic_name": "الارتشر",
		"level": 1,
		"hp": 110,
		"max_hp": 110,
		"mp": 100,
		"max_mp": 100,
		"attack_style": "Ranged / Rapid arrows",
		"attack_speed": 1.25,
		"mana_cost": 8,
		"promotion_level": ASSASSIN_PROMOTION_LEVEL,
		"promotion_class": "oriental_assassin"
	},
	"trojan": {"display_name": "Trojan", "arabic_name": "التروجان", "locked": true},
	"taoist": {"display_name": "Taoist", "arabic_name": "الحاوي", "locked": true},
	"warrior": {"display_name": "Warrior", "arabic_name": "المحارب", "locked": true}
}

var selected_class: String = "archer"
var _class_buttons: Dictionary = {}

@onready var name_input: LineEdit = $Character_Data_Panel/PanelContent/PlayerNameInput
@onready var start_button: Button = $Character_Data_Panel/PanelContent/StartGameButton
@onready var details_label: Label = $Character_Data_Panel/PanelContent/ClassDetails
@onready var gallery: ScrollContainer = $ClassGallery

func _ready() -> void:
	_setup_landscape_layout()
	_connect_class_buttons()
	_select_class("archer")
	start_button.pressed.connect(_on_start_game_pressed)
	name_input.text_submitted.connect(func(_value: String) -> void: _on_start_game_pressed())
	name_input.grab_focus()

func _setup_landscape_layout() -> void:
	# Keep the screen usable on wide and narrow landscape displays.
	get_viewport().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	gallery.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	gallery.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

func _connect_class_buttons() -> void:
	for class_id in ["trojan", "taoist", "warrior", "archer"]:
		var button := get_node("ClassGallery/ClassTrack/" + class_id.capitalize() + "Card/SelectButton") as Button
		_class_buttons[class_id] = button
		button.pressed.connect(_select_class.bind(class_id))

func _select_class(class_id: String) -> void:
	if not CLASS_DATA.has(class_id):
		return
	var data: Dictionary = CLASS_DATA[class_id]
	if bool(data.get("locked", false)):
		details_label.text = "%s\n%s\nقريباً" % [data.arabic_name, data.display_name]
		return
	selected_class = class_id
	for key in _class_buttons:
		var button: Button = _class_buttons[key]
		button.button_pressed = key == class_id
	var promotion_text := "التطور المتاح عند المستوى %d: السفاح الشرقي" % int(data.promotion_level)
	details_label.text = "الفئة: %s  |  المستوى: 1\nالهجوم: سريع وبعيد المدى\nالصحة: متوازنة (%d)  |  المانا: %d\nاستهلاك المانا للسهم: %d\n%s" % [
		data.arabic_name, int(data.max_hp), int(data.max_mp), int(data.mana_cost), promotion_text
	]

func get_promoted_class(class_id: String, level: int) -> String:
	if class_id == "archer" and level >= ASSASSIN_PROMOTION_LEVEL:
		return "oriental_assassin"
	return class_id

func get_combat_profile(class_id: String, level: int) -> Dictionary:
	if class_id == "archer" and level >= ASSASSIN_PROMOTION_LEVEL:
		return {
			"class_id": "oriental_assassin",
			"display_name": "السفاح الشرقي",
			"weapon_style": "Flying daggers",
			"attack_style": "Fast melee / flying daggers",
			"attack_speed": 1.65,
			"hp": 125,
			"mp": 85,
			"uses_mana_for_arrows": false
		}
	if class_id == "archer":
		return {
			"class_id": "archer",
			"display_name": "الارتشر",
			"weapon_style": "Bow",
			"attack_style": "Rapid ranged arrows",
			"attack_speed": 1.25,
			"hp": 110,
			"mp": 100,
			"mana_cost_per_arrow": 8,
			"uses_mana_for_arrows": true
		}
	return {}

func _on_start_game_pressed() -> void:
	var player_name := name_input.text.strip_edges()
	if player_name.is_empty():
		name_input.placeholder_text = "اكتب اسم الشخصية أولاً"
		name_input.grab_focus()
		return
	if player_name.length() > 20:
		player_name = player_name.substr(0, 20)

	var profile := get_combat_profile(selected_class, 1)
	if profile.is_empty():
		return

	# Persist identity in the existing offline profile; GlobalEconomy remains
	# the authority for the gold balance and its own save file.
	GameState.profile["character_name"] = player_name
	GameState.profile["class_id"] = selected_class
	GameState.profile["class_level"] = 1
	GameState.profile["combat_profile"] = profile
	GameState.save_local()
	GlobalEconomy.save_gold()

	var chosen := {
		"character_name": player_name,
		"class_id": selected_class,
		"class_level": 1,
		"combat_profile": profile
	}
	character_confirmed.emit(chosen)
	var error := get_tree().change_scene_to_file(WORLD_SCENE)
	if error != OK:
		push_error("CharacterSelection: Could not open world scene. Error: %s" % error)

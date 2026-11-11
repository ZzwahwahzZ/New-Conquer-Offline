extends Node
## Gold wallet and persistent character + gear envelope.

signal gold_changed(new_amount: int)
signal economy_ready

const SAVE_PATH := "user://conquer_offline_save.dat"
const SAVE_VERSION := 4
const DEFAULT_GOLD := 100
const LEGACY_SAVE_PATH := "user://offline_profile.json"

var current_gold: int = DEFAULT_GOLD
var _gear_data: Dictionary = {}
var _character_data: Dictionary = {}
var _is_ready_for_transactions := false
var _loaded_save_version := 0

func _ready() -> void:
	_load_save_envelope()
	var gear_system := get_node_or_null("/root/GearSystem")
	if gear_system != null: gear_system.initialize_from_save(_gear_data)
	_is_ready_for_transactions = true
	_notify_gold_changed()
	if not FileAccess.file_exists(SAVE_PATH) or _loaded_save_version < SAVE_VERSION: _write_save_envelope()
	economy_ready.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_runtime_state()

func save_runtime_state() -> bool:
	var class_system := get_node_or_null("/root/ClassSystem")
	if is_instance_valid(class_system) and class_system.has_method("save_character"):
		class_system.call("save_character")
	var gear_system := get_node_or_null("/root/GearSystem")
	if is_instance_valid(gear_system) and gear_system.has_method("serialize_gear_data"):
		_gear_data = gear_system.call("serialize_gear_data")
	var game_state := get_node_or_null("/root/GameState")
	if is_instance_valid(game_state):
		var manager := get_tree().get_first_node_in_group("world_manager")
		if is_instance_valid(manager) and manager.has_method("save_world_state"):
			manager.call("save_world_state")
		game_state.call("save_local")
	return _write_save_envelope()

func add_gold(amount: int) -> bool:
	if amount <= 0: return false
	var previous := current_gold
	current_gold += amount
	if not save_gold():
		current_gold = previous
		return false
	_notify_gold_changed()
	return true

func remove_gold(amount: int) -> bool:
	if amount <= 0 or amount > current_gold: return false
	var previous := current_gold
	current_gold -= amount
	if not save_gold():
		current_gold = previous
		return false
	_notify_gold_changed()
	return true

func save_gold() -> bool:
	if _is_ready_for_transactions:
		var gear_system := get_node_or_null("/root/GearSystem")
		if gear_system != null: _gear_data = gear_system.serialize_gear_data()
	return _write_save_envelope()

func save_gear_data(data: Dictionary) -> bool:
	_gear_data = data.duplicate(true)
	return _write_save_envelope()

func load_gear_data() -> Dictionary: return _gear_data.duplicate(true)
func save_character_data(data: Dictionary) -> bool:
	_character_data = data.duplicate(true)
	return _write_save_envelope()
func load_character_data() -> Dictionary: return _character_data.duplicate(true)

func _load_save_envelope() -> bool:
	_loaded_save_version = 0
	if not FileAccess.file_exists(SAVE_PATH):
		current_gold = _read_legacy_gold()
		_gear_data = {}
		_character_data = {}
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GlobalEconomy: Could not open local save for reading.")
		return false
	var data = file.get_var()
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("GlobalEconomy: Save data is invalid; using safe defaults.")
		current_gold = DEFAULT_GOLD
		return false
	var version := int(data.get("version", -1))
	if version < 1 or version > SAVE_VERSION:
		push_error("GlobalEconomy: Unsupported save version; using safe defaults.")
		current_gold = DEFAULT_GOLD
		return false
	current_gold = maxi(0, int(data.get("current_gold", DEFAULT_GOLD)))
	var loaded_gear = data.get("gear_data", {})
	_gear_data = loaded_gear.duplicate(true) if loaded_gear is Dictionary else {}
	var loaded_character = data.get("character_data", {})
	_character_data = loaded_character.duplicate(true) if loaded_character is Dictionary else {}
	_loaded_save_version = version
	return true

func _write_save_envelope() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GlobalEconomy: Could not open local save for writing.")
		return false
	file.store_var({"version":SAVE_VERSION,"current_gold":current_gold,"gear_data":_gear_data.duplicate(true),"character_data":_character_data.duplicate(true)})
	file.close()
	_loaded_save_version = SAVE_VERSION
	return true

func update_gold_display() -> void: _notify_gold_changed()
func _notify_gold_changed() -> void:
	gold_changed.emit(current_gold)
	var tree := get_tree()
	if tree != null: tree.call_group("gold_counter","set_gold",current_gold)

func _read_legacy_gold() -> int:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH): return DEFAULT_GOLD
	var file := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if file == null: return DEFAULT_GOLD
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY: return DEFAULT_GOLD
	return maxi(0,int(data.get("gold",DEFAULT_GOLD)))

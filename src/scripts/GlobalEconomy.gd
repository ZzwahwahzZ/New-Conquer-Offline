extends Node
## Gold wallet and single-file persistence for gold plus GearSystem data.
## Autoload order: GearDatabase -> GearSystem -> GlobalEconomy -> GameState.

signal gold_changed(new_amount: int)
signal economy_ready

const SAVE_PATH := "user://conquer_offline_save.dat"
const SAVE_VERSION := 2
const DEFAULT_GOLD := 100
const LEGACY_SAVE_PATH := "user://offline_profile.json"

var current_gold: int = DEFAULT_GOLD
var _gear_data: Dictionary = {}
var _is_ready_for_transactions: bool = false


func _ready() -> void:
	# GearSystem is earlier in the Autoload list, so it has completed _ready().
	_load_save_envelope()
	var gear_system := get_node_or_null("/root/GearSystem")
	if gear_system != null:
		gear_system.initialize_from_save(_gear_data)
	_is_ready_for_transactions = true
	_notify_gold_changed()
	if not FileAccess.file_exists(SAVE_PATH) or _loaded_save_version < SAVE_VERSION:
		_write_save_envelope()
	economy_ready.emit()


var _loaded_save_version: int = 0


func add_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	var previous_gold := current_gold
	current_gold += amount
	if not save_gold():
		current_gold = previous_gold
		return false
	_notify_gold_changed()
	return true


func remove_gold(amount: int) -> bool:
	if amount <= 0 or amount > current_gold:
		return false
	var previous_gold := current_gold
	current_gold -= amount
	if not save_gold():
		current_gold = previous_gold
		return false
	_notify_gold_changed()
	return true


func save_gold() -> bool:
	if _is_ready_for_transactions:
		var gear_system := get_node_or_null("/root/GearSystem")
		if gear_system != null:
			_gear_data = gear_system.serialize_gear_data()
	return _write_save_envelope()


func save_gear_data(data: Dictionary) -> bool:
	_gear_data = data.duplicate(true)
	return _write_save_envelope()


func load_gear_data() -> Dictionary:
	return _gear_data.duplicate(true)


func _load_save_envelope() -> bool:
	_loaded_save_version = 0
	if not FileAccess.file_exists(SAVE_PATH):
		current_gold = _read_legacy_gold()
		_gear_data = {}
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
		_gear_data = {}
		return false
	var version := int(data.get("version", -1))
	if version != 1 and version != SAVE_VERSION:
		push_error("GlobalEconomy: Unsupported save version; using safe defaults.")
		current_gold = DEFAULT_GOLD
		_gear_data = {}
		return false
	var loaded_gold := int(data.get("current_gold", -1))
	if loaded_gold < 0:
		push_error("GlobalEconomy: Saved gold amount is invalid.")
		current_gold = DEFAULT_GOLD
		_gear_data = {}
		return false
	current_gold = loaded_gold
	var loaded_gear = data.get("gear_data", {})
	_gear_data = loaded_gear.duplicate(true) if loaded_gear is Dictionary else {}
	_loaded_save_version = version
	return true


func _write_save_envelope() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GlobalEconomy: Could not open local save for writing.")
		return false
	file.store_var({
		"version": SAVE_VERSION,
		"current_gold": current_gold,
		"gear_data": _gear_data.duplicate(true)
	})
	file.close()
	_loaded_save_version = SAVE_VERSION
	return true


func update_gold_display() -> void:
	_notify_gold_changed()


func _notify_gold_changed() -> void:
	gold_changed.emit(current_gold)
	var tree := get_tree()
	if tree != null:
		tree.call_group("gold_counter", "set_gold", current_gold)


func _read_legacy_gold() -> int:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return DEFAULT_GOLD
	var legacy_file := FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
	if legacy_file == null:
		return DEFAULT_GOLD
	var legacy_data = JSON.parse_string(legacy_file.get_as_text())
	legacy_file.close()
	if typeof(legacy_data) != TYPE_DICTIONARY:
		return DEFAULT_GOLD
	return maxi(0, int(legacy_data.get("gold", DEFAULT_GOLD)))

extends Node

signal gold_changed(new_amount: int)

const SAVE_PATH := "user://conquer_offline_save.dat"
const SAVE_VERSION := 1
const DEFAULT_GOLD := 100

var current_gold: int = DEFAULT_GOLD


func _ready() -> void:
	load_gold()


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
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("GlobalEconomy: Could not open local gold save for writing.")
		return false

	file.store_var({
		"version": SAVE_VERSION,
		"current_gold": current_gold
	})
	file.close()
	return true


func load_gold() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		current_gold = DEFAULT_GOLD
		var created := save_gold()
		_notify_gold_changed()
		return created

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("GlobalEconomy: Could not open local gold save for reading.")
		return false

	var data = file.get_var()
	file.close()

	if typeof(data) != TYPE_DICTIONARY:
		push_error("GlobalEconomy: Save data is invalid; keeping the current balance.")
		return false

	if int(data.get("version", -1)) != SAVE_VERSION:
		push_error("GlobalEconomy: Unsupported save version; keeping the current balance.")
		return false

	var loaded_gold := int(data.get("current_gold", -1))
	if loaded_gold < 0:
		push_error("GlobalEconomy: Saved gold amount is invalid.")
		return false

	current_gold = loaded_gold
	_notify_gold_changed()
	return true


func update_gold_display() -> void:
	_notify_gold_changed()


func _notify_gold_changed() -> void:
	gold_changed.emit(current_gold)
	var tree := get_tree()
	if tree != null:
		tree.call_group("gold_counter", "set_gold", current_gold)

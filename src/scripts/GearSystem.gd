extends Node
## Gear, upgrade, composition and socket services. Gold is the only currency.

signal equipment_changed
signal inventory_changed
signal gear_operation_completed(message: String)

const PLUS_MAX := 12
const PLUS_POINT_GOLD_COST := 1000
const PLUS_POINTS_REQUIRED := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const COMPOSE_GOLD_COST := 2500
const PLUS_STONE_COSTS := {1: 1000, 2: 1800}
const LEVEL_UPGRADE_COSTS := {15: 5000, 40: 12000, 70: 25000, 100: 50000, 110: 75000, 120: 100000}
const LEVEL_UPGRADE_RATES := {15: 0.95, 40: 0.85, 70: 0.75, 100: 0.65, 110: 0.55, 120: 0.45}
const SOCKET_OPEN_COSTS := [100000, 200000]
const GEM_SOCKET_COST := 3000

var inventory: Array[Dictionary] = []
var equipment: Dictionary = {
	"RightHand": {}, "LeftHand": {}, "Armor": {}, "Helmet": {},
	"Necklace": {}, "Boots": {}, "Ring": {}
}
var upgrade_points: int = 0
var _rng := RandomNumberGenerator.new()
var _syncing_profile := false
var _gear_restore_received := false

func _ready() -> void:
	_rng.randomize()
	call_deferred("_connect_game_state")

func _connect_game_state() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	if game_state.has_signal("inventory_changed") and not game_state.inventory_changed.is_connected(_on_game_inventory_changed):
		game_state.inventory_changed.connect(_on_game_inventory_changed)
	_on_game_inventory_changed()

func initialize_from_save(data: Dictionary) -> void:
	deserialize_gear_data(data)
	_gear_restore_received = not data.is_empty()

func create_item(item_id: String) -> Dictionary:
	return GearDatabase.create_item(item_id)

func add_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	var blueprint := GearDatabase.get_blueprint(item_id)
	if blueprint.is_empty():
		return false
	for entry in inventory:
		if str(entry.get("id", "")) == item_id and int(entry.get("quantity", 1)) > 0:
			entry["quantity"] = int(entry.get("quantity", 1)) + quantity
			_save_and_emit()
			return true
	var item := GearDatabase.create_item(item_id)
	item["quantity"] = quantity
	inventory.append(item)
	_save_and_emit()
	return true

func add_gem(gem_id: String, quantity: int = 1) -> bool:
	if quantity <= 0 or GearDatabase.get_gem(gem_id).is_empty():
		return false
	for entry in inventory:
		if str(entry.get("gem_id", "")) == gem_id:
			entry["quantity"] = int(entry.get("quantity", 0)) + quantity
			_save_and_emit()
			return true
	inventory.append({"id": gem_id, "gem_id": gem_id, "quantity": quantity, "item_type": "gem", "instance_id": _new_instance_id("gem")})
	_save_and_emit()
	return true

func buy_plus_stone(stone_level: int, quantity: int = 1) -> bool:
	if not PLUS_STONE_COSTS.has(stone_level) or quantity <= 0:
		return false
	var cost := int(PLUS_STONE_COSTS[stone_level]) * quantity
	if not GlobalEconomy.remove_gold(cost):
		return false
	var stone_id := "plus_stone_%d" % stone_level
	for entry in inventory:
		if str(entry.get("id", "")) == stone_id:
			entry["quantity"] = int(entry.get("quantity", 0)) + quantity
			_save_and_emit()
			gear_operation_completed.emit("تم شراء %d حجر بلس +%d." % [quantity, stone_level])
			return true
	inventory.append({"id": stone_id, "instance_id": _new_instance_id(stone_id), "item_type": "plus_stone", "stone_level": stone_level, "name": "Plus Stone +%d" % stone_level, "quantity": quantity})
	_save_and_emit()
	gear_operation_completed.emit("تم شراء %d حجر بلس +%d." % [quantity, stone_level])
	return true

func can_character_equip(item: Dictionary, current_class: String, current_level: int, target_slot: String = "") -> bool:
	if item.is_empty():
		return false
	var allowed_classes: Array = item.get("allowed_classes", [])
	var class_allowed := allowed_classes.has(current_class)
	# Oriental Assassin inherits Archer gear; this rule is deliberately unchanged.
	if current_class == "Oriental_Assassin":
		class_allowed = class_allowed or allowed_classes.has("Archer") or allowed_classes.has("Oriental_Assassin")
	if not class_allowed or current_level < int(item.get("required_level", 1)):
		return false
	var slot := target_slot if not target_slot.is_empty() else str(item.get("slot", ""))
	var allowed_slots: Array = item.get("allowed_slots", [item.get("slot", "")])
	if not GearDatabase.SLOTS.has(slot) or not allowed_slots.has(slot):
		return false
	if str(item.get("weapon_family", "")) == "ThrowingKnife" and current_class != "Oriental_Assassin":
		return false
	return true

func equip_item(item_instance_id: String, target_slot: String, current_class: String, current_level: int) -> bool:
	if not GearDatabase.SLOTS.has(target_slot):
		return false
	var index := _find_inventory_index(item_instance_id)
	if index < 0:
		return false
	var item: Dictionary = inventory[index]
	if not can_character_equip(item, current_class, current_level, target_slot):
		return false
	if target_slot == "LeftHand":
		var family := str(item.get("weapon_family", ""))
		if family == "Arrows":
			var right_item: Dictionary = equipment.get("RightHand", {})
			if right_item.is_empty() or str(right_item.get("weapon_family", "")) != "Bow":
				return false
		if family == "ThrowingKnife":
			var right_knife: Dictionary = equipment.get("RightHand", {})
			if not right_knife.is_empty() and str(right_knife.get("weapon_family", "")) != "ThrowingKnife":
				return false
	if target_slot == "RightHand":
		var left_item: Dictionary = equipment.get("LeftHand", {})
		var family := str(item.get("weapon_family", ""))
		if family == "Bow" and not left_item.is_empty() and str(left_item.get("weapon_family", "")) != "Arrows":
			return false
		if family == "ThrowingKnife" and not left_item.is_empty() and str(left_item.get("weapon_family", "")) != "ThrowingKnife":
			return false
	var old_item: Dictionary = equipment.get(target_slot, {})
	if not old_item.is_empty():
		old_item["quantity"] = 1
		inventory.append(old_item)
	var equipped := item.duplicate(true)
	equipped.erase("quantity")
	equipment[target_slot] = equipped
	var remaining := int(item.get("quantity", 1)) - 1
	if remaining <= 0:
		inventory.remove_at(index)
	else:
		inventory[index]["quantity"] = remaining
	_save_and_emit()
	return true

func unequip_item(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false
	var item: Dictionary = equipment[slot].duplicate(true)
	item["quantity"] = 1
	inventory.append(item)
	equipment[slot] = {}
	_save_and_emit()
	return true

func buy_plus_points(points: int) -> bool:
	if points <= 0 or not GlobalEconomy.remove_gold(points * PLUS_POINT_GOLD_COST):
		return false
	upgrade_points += points
	_save_gear_data()
	gear_operation_completed.emit("تم شراء %d نقطة توليف." % points)
	return true

func upgrade_plus(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false
	var item: Dictionary = equipment[slot]
	return _upgrade_plus_dictionary(item)

func _upgrade_plus_dictionary(item: Dictionary) -> bool:
	var current_plus := int(item.get("plus", 0))
	if current_plus >= PLUS_MAX:
		return false
	var required := PLUS_POINTS_REQUIRED[current_plus]
	if upgrade_points < required and not buy_plus_points(required - upgrade_points):
		return false
	upgrade_points -= required
	item["plus"] = current_plus + 1
	_save_and_emit()
	gear_operation_completed.emit("نجح رفع البلس إلى +%d." % int(item["plus"]))
	return true

func compose_item(main_instance_id: String, minor_instance_ids: Array[String]) -> bool:
	var main_record := _find_item_record(main_instance_id)
	if main_record.is_empty() or minor_instance_ids.is_empty() or minor_instance_ids.size() > 2:
		return false
	var main_item: Dictionary = main_record["item"]
	var plus := int(main_item.get("plus", 0))
	if plus >= PLUS_MAX:
		return false
	var points := 0
	var consume_counts: Dictionary = {}
	for stone_id in minor_instance_ids:
		if stone_id.is_empty() or stone_id == main_instance_id:
			return false
		var stone_record := _find_item_record(stone_id)
		if stone_record.is_empty() or str(stone_record["kind"]) != "inventory":
			return false
		var stone: Dictionary = stone_record["item"]
		if str(stone.get("item_type", "")) != "plus_stone":
			return false
		points += int(stone.get("stone_level", 0))
		consume_counts[stone_id] = int(consume_counts.get(stone_id, 0)) + 1
	for stone_id in consume_counts:
		var stone_index := _find_inventory_index(str(stone_id))
		if stone_index < 0 or int(inventory[stone_index].get("quantity", 0)) < int(consume_counts[stone_id]):
			return false
	if points <= 0 or not GlobalEconomy.remove_gold(COMPOSE_GOLD_COST):
		return false
	for stone_id in consume_counts:
		_consume_inventory_item(str(stone_id), int(consume_counts[stone_id]))
	var required := PLUS_POINTS_REQUIRED[plus]
	main_item["compose_points"] = int(main_item.get("compose_points", 0)) + points
	if int(main_item["compose_points"]) >= required:
		main_item["compose_points"] = int(main_item["compose_points"]) - required
		main_item["plus"] = plus + 1
	_write_item_record(main_record, main_item)
	_save_and_emit()
	if int(main_item["plus"]) > plus:
		gear_operation_completed.emit("اكتمل التوليف وارتفع العتاد إلى +%d بأمان." % int(main_item["plus"]))
	else:
		gear_operation_completed.emit("تمت إضافة %d نقطة توليف." % points)
	return true


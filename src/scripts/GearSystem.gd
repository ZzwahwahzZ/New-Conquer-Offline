extends Node
## Equipment, gem, quality, level and guaranteed plus-upgrade system.
## Gear data is persisted inside GlobalEconomy's existing local save file.

signal equipment_changed
signal inventory_changed
signal gear_operation_completed(message: String)

const PLUS_MAX := 12
const PLUS_POINT_GOLD_COST := 1000
const PLUS_POINTS_REQUIRED := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]
const QUALITY_UPGRADE_COST := 25000
const UNIQUE_TO_SUPER_CHANCE := 0.25
const LEVEL_UPGRADE_COSTS := {15: 5000, 40: 12000, 70: 25000, 100: 50000, 110: 75000}
const GEM_SOCKET_COST := 3000

var inventory: Array[Dictionary] = []
var equipment: Dictionary = {
	"RightHand": {}, "LeftHand": {}, "Armor": {}, "Helmet": {},
	"Necklace": {}, "Boots": {}, "Ring": {}
}
var upgrade_points: int = 0
var _rng := RandomNumberGenerator.new()
var _syncing_profile: bool = false

var _gear_restore_received: bool = false
var _game_state_connected: bool = false

func _ready() -> void:
	# GearDatabase is guaranteed to be initialized before this autoload.
	_rng.randomize()
	call_deferred("_connect_game_state")

func _connect_game_state() -> void:
	# Deferred until every autoload has entered the tree and completed _ready().
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	if game_state.has_signal("inventory_changed") and not game_state.inventory_changed.is_connected(_on_game_inventory_changed):
		game_state.inventory_changed.connect(_on_game_inventory_changed)
	_game_state_connected = true

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
	inventory.append({"id": gem_id, "gem_id": gem_id, "quantity": quantity, "item_type": "gem"})
	_save_and_emit()
	return true

func can_character_equip(item: Dictionary, current_class: String, current_level: int, target_slot: String = "") -> bool:
	if item.is_empty():
		return false
	var allowed_classes: Array = item.get("allowed_classes", [])
	var class_allowed := allowed_classes.has(current_class)
	# Oriental Assassin is the Archer's future evolution and inherits Archer gear.
	if current_class == "Oriental_Assassin":
		class_allowed = class_allowed or allowed_classes.has("Archer") or allowed_classes.has("Oriental_Assassin")
	if not class_allowed:
		return false
	if current_level < int(item.get("required_level", 1)):
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
			var right_knife_check: Dictionary = equipment.get("RightHand", {})
			if not right_knife_check.is_empty() and str(right_knife_check.get("weapon_family", "")) != "ThrowingKnife":
				return false
	if target_slot == "RightHand":
		var left_item: Dictionary = equipment.get("LeftHand", {})
		var new_family := str(item.get("weapon_family", ""))
		if new_family == "Bow" and not left_item.is_empty() and str(left_item.get("weapon_family", "")) != "Arrows":
			return false
		if new_family == "ThrowingKnife" and not left_item.is_empty() and str(left_item.get("weapon_family", "")) != "ThrowingKnife":
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
	if points <= 0:
		return false
	var total_cost := points * PLUS_POINT_GOLD_COST
	if not GlobalEconomy.remove_gold(total_cost):
		return false
	upgrade_points += points
	_save_gear_data()
	gear_operation_completed.emit("تم شراء %d نقطة ترقية." % points)
	return true

func upgrade_plus(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false
	var item: Dictionary = equipment[slot]
	var current_plus := int(item.get("plus", 0))
	if current_plus >= PLUS_MAX:
		return false
	var required_points := PLUS_POINTS_REQUIRED[current_plus]
	if upgrade_points < required_points:
		var missing := required_points - upgrade_points
		if not buy_plus_points(missing):
			return false
	upgrade_points -= required_points
	item["plus"] = current_plus + 1
	_save_and_emit()
	gear_operation_completed.emit("نجحت الترقية المضمونة إلى +%d." % int(item["plus"]))
	return true

func upgrade_item_level(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false
	var item: Dictionary = equipment[slot]
	var current_level := int(item.get("required_level", 15))
	var tier_index := GearDatabase.LEVEL_TIERS.find(current_level)
	if tier_index < 0 or tier_index >= GearDatabase.LEVEL_TIERS.size() - 1:
		return false
	var cost := int(LEVEL_UPGRADE_COSTS.get(current_level, 0))
	if cost <= 0 or not GlobalEconomy.remove_gold(cost):
		return false
	item["required_level"] = GearDatabase.LEVEL_TIERS[tier_index + 1]
	_save_and_emit()
	gear_operation_completed.emit("تم رفع مستوى القطعة إلى %d." % int(item["required_level"]))
	return true

func upgrade_quality_to_super(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false
	var item: Dictionary = equipment[slot]
	if str(item.get("quality", "")) != "Unique":
		return false
	if not GlobalEconomy.remove_gold(QUALITY_UPGRADE_COST):
		return false
	if _rng.randf() <= UNIQUE_TO_SUPER_CHANCE:
		item["quality"] = "Super"
		_save_and_emit()
		gear_operation_completed.emit("نجحت ترقية الجودة إلى Super!")
		return true
	_save_gear_data()
	gear_operation_completed.emit("لم تنجح محاولة ترقية الجودة. لم تتغير القطعة.")
	return false

func socket_gem(slot: String, socket_index: int, gem_id: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false
	if socket_index < 0 or socket_index >= GearDatabase.SOCKET_COUNT:
		return false
	var gem := GearDatabase.get_gem(gem_id)
	if gem.is_empty():
		return false
	var item: Dictionary = equipment[slot]
	var sockets: Array = item.get("sockets", ["Empty", "Empty"])
	if str(sockets[socket_index]) != "Empty":
		return false
	var gem_index := _find_gem_index(gem_id)
	if gem_index < 0:
		return false
	if not GlobalEconomy.remove_gold(GEM_SOCKET_COST):
		return false
	var gem_quantity := int(inventory[gem_index].get("quantity", 0)) - 1
	if gem_quantity <= 0:
		inventory.remove_at(gem_index)
	else:
		inventory[gem_index]["quantity"] = gem_quantity
	sockets[socket_index] = gem_id
	item["sockets"] = sockets
	_save_and_emit()
	return true

func get_equipment_bonus() -> Dictionary:
	var result := {"physical_attack_pct": 0.0, "magic_attack_pct": 0.0, "experience_pct": 0.0}
	for slot in equipment:
		var item: Dictionary = equipment[slot]
		if item.is_empty():
			continue
		for gem_id in item.get("sockets", []):
			var gem := GearDatabase.get_gem(str(gem_id))
			if gem.is_empty():
				continue
			var stat := str(gem.get("stat", ""))
			if result.has(stat):
				result[stat] = float(result[stat]) + float(gem.get("percent", 0.0))
	return result

func get_item_final_stats(item: Dictionary) -> Dictionary:
	var stats: Dictionary = item.get("base_stats", {}).duplicate(true)
	var plus_level := int(item.get("plus", 0))
	for stat in stats:
		stats[stat] = int(round(float(stats[stat]) * (1.0 + plus_level * 0.05)))
	var quality := str(item.get("quality", "Normal"))
	var quality_multiplier := {"Normal": 1.0, "Refined": 1.05, "Unique": 1.10, "Super": 1.15}
	for stat in stats:
		stats[stat] = int(round(float(stats[stat]) * float(quality_multiplier.get(quality, 1.0))))
	return stats

func serialize_gear_data() -> Dictionary:
	return {
		"inventory": inventory.duplicate(true),
		"equipment": equipment.duplicate(true),
		"upgrade_points": upgrade_points
	}

func deserialize_gear_data(data: Dictionary) -> void:
	var stored_inventory = data.get("inventory", [])
	if stored_inventory is Array:
		inventory.clear()
		for entry in stored_inventory:
			if entry is Dictionary:
				inventory.append(entry.duplicate(true))
	var stored_equipment = data.get("equipment", {})
	if stored_equipment is Dictionary:
		for slot in GearDatabase.SLOTS:
			var item = stored_equipment.get(slot, {})
			equipment[slot] = item.duplicate(true) if item is Dictionary else {}
	upgrade_points = maxi(0, int(data.get("upgrade_points", 0)))
	inventory_changed.emit()
	equipment_changed.emit()

func save_gear_data() -> bool:
	return GlobalEconomy.save_gear_data(serialize_gear_data())

func load_gear_data() -> bool:
	# Compatibility wrapper. GlobalEconomy owns the startup load sequence.
	var economy := get_node_or_null("/root/GlobalEconomy")
	if economy == null:
		return false
	var data: Dictionary = economy.load_gear_data()
	initialize_from_save(data)
	return not data.is_empty()

func _find_inventory_index(item_instance_id: String) -> int:
	for index in range(inventory.size()):
		if str(inventory[index].get("instance_id", "")) == item_instance_id:
			return index
	return -1

func _find_gem_index(gem_id: String) -> int:
	for index in range(inventory.size()):
		if str(inventory[index].get("gem_id", "")) == gem_id and int(inventory[index].get("quantity", 0)) > 0:
			return index
	return -1

func _save_and_emit() -> void:
	_save_gear_data()
	inventory_changed.emit()
	equipment_changed.emit()

func _save_gear_data() -> void:
	var snapshot := serialize_gear_data()
	var economy := get_node_or_null("/root/GlobalEconomy")
	if economy != null:
		economy.save_gear_data(snapshot)
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		_syncing_profile = true
		game_state.profile["inventory"] = inventory.duplicate(true)
		game_state.save_local()
		game_state.inventory_changed.emit()
		_syncing_profile = false

func _on_game_inventory_changed() -> void:
	if _syncing_profile:
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	# Migrate the old GameState bag only when no GearSystem save existed.
	if not _gear_restore_received and inventory.is_empty():
		var profile_inventory = game_state.profile.get("inventory", [])
		if profile_inventory is Array:
			for entry in profile_inventory:
				if entry is Dictionary:
					inventory.append(entry.duplicate(true))
			if not inventory.is_empty():
				_save_gear_data()
				inventory_changed.emit()
		return
	# GearSystem's dedicated save is authoritative; mirror it for the legacy bag UI.
	_syncing_profile = true
	game_state.profile["inventory"] = inventory.duplicate(true)
	_syncing_profile = false

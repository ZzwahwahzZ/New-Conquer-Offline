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
var weapon_loadouts: Dictionary = {"Archer": {}, "Oriental_Assassin": {}}
var _rng := RandomNumberGenerator.new()
var _syncing_profile := false
var _gear_restore_received := false

func _ready() -> void:
	_rng.randomize()
	call_deferred("_connect_game_state")

func _connect_game_state() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state == null:
		return
	if game_state.has_signal("inventory_changed") and not game_state.inventory_changed.is_connected(_on_game_inventory_changed):
		game_state.inventory_changed.connect(_on_game_inventory_changed)
	_migrate_legacy_inventory()

func _migrate_legacy_inventory() -> void:
	var game_state = get_node_or_null("/root/GameState")
	if game_state == null:
		return
	var legacy = game_state.profile.get("inventory", [])
	if typeof(legacy) != TYPE_ARRAY:
		_gear_restore_received = true
		return
	var remaining: Array = []
	var migrated := false
	for entry in legacy:
		if typeof(entry) != TYPE_DICTIONARY:
			remaining.append(entry)
			continue
		var item_id := str(entry.get("id", ""))
		var is_gear := entry.has("slot") or entry.has("weapon_family") or str(entry.get("item_type", "")) in ["gem", "plus_stone"] or not GearDatabase.get_blueprint(item_id).is_empty()
		if is_gear:
			if not _gear_restore_received:
				inventory.append(_normalize_item(entry))
				migrated = true
		else:
			remaining.append(entry)
	_gear_restore_received = true
	if remaining.size() != legacy.size():
		game_state.profile["inventory"] = remaining
		game_state.call("save_local")
	if migrated:
		_save_gear_data()
		inventory_changed.emit()

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
	var item := create_item(item_id)
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

func can_character_equip(item: Dictionary, current_class: String = "", current_level: int = 0, target_slot: String = "") -> bool:
	var class_system = get_node_or_null("/root/ClassSystem")
	if class_system != null:
		current_class = class_system.current_class
		current_level = class_system.level
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
	var weapon_family := str(item.get("weapon_family", ""))
	if weapon_family == "ThrowingKnife" and current_class != "Oriental_Assassin":
		return false
	if weapon_family in ["Bow", "Arrows"] and current_class == "Oriental_Assassin":
		return false
	return true

## Keep a separate two-hand weapon set for each Archer/Assassin combat stance.
func switch_weapon_mode(previous_mode: String, new_mode: String) -> void:
	if previous_mode not in ["Archer", "Oriental_Assassin"] or new_mode not in ["Archer", "Oriental_Assassin"] or previous_mode == new_mode:
		return
	weapon_loadouts[previous_mode] = {
		"RightHand": equipment.get("RightHand", {}).duplicate(true),
		"LeftHand": equipment.get("LeftHand", {}).duplicate(true)
	}
	equipment["RightHand"] = {}
	equipment["LeftHand"] = {}
	var target: Dictionary = weapon_loadouts.get(new_mode, {})
	if not target.is_empty():
		equipment["RightHand"] = target.get("RightHand", {}).duplicate(true)
		equipment["LeftHand"] = target.get("LeftHand", {}).duplicate(true)
		weapon_loadouts[new_mode] = {}
	else:
		var right_family := "Bow" if new_mode == "Archer" else "ThrowingKnife"
		var left_family := "Arrows" if new_mode == "Archer" else "ThrowingKnife"
		var right_index := _find_inventory_weapon_index(right_family)
		var left_index := _find_inventory_weapon_index(left_family, right_index)
		if right_index >= 0 and left_index >= 0:
			var right_item: Dictionary = inventory[right_index].duplicate(true)
			var left_item: Dictionary = inventory[left_index].duplicate(true)
			_consume_inventory_index(maxi(right_index, left_index), 1)
			_consume_inventory_index(mini(right_index, left_index), 1)
			right_item.erase("quantity")
			left_item.erase("quantity")
			equipment["RightHand"] = right_item
			equipment["LeftHand"] = left_item
	_save_and_emit()

func _find_inventory_weapon_index(family: String, excluded_index: int = -1) -> int:
	for index in range(inventory.size()):
		if index == excluded_index and int(inventory[index].get("quantity", 1)) < 2:
			continue
		if str(inventory[index].get("weapon_family", "")) == family and int(inventory[index].get("quantity", 1)) > 0:
			return index
	return -1

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



func get_item_by_instance_id(instance_id: String) -> Dictionary:
	var record := _find_item_record(instance_id)
	if record.is_empty():
		return {}
	var item: Dictionary = record["item"]
	return item.duplicate(true)

func get_compose_progress(item_instance_id: String) -> Dictionary:
	var record := _find_item_record(item_instance_id)
	if record.is_empty():
		return {}
	var item: Dictionary = record["item"]
	var plus := clampi(int(item.get("plus", 0)), 0, PLUS_MAX)
	var required := 0 if plus >= PLUS_MAX else PLUS_POINTS_REQUIRED[plus]
	return {"current": int(item.get("compose_points", 0)), "required": required, "plus": plus}

func upgrade_item_level(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false
	return upgrade_item_level_by_id(str(equipment[slot].get("instance_id", "")))

func upgrade_item_level_by_id(instance_id: String) -> bool:
	var record := _find_item_record(instance_id)
	if record.is_empty():
		return false
	var item: Dictionary = record["item"]
	var current_level := int(item.get("required_level", 15))
	var tier_index := GearDatabase.LEVEL_TIERS.find(current_level)
	if tier_index < 0 or tier_index >= GearDatabase.LEVEL_TIERS.size() - 1:
		return false
	var cost := int(LEVEL_UPGRADE_COSTS.get(current_level, 0))
	if cost <= 0 or not GlobalEconomy.remove_gold(cost):
		return false
	if _rng.randf() <= float(LEVEL_UPGRADE_RATES.get(current_level, 0.5)):
		item["required_level"] = GearDatabase.LEVEL_TIERS[tier_index + 1]
		_write_item_record(record, item)
		_save_and_emit()
		gear_operation_completed.emit("نجحت ترقية المستوى إلى %d." % int(item["required_level"]))
		return true
	_save_gear_data()
	gear_operation_completed.emit("فشلت ترقية المستوى؛ خُصم الذهب وبقي المستوى كما هو.")
	return false

func upgrade_quality_to_super(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false
	return upgrade_quality_by_id(str(equipment[slot].get("instance_id", "")))

func upgrade_quality_by_id(instance_id: String) -> bool:
	var record := _find_item_record(instance_id)
	if record.is_empty():
		return false
	var item: Dictionary = record["item"]
	var next := GearDatabase.get_quality_upgrade(str(item.get("quality", "Normal")))
	if next.is_empty():
		return false
	if not GlobalEconomy.remove_gold(int(next["cost"])):
		return false
	if _rng.randf() <= float(next["chance"]):
		item["quality"] = str(next["quality"])
		_write_item_record(record, item)
		_save_and_emit()
		gear_operation_completed.emit("نجحت ترقية الجودة إلى %s." % str(next["quality"]))
		return true
	_save_gear_data()
	gear_operation_completed.emit("فشلت ترقية الجودة؛ خُصم الذهب فقط ولم تتغير القطعة.")
	return false

func open_socket_by_id(instance_id: String) -> bool:
	var record := _find_item_record(instance_id)
	if record.is_empty():
		return false
	var item: Dictionary = record["item"]
	var count := clampi(int(item.get("socket_count", item.get("sockets", []).size())), 0, GearDatabase.SOCKET_MAX)
	if count >= GearDatabase.SOCKET_MAX:
		return false
	var cost := int(SOCKET_OPEN_COSTS[count])
	if not GlobalEconomy.remove_gold(cost):
		return false
	var sockets: Array = item.get("sockets", []).duplicate(true)
	while sockets.size() < count:
		sockets.append("Empty")
	sockets.append("Empty")
	item["socket_count"] = count + 1
	item["sockets"] = sockets
	_write_item_record(record, item)
	_save_and_emit()
	gear_operation_completed.emit("تم فتح المقبس رقم %d." % (count + 1))
	return true

func socket_gem_by_id(instance_id: String, socket_index: int, gem_id: String) -> bool:
	var record := _find_item_record(instance_id)
	if record.is_empty() or GearDatabase.get_gem(gem_id).is_empty():
		return false
	var item: Dictionary = record["item"]
	var count := clampi(int(item.get("socket_count", item.get("sockets", []).size())), 0, GearDatabase.SOCKET_MAX)
	if socket_index < 0 or socket_index >= count:
		return false
	var gem_index := _find_gem_index(gem_id)
	if gem_index < 0 or not GlobalEconomy.remove_gold(GEM_SOCKET_COST):
		return false
	var sockets: Array = item.get("sockets", []).duplicate(true)
	while sockets.size() < count:
		sockets.append("Empty")
	sockets[socket_index] = gem_id
	_consume_inventory_index(gem_index, 1)
	item["sockets"] = sockets
	item["socket_count"] = count
	_write_item_record(record, item)
	_save_and_emit()
	gear_operation_completed.emit("تم تركيب الجوهرة؛ الجوهرة السابقة -إن وجدت- أتلفت.")
	return true

func socket_gem(slot: String, socket_index: int, gem_id: String) -> bool:
	if not equipment.has(slot) or equipment[slot].is_empty():
		return false
	return socket_gem_by_id(str(equipment[slot].get("instance_id", "")), socket_index, gem_id)

func get_equipment_bonus() -> Dictionary:
	var result := {"physical_attack_pct": 0.0, "magic_attack_pct": 0.0, "experience_pct": 0.0, "dodge_pct": 0.0, "magic_defense_pct": 0.0, "critical_pct": 0.0, "defense_pct": 0.0}
	for slot in equipment:
		var item: Dictionary = equipment[slot]
		for gem_id in item.get("sockets", []):
			var gem := GearDatabase.get_gem(str(gem_id))
			var stat := str(gem.get("stat", ""))
			if result.has(stat):
				result[stat] = float(result[stat]) + float(gem.get("percent", 0.0))
	return result

func get_item_final_stats(item: Dictionary) -> Dictionary:
	var stats: Dictionary = item.get("base_stats", {}).duplicate(true)
	var plus := int(item.get("plus", 0))
	var quality := str(item.get("quality", "Normal"))
	var multiplier := float(GearDatabase.QUALITY_MULTIPLIERS.get(quality, 1.0))
	for stat in stats:
		stats[stat] = int(round(float(stats[stat]) * (1.0 + plus * 0.05) * multiplier))
	for gem_id in item.get("sockets", []):
		var gem := GearDatabase.get_gem(str(gem_id))
		if gem.is_empty():
			continue
		var stat := str(gem["stat"])
		stats[stat] = float(stats.get(stat, 0.0)) + float(gem["percent"])
	return stats

func serialize_gear_data() -> Dictionary:
	return {"inventory": inventory.duplicate(true), "equipment": equipment.duplicate(true), "upgrade_points": upgrade_points, "weapon_loadouts": weapon_loadouts.duplicate(true)}

func deserialize_gear_data(data: Dictionary) -> void:
	var stored_inventory = data.get("inventory", [])
	if stored_inventory is Array:
		inventory.clear()
		for entry in stored_inventory:
			if entry is Dictionary:
				inventory.append(_normalize_item(entry))
	var stored_equipment = data.get("equipment", {})
	if stored_equipment is Dictionary:
		for slot in GearDatabase.SLOTS:
			var item = stored_equipment.get(slot, {})
			equipment[slot] = _normalize_item(item) if item is Dictionary and not item.is_empty() else {}
	upgrade_points = maxi(0, int(data.get("upgrade_points", 0)))
	var stored_loadouts = data.get("weapon_loadouts", {})
	if stored_loadouts is Dictionary:
		weapon_loadouts = stored_loadouts.duplicate(true)
	for mode in ["Archer", "Oriental_Assassin"]:
		if not weapon_loadouts.has(mode): weapon_loadouts[mode] = {}
	inventory_changed.emit()
	equipment_changed.emit()

func save_gear_data() -> bool:
	return GlobalEconomy.save_gear_data(serialize_gear_data())

func load_gear_data() -> bool:
	var economy = get_node_or_null("/root/GlobalEconomy")
	if economy == null:
		return false
	var data: Dictionary = economy.load_gear_data()
	initialize_from_save(data)
	return not data.is_empty()

func _normalize_item(source: Dictionary) -> Dictionary:
	var item := source.duplicate(true)
	if not item.has("instance_id") or str(item["instance_id"]).is_empty():
		item["instance_id"] = _new_instance_id(str(item.get("id", "item")))
	var sockets: Array = item.get("sockets", []).duplicate(true)
	var inferred_count := 0
	if not item.has("socket_count"):
		# Legacy items had two Empty placeholders; only a socket containing a gem proves it was opened.
		for socket_index in range(sockets.size()):
			if str(sockets[socket_index]) != "Empty":
				inferred_count = socket_index + 1
	var count := clampi(int(item.get("socket_count", inferred_count)), 0, GearDatabase.SOCKET_MAX)
	while sockets.size() < count:
		sockets.append("Empty")
	if sockets.size() > count:
		sockets.resize(count)
	item["socket_count"] = count
	item["sockets"] = sockets
	return item

func _find_item_record(instance_id: String) -> Dictionary:
	if instance_id.is_empty():
		return {}
	var index := _find_inventory_index(instance_id)
	if index >= 0:
		return {"kind": "inventory", "index": index, "item": inventory[index]}
	for slot in equipment:
		if str(equipment[slot].get("instance_id", "")) == instance_id:
			return {"kind": "equipment", "slot": slot, "item": equipment[slot]}
	return {}

func _write_item_record(record: Dictionary, item: Dictionary) -> void:
	if str(record.get("kind", "")) == "inventory":
		var index := _find_inventory_index(str(item.get("instance_id", "")))
		if index >= 0:
			inventory[index] = item
	elif str(record.get("kind", "")) == "equipment":
		equipment[str(record["slot"])] = item

func _consume_inventory_item(instance_id: String, amount: int) -> void:
	var index := _find_inventory_index(instance_id)
	if index >= 0:
		_consume_inventory_index(index, amount)

func _consume_inventory_index(index: int, amount: int) -> void:
	if index < 0 or index >= inventory.size():
		return
	var remaining := int(inventory[index].get("quantity", 1)) - amount
	if remaining <= 0:
		inventory.remove_at(index)
	else:
		inventory[index]["quantity"] = remaining

func _find_inventory_index(instance_id: String) -> int:
	for index in range(inventory.size()):
		if str(inventory[index].get("instance_id", "")) == instance_id:
			return index
	return -1

func _find_gem_index(gem_id: String) -> int:
	for index in range(inventory.size()):
		if str(inventory[index].get("gem_id", "")) == gem_id and int(inventory[index].get("quantity", 0)) > 0:
			return index
	return -1

func _new_instance_id(prefix: String) -> String:
	return "%s_%d_%d" % [prefix, Time.get_ticks_usec(), _rng.randi()]

func _save_and_emit() -> void:
	_save_gear_data()
	inventory_changed.emit()
	equipment_changed.emit()

func _save_gear_data() -> void:
	var snapshot := serialize_gear_data()
	var economy = get_node_or_null("/root/GlobalEconomy")
	if economy != null:
		economy.call("save_gear_data",snapshot)

func _on_game_inventory_changed() -> void:
	# GearSystem inventory and general GameState inventory are separate stores.
	# Never mirror one over the other: that would erase potions/materials.
	if _syncing_profile:
		return

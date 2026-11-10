extends Node
## Item blueprints and progression tables. Values are project balance data, not claims of exact official-server rates.

const SLOTS := ["RightHand", "LeftHand", "Armor", "Helmet", "Necklace", "Boots", "Ring"]
const QUALITIES := ["Normal", "Refined", "Unique", "Elite", "Super"]
const QUALITY_MULTIPLIERS := {"Normal": 1.0, "Refined": 1.05, "Unique": 1.10, "Elite": 1.15, "Super": 1.22}
const SOCKET_MAX := 2
const LEVEL_TIERS := [15, 40, 70, 100, 110, 120, 130]

const GEM_FAMILIES := ["Dragon", "Phoenix", "Rainbow", "Violet", "Moon", "Fury", "Kylin"]
const GEM_QUALITIES := ["Normal", "Refined", "Super"]
const GEM_DATA := {
	"Dragon": {"stat": "physical_attack_pct", "values": [5.0, 7.0, 10.0]},
	"Phoenix": {"stat": "magic_attack_pct", "values": [5.0, 7.0, 10.0]},
	"Rainbow": {"stat": "experience_pct", "values": [10.0, 15.0, 20.0]},
	"Violet": {"stat": "dodge_pct", "values": [2.0, 3.0, 5.0]},
	"Moon": {"stat": "magic_defense_pct", "values": [5.0, 7.0, 10.0]},
	"Fury": {"stat": "critical_pct", "values": [2.0, 3.0, 5.0]},
	"Kylin": {"stat": "defense_pct", "values": [5.0, 7.0, 10.0]}
}

const WEAPON_BLUEPRINTS := {
	"archer_bow": {
		"name": "Archer Bow", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "RightHand", "allowed_slots": ["RightHand"], "weapon_family": "Bow",
		"quality": "Normal", "plus": 0, "socket_count": 0, "sockets": [],
		"required_level": 15, "base_stats": {"physical_attack": 30, "magic_attack": 0}
	},
	"archer_arrows": {
		"name": "Arrows", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "LeftHand", "allowed_slots": ["LeftHand"], "weapon_family": "Arrows",
		"quality": "Normal", "plus": 0, "socket_count": 0, "sockets": [],
		"required_level": 15, "base_stats": {"physical_attack": 8, "magic_attack": 0}
	},
	"assassin_throwing_knife": {
		"name": "Throwing Knife", "allowed_classes": ["Oriental_Assassin"],
		"slot": "RightHand", "allowed_slots": ["RightHand", "LeftHand"], "weapon_family": "ThrowingKnife",
		"quality": "Normal", "plus": 0, "socket_count": 0, "sockets": [],
		"required_level": 70, "base_stats": {"physical_attack": 42, "magic_attack": 0}
	}
}

const ARMOR_BLUEPRINTS := {
	"archer_armor_15": {
		"name": "Archer Armor", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "Armor", "allowed_slots": ["Armor"], "weapon_family": "",
		"quality": "Normal", "plus": 0, "socket_count": 0, "sockets": [],
		"required_level": 15, "base_stats": {"defense": 18}
	},
	"archer_helmet_15": {
		"name": "Archer Helmet", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "Helmet", "allowed_slots": ["Helmet"], "weapon_family": "",
		"quality": "Normal", "plus": 0, "socket_count": 0, "sockets": [],
		"required_level": 15, "base_stats": {"defense": 8}
	},
	"basic_necklace": {
		"name": "Necklace", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "Necklace", "allowed_slots": ["Necklace"], "weapon_family": "",
		"quality": "Normal", "plus": 0, "socket_count": 0, "sockets": [],
		"required_level": 15, "base_stats": {"max_hp": 10}
	},
	"basic_boots": {
		"name": "Boots", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "Boots", "allowed_slots": ["Boots"], "weapon_family": "",
		"quality": "Normal", "plus": 0, "socket_count": 0, "sockets": [],
		"required_level": 15, "base_stats": {"defense": 4}
	},
	"basic_ring": {
		"name": "Ring", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "Ring", "allowed_slots": ["Ring"], "weapon_family": "",
		"quality": "Normal", "plus": 0, "socket_count": 0, "sockets": [],
		"required_level": 15, "base_stats": {"physical_attack": 3}
	}
}

func get_blueprint(item_id: String) -> Dictionary:
	if WEAPON_BLUEPRINTS.has(item_id):
		return WEAPON_BLUEPRINTS[item_id].duplicate(true)
	if ARMOR_BLUEPRINTS.has(item_id):
		return ARMOR_BLUEPRINTS[item_id].duplicate(true)
	return {}

func create_item(item_id: String, instance_id: String = "") -> Dictionary:
	var item := get_blueprint(item_id)
	if item.is_empty():
		return {}
	item["id"] = item_id
	item["instance_id"] = instance_id if not instance_id.is_empty() else "%s_%d" % [item_id, Time.get_ticks_usec()]
	item["socket_count"] = clampi(int(item.get("socket_count", 0)), 0, SOCKET_MAX)
	item["sockets"] = item.get("sockets", []).duplicate(true)
	return item

func get_gem(gem_id: String) -> Dictionary:
	var parts := gem_id.split("_")
	if parts.size() != 2:
		return {}
	var family := parts[0]
	var quality := parts[1]
	if not GEM_DATA.has(family) or not GEM_QUALITIES.has(quality):
		return {}
	var tier := GEM_QUALITIES.find(quality)
	var values: Array = GEM_DATA[family]["values"]
	return {"gem_id": gem_id, "family": family, "quality": quality, "stat": GEM_DATA[family]["stat"], "percent": float(values[tier])}

func get_all_gem_ids() -> Array[String]:
	var result: Array[String] = []
	for family in GEM_FAMILIES:
		for quality in GEM_QUALITIES:
			result.append("%s_%s" % [family, quality])
	return result

func get_quality_upgrade(quality: String) -> Dictionary:
	var index := QUALITIES.find(quality)
	if index < 0 or index >= QUALITIES.size() - 1:
		return {}
	var next_quality := QUALITIES[index + 1]
	var rates := [0.90, 0.75, 0.55, 0.35]
	var costs := [8000, 18000, 45000, 100000]
	return {"quality": next_quality, "chance": rates[index], "cost": costs[index]}

extends Node
## Centralized item blueprints and progression rules for New Conquer Offline.

const SLOTS := ["RightHand", "LeftHand", "Armor", "Helmet", "Necklace", "Boots", "Ring"]
const QUALITIES := ["Normal", "Refined", "Unique", "Super"]
const SOCKET_COUNT := 2
const LEVEL_TIERS := [15, 40, 70, 100, 110, 120]

const GEM_DATA := {
	"Dragon_Normal": {"family": "Dragon", "quality": "Normal", "stat": "physical_attack_pct", "percent": 5.0},
	"Dragon_Super": {"family": "Dragon", "quality": "Super", "stat": "physical_attack_pct", "percent": 10.0},
	"Phoenix_Normal": {"family": "Phoenix", "quality": "Normal", "stat": "magic_attack_pct", "percent": 5.0},
	"Phoenix_Super": {"family": "Phoenix", "quality": "Super", "stat": "magic_attack_pct", "percent": 10.0},
	"Rainbow_Normal": {"family": "Rainbow", "quality": "Normal", "stat": "experience_pct", "percent": 10.0},
	"Rainbow_Super": {"family": "Rainbow", "quality": "Super", "stat": "experience_pct", "percent": 20.0}
}

const WEAPON_BLUEPRINTS := {
	"archer_bow": {
		"name": "Archer Bow", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "RightHand", "allowed_slots": ["RightHand"], "weapon_family": "Bow",
		"quality": "Normal", "plus": 0, "sockets": ["Empty", "Empty"],
		"required_level": 15, "base_stats": {"physical_attack": 30, "magic_attack": 0}
	},
	"archer_arrows": {
		"name": "Arrows", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "LeftHand", "allowed_slots": ["LeftHand"], "weapon_family": "Arrows",
		"quality": "Normal", "plus": 0, "sockets": ["Empty", "Empty"],
		"required_level": 15, "base_stats": {"physical_attack": 8, "magic_attack": 0}
	},
	"assassin_throwing_knife": {
		"name": "Throwing Knife", "allowed_classes": ["Oriental_Assassin"],
		"slot": "RightHand", "allowed_slots": ["RightHand", "LeftHand"], "weapon_family": "ThrowingKnife",
		"quality": "Normal", "plus": 0, "sockets": ["Empty", "Empty"],
		"required_level": 70, "base_stats": {"physical_attack": 42, "magic_attack": 0}
	}
}

const ARMOR_BLUEPRINTS := {
	"archer_armor_15": {
		"name": "Archer Armor", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "Armor", "allowed_slots": ["Armor"], "weapon_family": "",
		"quality": "Normal", "plus": 0, "sockets": ["Empty", "Empty"],
		"required_level": 15, "base_stats": {"defense": 18}
	},
	"archer_helmet_15": {
		"name": "Archer Helmet", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "Helmet", "allowed_slots": ["Helmet"], "weapon_family": "",
		"quality": "Normal", "plus": 0, "sockets": ["Empty", "Empty"],
		"required_level": 15, "base_stats": {"defense": 8}
	},
	"basic_necklace": {
		"name": "Necklace", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "Necklace", "allowed_slots": ["Necklace"], "weapon_family": "",
		"quality": "Normal", "plus": 0, "sockets": ["Empty", "Empty"],
		"required_level": 15, "base_stats": {"max_hp": 10}
	},
	"basic_boots": {
		"name": "Boots", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "Boots", "allowed_slots": ["Boots"], "weapon_family": "",
		"quality": "Normal", "plus": 0, "sockets": ["Empty", "Empty"],
		"required_level": 15, "base_stats": {"defense": 4}
	},
	"basic_ring": {
		"name": "Ring", "allowed_classes": ["Archer", "Oriental_Assassin"],
		"slot": "Ring", "allowed_slots": ["Ring"], "weapon_family": "",
		"quality": "Normal", "plus": 0, "sockets": ["Empty", "Empty"],
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
	item["instance_id"] = instance_id if not instance_id.is_empty() else "%s_%s" % [item_id, str(Time.get_unix_time_from_system())]
	item["sockets"] = item.get("sockets", ["Empty", "Empty"]).duplicate(true)
	return item

func get_gem(gem_id: String) -> Dictionary:
	if not GEM_DATA.has(gem_id):
		return {}
	return GEM_DATA[gem_id].duplicate(true)

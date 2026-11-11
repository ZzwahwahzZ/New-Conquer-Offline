extends Node
## Authoritative classic-class progression, derived stats, XP skill and local persistence.
signal character_changed
signal stats_changed
signal level_up(new_level: int)
signal xp_changed(current_xp: int, required_xp: int)
signal xp_skill_changed(value: float, maximum: float)
const PROMOTION_LEVELS := [15, 40, 70, 100, 110]
const XP_BASE := 100
const CLASS_DATA := {
	"Archer": {"name":"Archer", "name_ar":"الآرتشر", "base":{"strength":15,"agility":35,"vitality":15,"spirit":0}, "weapon_families":["Bow","Arrows"], "evolutions":["Oriental_Assassin"]},
	"Trojan": {"name":"Trojan", "name_ar":"التروجان", "base":{"strength":35,"agility":15,"vitality":20,"spirit":0}, "weapon_families":["Sword","Blade","Club","Axe"], "evolutions":[]},
	"Warrior": {"name":"Warrior", "name_ar":"المحارب", "base":{"strength":25,"agility":15,"vitality":35,"spirit":0}, "weapon_families":["Sword","Blade","Club","Poleaxe"], "evolutions":[]},
	"Water_Taoist": {"name":"Water Taoist", "name_ar":"حاوي الماء", "base":{"strength":5,"agility":10,"vitality":20,"spirit":40}, "weapon_families":["Backsword"], "evolutions":[]},
	"Fire_Taoist": {"name":"Fire Taoist", "name_ar":"حاوي النار", "base":{"strength":5,"agility":10,"vitality":15,"spirit":45}, "weapon_families":["Backsword"], "evolutions":[]},
	"Ninja": {"name":"Ninja", "name_ar":"النينجا", "base":{"strength":20,"agility":35,"vitality":15,"spirit":0}, "weapon_families":["Katana"], "evolutions":[]},
	"Oriental_Assassin": {"name":"Oriental Assassin", "name_ar":"السفاح الشرقي", "base":{"strength":20,"agility":45,"vitality":20,"spirit":0}, "weapon_families":["ThrowingKnife"], "evolutions":[]}
}
var current_class := "Archer"
var level := 1
var experience := 0
var stat_points := 0
var attributes := {"strength":15,"agility":35,"vitality":15,"spirit":0}
var hp := 120
var max_hp := 120
var mp := 40
var max_mp := 40
var stamina := 100.0
var max_stamina := 100.0
var xp_skill := 0.0
var xp_skill_max := 100.0
var skill_proficiency := {"Jump":{"level":1,"xp":0},"Fly":{"level":1,"xp":0},"Scatter":{"level":1,"xp":0},"Rapid_Fire":{"level":1,"xp":0},"Kinetic_Spark":{"level":1,"xp":0},"XP_Mode":{"level":1,"xp":0}}
var _loaded := false

func _ready() -> void:
	call_deferred("_load_character")

func _load_character() -> void:
	var data: Dictionary = GlobalEconomy.load_character_data()
	if not data.is_empty():
		var saved_class := str(data.get("class", "Archer"))
		current_class = saved_class if CLASS_DATA.has(saved_class) else "Archer"
		level = maxi(1, int(data.get("level", 1)))
		experience = maxi(0, int(data.get("experience", 0)))
		stat_points = maxi(0, int(data.get("stat_points", 0)))
		hp = maxi(0, int(data.get("hp", hp)))
		mp = maxi(0, int(data.get("mp", mp)))
		stamina = maxf(0.0, float(data.get("stamina", stamina)))
		xp_skill = clampf(float(data.get("xp_skill", 0.0)), 0.0, xp_skill_max)
		var saved_attributes = data.get("attributes", {})
		if saved_attributes is Dictionary:
			for key in attributes:
				attributes[key] = maxi(0, int(saved_attributes.get(key, attributes[key])))
		var saved_skills = data.get("skill_proficiency", {})
		if saved_skills is Dictionary:
			for skill_id in skill_proficiency:
				var saved = saved_skills.get(skill_id, {})
				if saved is Dictionary:
					skill_proficiency[skill_id] = {"level":maxi(1,int(saved.get("level",1))),"xp":maxi(0,int(saved.get("xp",0)))}
	_recalculate_derived(false)
	_loaded = true
	character_changed.emit()
	stats_changed.emit()
	_emit_xp()
	xp_skill_changed.emit(xp_skill, xp_skill_max)

func get_current_class() -> String: return current_class
func get_level() -> int: return level
func get_required_xp() -> int: return XP_BASE * level
func get_class_name() -> String: return str(CLASS_DATA.get(current_class, {}).get("name", current_class))
func get_class_name_ar() -> String: return str(CLASS_DATA.get(current_class, {}).get("name_ar", get_class_name()))

func get_promotion_stage() -> int:
	var stage := 0
	for milestone in PROMOTION_LEVELS:
		if level >= int(milestone): stage += 1
	return stage

func get_next_promotion_level() -> int:
	for milestone in PROMOTION_LEVELS:
		if level < int(milestone): return int(milestone)
	return 0

func get_physical_attack_bonus() -> int:
	return int(attributes.get("strength", 0)) + int(float(attributes.get("agility", 0)) / 2.0)

func choose_class(class_id: String) -> bool:
	if not CLASS_DATA.has(class_id) or level > 1: return false
	if current_class == class_id:
		_save()
		return true
	current_class = class_id
	attributes = CLASS_DATA[class_id]["base"].duplicate(true)
	_recalculate_derived(false)
	character_changed.emit()
	stats_changed.emit()
	_save()
	return true

func can_evolve_to(class_id: String) -> bool:
	return current_class == "Archer" and class_id == "Oriental_Assassin" and get_promotion_stage() > 0

func evolve_to(class_id: String) -> bool:
	if not can_evolve_to(class_id): return false
	var old_base: Dictionary = CLASS_DATA[current_class]["base"]
	var new_base: Dictionary = CLASS_DATA[class_id]["base"]
	for stat in attributes:
		attributes[stat] = maxi(0, int(attributes[stat]) + int(new_base.get(stat, 0)) - int(old_base.get(stat, 0)))
	current_class = class_id
	_recalculate_derived(false)
	character_changed.emit()
	stats_changed.emit()
	_save()
	return true

func add_experience(amount: int) -> void:
	if amount <= 0: return
	experience += amount
	while experience >= get_required_xp():
		experience -= get_required_xp()
		level += 1
		stat_points += 3
		_recalculate_derived(false)
		level_up.emit(level)
		character_changed.emit()
	_emit_xp()
	stats_changed.emit()
	_save()

func spend_stat_points(stat: String, amount: int = 1) -> bool:
	if not attributes.has(stat) or amount <= 0 or stat_points < amount: return false
	attributes[stat] = int(attributes[stat]) + amount
	stat_points -= amount
	_recalculate_derived(false)
	stats_changed.emit()
	_save()
	return true

func gain_skill_proficiency(skill_id: String, amount: int = 1) -> void:
	if not skill_proficiency.has(skill_id) or amount <= 0: return
	var data: Dictionary = skill_proficiency[skill_id]
	data["xp"] = int(data.get("xp", 0)) + amount
	while int(data["xp"]) >= int(data["level"]) * 20:
		data["xp"] = int(data["xp"]) - int(data["level"]) * 20
		data["level"] = int(data["level"]) + 1
	skill_proficiency[skill_id] = data
	_save()

func get_skill_proficiency(skill_id: String) -> Dictionary:
	var data: Dictionary = skill_proficiency.get(skill_id, {})
	return data.duplicate(true)

func take_damage(amount: int) -> void:
	if amount <= 0: return
	hp = maxi(0, hp - amount)
	stats_changed.emit()
	_save()

func consume_mana(amount: int) -> bool:
	if amount < 0 or mp < amount: return false
	mp -= amount
	stats_changed.emit()
	_save()
	return true

func restore_mana(amount: int) -> void:
	if amount <= 0: return
	mp = mini(max_mp, mp + amount)
	stats_changed.emit()
	_save()

func set_stamina(value: float) -> void:
	stamina = clampf(value, 0.0, max_stamina)
	stats_changed.emit()

func consume_stamina(value: float) -> bool:
	if value < 0.0 or stamina < value: return false
	stamina -= value
	stats_changed.emit()
	_save()
	return true

func restore_stamina(value: float) -> void:
	var previous := stamina
	stamina = minf(max_stamina, stamina + maxf(0.0, value))
	if absf(stamina - previous) >= 0.25: stats_changed.emit()

func add_xp_skill(value: float) -> void:
	if value <= 0.0: return
	xp_skill = minf(xp_skill_max, xp_skill + value)
	xp_skill_changed.emit(xp_skill, xp_skill_max)
	_save()

func consume_xp_skill() -> bool:
	if xp_skill < xp_skill_max: return false
	xp_skill = 0.0
	xp_skill_changed.emit(xp_skill, xp_skill_max)
	_save()
	return true

func _recalculate_derived(restore_resources: bool = false) -> void:
	var vitality := int(attributes.get("vitality", 0))
	var spirit := int(attributes.get("spirit", 0))
	var agility := int(attributes.get("agility", 0))
	max_hp = 100 + vitality * 12 + level * 10
	max_mp = 30 + spirit * 8 + level * 4
	max_stamina = 100.0 + vitality * 0.5 + agility * 0.25
	if restore_resources:
		hp = max_hp
		mp = max_mp
	else:
		hp = clampi(hp, 0, max_hp)
		mp = clampi(mp, 0, max_mp)
	stamina = clampf(stamina, 0.0, max_stamina)

func _emit_xp() -> void: xp_changed.emit(experience, get_required_xp())

func save_character() -> bool:
	_save()
	return _loaded

func _save() -> void:
	if not _loaded: return
	GlobalEconomy.save_character_data({"class":current_class,"level":level,"experience":experience,"stat_points":stat_points,"attributes":attributes.duplicate(true),"hp":hp,"mp":mp,"stamina":stamina,"xp_skill":xp_skill,"skill_proficiency":skill_proficiency.duplicate(true)})

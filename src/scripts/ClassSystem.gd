extends Node
## Classic-inspired class progression and character progression authority.
signal character_changed
signal stats_changed
signal level_up(new_level: int)
signal xp_changed(current_xp: int, required_xp: int)

const CLASS_DATA := {
	"Archer": {"name":"Archer","base":{"strength":15,"agility":35,"vitality":15,"spirit":0},"weapon_families":["Bow","Arrows"],"evolutions":["Oriental_Assassin"]},
	"Oriental_Assassin": {"name":"Oriental Assassin","base":{"strength":20,"agility":45,"vitality":20,"spirit":0},"weapon_families":["ThrowingKnife"],"evolutions":[]},
	"Trojan": {"name":"Trojan","base":{"strength":35,"agility":15,"vitality":20,"spirit":0},"weapon_families":["Sword","Blade","Club","Axe"],"evolutions":[]},
	"Warrior": {"name":"Warrior","base":{"strength":25,"agility":15,"vitality":35,"spirit":0},"weapon_families":["Sword","Blade","Club","Poleaxe"],"evolutions":[]},
	"Water_Taoist": {"name":"Water Taoist","base":{"strength":5,"agility":10,"vitality":20,"spirit":40},"weapon_families":["Backsword"],"evolutions":[]},
	"Fire_Taoist": {"name":"Fire Taoist","base":{"strength":5,"agility":10,"vitality":15,"spirit":45},"weapon_families":[" backsword","Backsword"],"evolutions":[]},
	"Ninja": {"name":"Ninja","base":{"strength":20,"agility":35,"vitality":15,"spirit":0},"weapon_families":["Katana"],"evolutions":[]}
}
const ARCHER_EVOLUTION_LEVELS := [15,40,70,100,110]
const XP_BASE := 100

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
var skill_proficiency := {"Jump":{"level":1,"xp":0},"Fly":{"level":1,"xp":0},"Scatter":{"level":1,"xp":0},"Rapid_Fire":{"level":1,"xp":0}}
var _loaded := false

func _ready() -> void:
	if GlobalEconomy.economy_ready.is_connected(_load_character):
		_load_character()
	else:
		GlobalEconomy.economy_ready.connect(_load_character, CONNECT_ONE_SHOT)

func _load_character() -> void:
	var data := GlobalEconomy.load_character_data()
	if not data.is_empty():
		current_class = str(data.get("class", "Archer"))
		if not CLASS_DATA.has(current_class): current_class = "Archer"
		level = maxi(1, int(data.get("level", 1)))
		experience = maxi(0, int(data.get("experience", 0)))
		stat_points = maxi(0, int(data.get("stat_points", 0)))
		hp = int(data.get("hp", hp))
		mp = int(data.get("mp", mp))
		stamina = float(data.get("stamina", stamina))
		var saved_skills = data.get("skill_proficiency", {})
		if saved_skills is Dictionary:
			for skill_id in skill_proficiency:
				if saved_skills.has(skill_id): skill_proficiency[skill_id] = saved_skills[skill_id].duplicate(true)
		var saved_attributes = data.get("attributes", {})
		if saved_attributes is Dictionary:
			for key in attributes: attributes[key] = maxi(0, int(saved_attributes.get(key, attributes[key])))
	_recalculate_derived(false)
	_loaded = true
	character_changed.emit()
	stats_changed.emit()
	_emit_xp()

func get_current_class() -> String: return current_class
func get_level() -> int: return level
func get_required_xp() -> int: return XP_BASE * level
func get_class_name() -> String: return str(CLASS_DATA.get(current_class, {}).get("name", current_class))
func get_promotion_stage() -> int:
	var stage := 0
	for milestone in ARCHER_EVOLUTION_LEVELS:
		if level >= int(milestone): stage += 1
	return stage
func get_physical_attack_bonus() -> int:
	return int(attributes.get("strength", 0)) + int(int(attributes.get("agility", 0)) / 2)

func choose_class(class_id: String) -> bool:
	if not CLASS_DATA.has(class_id): return false
	if level > 1 and class_id != current_class: return false
	current_class = class_id
	var base_stats: Dictionary = CLASS_DATA[class_id]["base"]
	attributes = base_stats.duplicate(true)
	_recalculate_derived()
	character_changed.emit()
	_save()
	return true

func can_evolve_to(class_id: String) -> bool:
	if current_class == "Archer" and class_id == "Oriental_Assassin":
		return ARCHER_EVOLUTION_LEVELS.has(level)
	return false

func evolve_to(class_id: String) -> bool:
	if not can_evolve_to(class_id): return false
	current_class = class_id
	_recalculate_derived()
	character_changed.emit()
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
		if current_class == "Archer" and ARCHER_EVOLUTION_LEVELS.has(level):
			# Evolution is offered at the classic milestone; never auto-change the player's class.
			character_changed.emit()
	_emit_xp()
	stats_changed.emit()
	_save()

func spend_stat_points(stat: String, amount: int = 1) -> bool:
	if not attributes.has(stat) or amount <= 0 or stat_points < amount: return false
	attributes[stat] = int(attributes[stat]) + amount
	stat_points -= amount
	_recalculate_derived()
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

func set_stamina(value: float) -> void: stamina = clampf(value, 0.0, max_stamina)
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

func _recalculate_derived(save: bool = true) -> void:
	var vitality := int(attributes.get("vitality", 0))
	var spirit := int(attributes.get("spirit", 0))
	max_hp = 100 + vitality * 12 + level * 10
	max_mp = 30 + spirit * 8 + level * 4
	max_stamina = 100.0 + vitality * 0.5 + int(attributes.get("agility", 0)) * 0.25
	hp = clampi(hp, 1, max_hp)
	mp = clampi(mp, 0, max_mp)
	stamina = clampf(stamina, 0.0, max_stamina)
	if save: stats_changed.emit()

func _emit_xp() -> void: xp_changed.emit(experience, get_required_xp())
func _save() -> void:
	if _loaded:
		GlobalEconomy.save_character_data({"class":current_class,"level":level,"experience":experience,"stat_points":stat_points,"attributes":attributes.duplicate(true),"hp":hp,"mp":mp,"stamina":stamina,"skill_proficiency":skill_proficiency.duplicate(true)})

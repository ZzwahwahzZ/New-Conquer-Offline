extends SceneTree
## Step 10 regression checks. Run with Godot 4.3 headless.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe = load("res://src/scripts/ClassSystem.gd").new()
	assert(probe.PROMOTION_LEVELS == [15,40,70,100,110])
	assert(probe.CLASS_DATA.has("Archer") and probe.CLASS_DATA.has("Oriental_Assassin"))
	probe.current_class = "Archer"
	probe.stat_points = 3
	var archer: Dictionary = probe.auto_distribute_stat_points()
	assert(archer.agility == 2 and archer.vitality == 1)
	assert(probe.stat_points == 0)
	assert(not probe.spend_stat_points("strength",1))
	probe.current_class = "Trojan"
	probe.stat_points = 3
	var trojan: Dictionary = probe.auto_distribute_stat_points()
	assert(trojan.strength + trojan.vitality == 3)
	probe.current_class = "Warrior"
	probe.stat_points = 3
	var warrior: Dictionary = probe.auto_distribute_stat_points()
	assert(warrior.vitality + warrior.strength == 3)
	probe.current_class = "Water_Taoist"
	probe.stat_points = 3
	var taoist: Dictionary = probe.auto_distribute_stat_points()
	assert(taoist.spirit + taoist.vitality == 3)
	probe.level = 14
	assert(not probe.can_promote())
	probe.level = 15
	assert(probe.can_promote())
	assert(probe.promote())
	assert(probe.promotion_stage == 1)
	assert(probe.get_title() != "Novice")
	assert(not probe.can_promote())
	assert(probe.skill_proficiency.has("Double_Slash"))
	var player_script = load("res://src/scripts/Player.gd")
	assert(player_script != null)
	var player_source := FileAccess.get_file_as_string("res://src/scripts/Player.gd")
	assert(player_source.contains('"Double_Slash"'))
	var hud_source := FileAccess.get_file_as_string("res://src/scripts/HUD.gd")
	assert(hud_source.contains("KEY_C") and hud_source.contains("KEY_K"))
	assert(hud_source.contains("notify_auto_allocation"))
	assert(load("res://src/scripts/CharacterStatusUI.gd") != null)
	assert(load("res://src/scripts/SkillsUI.gd") != null)
	assert(ResourceLoader.exists("res://src/scenes/CharacterStatusUI.tscn"))
	assert(ResourceLoader.exists("res://src/scenes/SkillsUI.tscn"))
	var economy_source := FileAccess.get_file_as_string("res://src/scripts/GlobalEconomy.gd")
	assert(economy_source.contains('"character_data":_character_data.duplicate(true)'))
	print("STEP10_AUTO_ATTRIBUTES_STATUS_SKILLS_PROMOTION_PASS")
	quit(0)

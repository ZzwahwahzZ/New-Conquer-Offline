extends SceneTree
## Step 9 smoke checks. Run with Godot 4.3 headless.
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	assert(ClassSystem.CLASS_DATA.has("Archer"))
	assert(ClassSystem.CLASS_DATA.has("Trojan"))
	assert(ClassSystem.CLASS_DATA.has("Warrior"))
	assert(ClassSystem.CLASS_DATA.has("Water_Taoist"))
	assert(ClassSystem.CLASS_DATA.has("Fire_Taoist"))
	assert(ClassSystem.CLASS_DATA.has("Ninja"))
	assert(ClassSystem.CLASS_DATA.has("Oriental_Assassin"))
	assert(ClassSystem.PROMOTION_LEVELS == [15, 40, 70, 100, 110])
	assert(ClassSystem.get_required_xp() > 0)
	assert(ClassSystem.get_next_promotion_level() == 15)
	assert(ClassSystem.get_skill_proficiency("Fly").get("level", 0) == 1)
	assert(ClassSystem.get_skill_proficiency("Kinetic_Spark").get("level", 0) == 1)
	assert(load("res://src/scripts/Player.gd") != null)
	assert(load("res://src/scripts/GearSystem.gd") != null)
	assert(load("res://src/scripts/GlobalEconomy.gd") != null)
	print("STEP9_CLASS_SYSTEM_SMOKE_TEST_PASS")
	quit(0)

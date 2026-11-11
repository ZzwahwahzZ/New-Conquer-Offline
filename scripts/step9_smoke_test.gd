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
	assert(ClassSystem.get_skill_proficiency("Path_of_Shadow").get("level", 0) == 1)
	ClassSystem._loaded = false
	ClassSystem.current_class = "Archer"
	ClassSystem.oriental_assassin_unlocked = false
	ClassSystem.level = 39
	assert(not ClassSystem.can_evolve_to("Oriental_Assassin"))
	ClassSystem.level = 40
	assert(ClassSystem.can_evolve_to("Oriental_Assassin"))
	assert(ClassSystem.evolve_to("Oriental_Assassin"))
	assert(ClassSystem.is_path_shadow_unlocked())
	assert(ClassSystem.current_class == "Oriental_Assassin")
	assert(ClassSystem.toggle_path_of_shadow())
	assert(ClassSystem.current_class == "Archer")
	assert(ClassSystem.toggle_path_of_shadow())
	assert(ClassSystem.current_class == "Oriental_Assassin")
	assert(load("res://src/scripts/Player.gd") != null)
	assert(load("res://src/scripts/GearSystem.gd") != null)
	assert(load("res://src/scripts/GlobalEconomy.gd") != null)
	print("STEP9_PATH_OF_SHADOW_LEVEL40_SMOKE_TEST_PASS")
	quit(0)

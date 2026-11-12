extends SceneTree

# SceneTree scripts expose get_tree().quit() directly; this accessor keeps explicit tree-style shutdown calls.
func get_tree() -> SceneTree:
	return self
## Step 13 offline roster, guild, pool and density smoke test.
## Run: godot --headless --path . --script scripts/step13_smoke_test.gd
const Roster = preload("res://src/scripts/VirtualPlayerRoster.gd")
const AI_MANAGER_PATH := "res://src/scripts/AIPlayersManager.gd"
const AI_SCENE_PATH := "res://src/scenes/AIPlayer.tscn"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var roster = Roster.new()
	roster.build_roster()
	if roster.players.size() != 200:
		failures.append("Roster must contain exactly 200 virtual players")
	if roster.guilds.size() != 8:
		failures.append("Roster must contain exactly 8 guilds")
	if roster.get_all_players().size() != 200:
		failures.append("Public roster API did not return 200 player records")
	for bot_data in roster.players:
		for key in ["id","name","class_type","level","gear_plus","gear_quality","has_wings","guild_name","guild_donation","guild_rank"]:
			if not bot_data.has(key):
				failures.append("Bot data field missing: " + key)
				break
	if not roster.validate_data():
		failures.append("Guild structure / one-leader / leader equipment validation failed")
	for guild_name in Roster.GUILD_NAMES:
		var guild: Dictionary = roster.get_guild(guild_name)
		if roster.get_guild_members(guild_name).size() != 25:
			failures.append("Guild must have 25 members: " + guild_name)
		for key in ["guild_name","guild_fund","bulletin","allies","enemies"]:
			if not guild.has(key):
				failures.append("Guild field missing: %s/%s" % [guild_name,key])
	var manager_script := load(AI_MANAGER_PATH)
	var bot_scene := load(AI_SCENE_PATH) as PackedScene
	if manager_script == null:
		failures.append("AIPlayersManager script failed to load")
	if bot_scene == null:
		failures.append("AIPlayer scene failed to load")
	if bot_scene != null:
		var bot := bot_scene.instantiate()
		if bot == null:
			failures.append("AIPlayer scene could not instantiate")
		else:
			bot.free()
	var actor_source := FileAccess.get_file_as_string("res://src/scripts/AIPlayer.gd")
	if not actor_source.contains("arc_jump_to") or not actor_source.contains("simulate_gold_pickup") or not actor_source.contains("set_idle_lod"):
		failures.append("Arc jump, virtual gold pickup, or idle LOD actor API is missing")
	var manager_source := FileAccess.get_file_as_string(AI_MANAGER_PATH)
	if not manager_source.contains("CITY_CAP := 40") or not manager_source.contains("HUNT_CAP := 3"):
		failures.append("Safe-zone 40 / hunting-zone 3 caps are missing")
	if not manager_source.contains("_assign_city_behavior") or not manager_source.contains("_assign_hunting_behavior"):
		failures.append("Safe-zone NPC behavior / hunting behavior is missing")
	if not manager_source.contains("GUILD_DONATION_INTERVAL") or not manager_source.contains("push_simulated_chat"):
		failures.append("Guild donations or chat feed integration is missing")
	if not manager_source.contains("_spawn_virtual_gold") or not manager_source.contains("_update_virtual_gold"):
		failures.append("Hunting-zone virtual gold pickup simulation is missing")
	if not manager_source.contains("recycle_all()") or not manager_source.contains("set_idle_lod"):
		failures.append("Clean pooling or idle LOD integration is missing")
	if not manager_source.contains("SPAWN_BATCH := 2") or not manager_source.contains("SPAWN_INTERVAL := 0.1"):
		failures.append("Staggered spawning must be 2 bots per 0.1 seconds")
	if not manager_source.contains("func recycle_all()") or not manager_source.contains("func get_pool_count()") or not manager_source.contains("func get_queued_count()"):
		failures.append("Pool cleanup / inspection API is missing")
	var world_source := FileAccess.get_file_as_string("res://src/scripts/WorldManager.gd")
	var hud_source := FileAccess.get_file_as_string("res://src/scripts/HUD.gd")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	if not world_source.contains("AIPlayersManager.gd") or not world_source.contains("ai_players_manager"):
		failures.append("WorldManager integration is missing")
	if not hud_source.contains("push_simulated_chat"):
		failures.append("HUD simulated chat API is missing")
	var expected_autoloads := ["ClassSystem=","GearDatabase=","GearSystem=","GlobalEconomy=","GameState="]
	var last_index := -1
	for autoload_name in expected_autoloads:
		var current_index := project_source.find(autoload_name)
		if current_index <= last_index:
			failures.append("Autoload order changed: " + autoload_name)
		last_index = current_index
	if failures.is_empty():
		print("STEP13_ROSTER_GUILDS_POOL_DENSITY_STATIC_PASS")
		print("Roster: 200 | Guilds: 8 | Members per guild: 25 | Safe cap: 40 | Hunting cap: 3")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("STEP13_SMOKE_TEST_FAIL: %d issue(s)" % failures.size())
		get_tree().quit(1)

extends SceneTree
## Step 14 guild membership, treasury, v6 persistence and pole destruction smoke test.
## Run: godot --headless --path . --script scripts/step14_smoke_test.gd

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	# Standalone SceneTree tests resolve Autoloads dynamically from the root.
	var economy: Node = root.get_node_or_null("GlobalEconomy")
	var game_state: Node = root.get_node_or_null("GameState")
	var class_system: Node = root.get_node_or_null("ClassSystem")
	if not is_instance_valid(economy) or not is_instance_valid(game_state) or not is_instance_valid(class_system):
		push_error("Step 14 requires GlobalEconomy, GameState and ClassSystem Autoloads")
		quit(1)
		return
	var economy_script := load("res://src/scripts/GlobalEconomy.gd") as GDScript
	var economy_constants: Dictionary = economy_script.get_script_constant_map() if economy_script != null else {}
	var save_version := int(economy_constants.get("SAVE_VERSION", -1))
	var original_gold: int = int(economy.get("current_gold"))
	var original_guild_data: Dictionary = economy.call("load_guild_data")
	var original_profile: Dictionary = game_state.get("profile").duplicate(true)
	var original_level: int = int(class_system.get("level"))
	var original_autoloads := FileAccess.get_file_as_string("res://project.godot")
	var system := Node.new()
	system.name = "GuildSystemSmokeTest"
	system.set_script(load("res://src/scripts/GuildSystem.gd"))
	root.add_child(system)
	await process_frame
	economy.set("current_gold", maxi(original_gold,5000000))
	economy.call("save_gold")
	class_system.set("level", maxi(original_level,40))
	system.set("player_guild_name","")
	system.set("player_guild_rank","")
	system.set("player_guild_donation",0)
	var pharaoh_fund_before := int(system.call("get_guild","Pharaohs").get("guild_fund",0))
	if not bool(system.call("join_guild","Pharaohs")):
		failures.append("Could not join an existing classic guild")
	elif str(system.get("player_guild_rank")) != "Member":
		failures.append("Joined player must receive Member rank")
	if not bool(system.call("donate_gold",350000)) or str(system.get("player_guild_rank")) != "Supervisor":
		failures.append("350,000 Gold donation did not promote to Supervisor")
	if not bool(system.call("donate_gold",550000)) or str(system.get("player_guild_rank")) != "Honorary Deputy Leader":
		failures.append("900,000 cumulative donation did not promote to Honorary Deputy Leader")
	if not bool(system.call("donate_gold",1600000)) or str(system.get("player_guild_rank")) != "Deputy Leader":
		failures.append("2,500,000 cumulative donation did not promote to Deputy Leader")
	if int(system.call("get_guild","Pharaohs").get("guild_fund",0)) != pharaoh_fund_before + 2500000:
		failures.append("Classic guild treasury does not match player donations")
	if float(system.call("get_attack_multiplier")) <= 1.0 or float(system.call("get_defense_multiplier")) <= 1.0 or float(system.call("get_xp_multiplier")) <= 1.0:
		failures.append("Guild rank and treasury buffs were not applied")
	if not bool(system.call("leave_guild")):
		failures.append("Could not leave the classic guild before founding a new one")
	var test_guild := "S14_%d" % (Time.get_ticks_msec() % 1000000)
	var gold_before_create := int(economy.get("current_gold"))
	if not bool(system.call("create_guild",test_guild)):
		failures.append("Could not found a guild at level 40 for 1,000,000 Gold")
	else:
		if str(system.get("player_guild_rank")) != "Guild Leader":
			failures.append("Guild founder did not receive Guild Leader rank")
		if int(economy.get("current_gold")) != gold_before_create - 1000000:
			failures.append("Guild foundation did not deduct exactly 1,000,000 Gold")
		if not bool(system.call("set_bulletin","Step 14 smoke guild bulletin")):
			failures.append("Guild Leader could not update the guild bulletin")
		if not bool(system.call("set_diplomacy","Dragons","Ally")) or not bool(system.call("set_diplomacy","Vipers","Enemy")):
			failures.append("Guild Leader could not update Ally/Enemy diplomacy")
		if not bool(system.call("donate_gold",250000)):
			failures.append("Founder could not donate to the new guild treasury")
		if int(system.call("get_guild",test_guild).get("guild_fund",0)) != 250000:
			failures.append("New guild treasury does not match founder donation")
		var saved: Dictionary = economy.call("load_guild_data") as Dictionary
		if str(saved.get("player_guild_name","")) != test_guild:
			failures.append("Guild membership was not serialized in the v6 save envelope")
		if int(saved.get("player_guild_donation",0)) != 250000:
			failures.append("Player guild donation total was not persisted")
		if int(saved.get("guilds",{}).get(test_guild,{}).get("guild_fund",0)) != 250000:
			failures.append("Guild treasury was not persisted")
		var saved_guild: Dictionary = saved.get("guilds",{}).get(test_guild,{})
		if str(saved_guild.get("bulletin","")) != "Step 14 smoke guild bulletin" or not Array(saved_guild.get("allies",[])).has("Dragons") or not Array(saved_guild.get("enemies",[])).has("Vipers"):
			failures.append("Guild bulletin and diplomacy relations were not persisted")

	var arena_scene := load("res://src/scenes/world/GuildWarArena.tscn") as PackedScene
	if arena_scene == null:
		failures.append("GuildWarArena scene failed to load")
	else:
		var arena := arena_scene.instantiate()
		root.add_child(arena)
		await process_frame
		if not is_instance_valid(arena.get("guild_pole")):
			failures.append("Guild Pole was not created in the arena")
		else:
			arena.set("gates_destroyed",true)
			arena.get("guild_pole").call("take_damage",60000)
			if str(system.get("war_winner_guild")) != test_guild:
				failures.append("Destroying Guild Pole did not award control to the highest-damage guild")
			if str(game_state.get("profile").get("guild_war_title","")) != "Guild War Winner":
				failures.append("Winning player did not receive Guild War Winner title")
		arena.queue_free()
		await process_frame

	if save_version != 6 or int(economy.get("_loaded_save_version")) != 6:
		failures.append("GlobalEconomy save version did not migrate to v6")
	if not economy.call("load_guild_data").has("war_winner_guild"):
		failures.append("Guild War winner was not written to v6 guild data")
	if not original_autoloads.contains("ClassSystem=") or not original_autoloads.contains("GameState=") or original_autoloads.contains("GuildSystem="):
		failures.append("Existing Autoloads changed or GuildSystem was incorrectly registered as an Autoload")
	var class_source := FileAccess.get_file_as_string("res://src/scripts/ClassSystem.gd")
	var player_source := FileAccess.get_file_as_string("res://src/scripts/Player.gd")
	if not class_source.contains("get_defense_multiplier") or not class_source.contains("get_xp_multiplier") or not player_source.contains("_guild_attack_multiplier"):
		failures.append("Guild attack, defense, or XP bonuses are not wired into gameplay")
	var npc_source := FileAccess.get_file_as_string("res://src/scripts/NPCSystem.gd")
	var ui_scene := load("res://src/scenes/GuildUI.tscn") as PackedScene
	var target_script := load("res://src/scripts/GuildWarTarget.gd")
	if not npc_source.contains("guild_director"):
		failures.append("Guild Director NPC integration is missing")
	if ui_scene == null:
		failures.append("GuildUI scene failed to load")
	if target_script == null:
		failures.append("Guild War destructible target script failed to load")

	system.queue_free()
	await process_frame
	economy.set("current_gold", original_gold)
	economy.call("save_gold")
	economy.call("save_guild_data", original_guild_data)
	game_state.set("profile", original_profile)
	game_state.call("save_local")
	class_system.set("level", original_level)

	if failures.is_empty():
		print("STEP14_GUILD_MEMBERSHIP_DONATIONS_SAVE_V6_POLE_DESTRUCTION_PASS")
		print("Guild join/create: PASS | donation ranks: PASS | v6 persistence: PASS | arena pole: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("STEP14_SMOKE_TEST_FAIL: %d issue(s)" % failures.size())
		quit(1)

extends SceneTree
const RIG_FACTORY = preload("res://src/scripts/RiggedCharacterFactory.gd")
## Step 11 static/resource smoke checks. Run with Godot 4.3 headless.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world_ids := ["TwinCity","DesertLand","VolcanoLand","IceLand","Waterlands","DarkForest"]
	var expected_levels := [[1,15],[15,40],[40,70],[70,95],[95,115],[115,130]]
	for index in range(world_ids.size()):
		var path := "res://src/scenes/world/%s.tscn" % world_ids[index]
		assert(ResourceLoader.exists(path), "Missing settlement: " + path)
		var packed := load(path) as PackedScene
		assert(packed != null)
		var settlement := packed.instantiate() as Node3D
		root.add_child(settlement)
		await process_frame
		assert(settlement.get_node_or_null("TerrainCollision") != null)
		assert(settlement.get_node_or_null("TerrainAssetSlot") != null)
		assert(settlement.get_node_or_null("ArchitectureAssetSlot") != null)
		assert(settlement.get_node_or_null("FoliageAssetSlot") != null)
		assert(settlement.get_node_or_null("SanctuaryAnchors/RareSanctuaryNorthEast") != null)
		assert(settlement.get_node_or_null("SanctuaryAnchors/BossSanctuarySouthWest") != null)
		assert(int(settlement.get("level_min")) == expected_levels[index][0])
		assert(int(settlement.get("level_max")) == expected_levels[index][1])
		settlement.queue_free()
		await process_frame

	var database_script = load("res://src/scripts/MonsterDatabase.gd")
	var database = database_script.new()
	for world_id in world_ids:
		assert(database.get_settlement_monsters(world_id).size() >= 3)
		assert(database.get_sanctuary_monsters(world_id).size() >= 2)
	var classic_names := ["Pheasant","Turtledove","Apparition","Bandit","GiantApe","SandMonster","Birdman"]
	var all_monsters: String = database_script.get_source_code()
	for monster_name in classic_names:
		assert(all_monsters.contains(monster_name))

	assert(load("res://src/scripts/WorldManager.gd") != null)
	assert(load("res://src/scripts/WorldTeleporter.gd") != null)
	assert(load("res://src/scripts/SettlementWorld.gd") != null)
	assert(load("res://src/scripts/MiniMapUI.gd") != null)
	assert(load("res://src/scripts/Monster.gd") != null)
	assert(ResourceLoader.exists("res://src/scenes/Monster.tscn"))
	assert(ResourceLoader.exists("res://src/scenes/CPDrop.tscn"))
	var monster_scene := (load("res://src/scenes/Monster.tscn") as PackedScene).instantiate()
	root.add_child(monster_scene)
	await process_frame
	var monster_skeleton := RIG_FACTORY.find_skeleton(monster_scene)
	assert(monster_skeleton != null and monster_skeleton.get_bone_count() > 0, "Monster must load a skinned GLB skeleton")
	var animation_player := RIG_FACTORY.find_animation_player(monster_scene)
	assert(animation_player != null and not animation_player.get_animation_list().is_empty(), "Monster must retain imported GLB animations")
	assert(monster_scene.get_node_or_null("Rigged_Monster") != null, "Monster must use the imported rigged visual, not the old capsule")
	monster_scene.queue_free()
	await process_frame

	var world_manager_source := FileAccess.get_file_as_string("res://src/scripts/WorldManager.gd")
	assert(world_manager_source.contains("MAX_MONSTER_POOL"))
	assert(world_manager_source.contains("MAX_GOLD_POOL"))
	assert(world_manager_source.contains("MAX_IMPACT_POOL"))
	assert(world_manager_source.contains("set_sleeping"))
	assert(world_manager_source.contains("CACHE_MODE_IGNORE_DEEP"))
	assert(world_manager_source.contains("get_minimap_snapshot"))
	assert(world_manager_source.contains("change_settlement"))
	var teleporter_source := FileAccess.get_file_as_string("res://src/scripts/WorldTeleporter.gd")
	assert(teleporter_source.contains("travel_to"))
	var minimap_source := FileAccess.get_file_as_string("res://src/scripts/MiniMapUI.gd")
	assert(minimap_source.contains("X: %04d   Y: %04d"))
	assert(minimap_source.contains("draw_circle"))
	var economy_source := FileAccess.get_file_as_string("res://src/scripts/GlobalEconomy.gd")
	assert(economy_source.contains("NOTIFICATION_APPLICATION_PAUSED"))
	assert(economy_source.contains("NOTIFICATION_WM_CLOSE_REQUEST"))
	assert(economy_source.contains("save_runtime_state"))
	var enemy_source := FileAccess.get_file_as_string("res://src/scripts/Enemy.gd")
	assert(enemy_source.contains("recycle_monster"))
	assert(enemy_source.contains("spawn_impact_effect"))
	var drop_source := FileAccess.get_file_as_string("res://src/scripts/CPDrop.gd")
	assert(drop_source.contains("reset_for_pool"))
	assert(drop_source.contains("recycle_gold"))
	var hud_source := FileAccess.get_file_as_string("res://src/scripts/HUD.gd")
	assert(hud_source.contains("MiniMapUI"))
	assert(hud_source.contains("WorldTravelPanel"))
	assert(hud_source.contains("KEY_M"))
	var gear_source := FileAccess.get_file_as_string("res://src/scripts/GearDatabase.gd")
	for item_id in ["trojan_blade_15","warrior_sword_15","taoist_backsword_15","ninja_katana_15"]:
		assert(gear_source.contains(item_id))

	var game_state_source := FileAccess.get_file_as_string("res://scripts/game_state.gd")
	assert(game_state_source.contains("settlement_id"))
	assert(game_state_source.contains("f.close()"))
	var monster_source := FileAccess.get_file_as_string("res://src/scripts/Monster.gd")
	assert(monster_source.contains("func _die()"))
	assert(monster_source.contains("Skeleton3D"))
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	var class_index := project_source.find("ClassSystem=")
	var database_index := project_source.find("GearDatabase=")
	var gear_index := project_source.find("GearSystem=")
	var economy_index := project_source.find("GlobalEconomy=")
	assert(class_index >= 0 and database_index > class_index and gear_index > database_index and economy_index > gear_index)
	assert(not project_source.contains("WorldManager="))
	print("STEP11_OPEN_WORLD_SIX_SETTLEMENTS_MONSTER_POOL_MINIMAP_AUTOSAVE_PASS")
	quit(0)

extends SceneTree
## Static resource-load and architecture regression audit for Godot 4.3.
## Run: godot --headless --path . --script scripts/step12_smoke_test.gd

const SCRIPT_PATHS := [
	"res://scripts/game_state.gd",
	"res://scripts/local_enemy.gd",
	"res://scripts/main.gd",
	"res://scripts/offline_smoke_test.gd",
	"res://scripts/player_controller.gd",
	"res://scripts/step9_smoke_test.gd",
	"res://scripts/step10_smoke_test.gd",
	"res://scripts/step11_smoke_test.gd",
	"res://scripts/step12_smoke_test.gd",
	"res://src/scripts/CPDrop.gd",
	"res://src/scripts/CharacterSelection.gd",
	"res://src/scripts/CharacterStatusUI.gd",
	"res://src/scripts/ClassSystem.gd",
	"res://src/scripts/Enemy.gd",
	"res://src/scripts/GearDatabase.gd",
	"res://src/scripts/GearSystem.gd",
	"res://src/scripts/GlobalEconomy.gd",
	"res://src/scripts/HUD.gd",
	"res://src/scripts/InventoryManager.gd",
	"res://src/scripts/InventoryUI.gd",
	"res://src/scripts/IsometricCamera.gd",
	"res://src/scripts/MiniMapUI.gd",
	"res://src/scripts/Monster.gd",
	"res://src/scripts/MonsterDatabase.gd",
	"res://src/scripts/NPC.gd",
	"res://src/scripts/NPCSystem.gd",
	"res://src/scripts/Player.gd",
	"res://src/scripts/QuestSystem.gd",
	"res://src/scripts/QuestUI.gd",
	"res://src/scripts/SettlementWorld.gd",
	"res://src/scripts/ShopUI.gd",
	"res://src/scripts/ShoppingMallUI.gd",
	"res://src/scripts/SkillsUI.gd",
	"res://src/scripts/UpgradeMarketUI.gd",
	"res://src/scripts/WarehouseUI.gd",
	"res://src/scripts/WorldManager.gd",
	"res://src/scripts/WorldTeleporter.gd"
]

const SCENE_PATHS := [
	"res://scenes/main.tscn",
	"res://src/scenes/CPDrop.tscn",
	"res://src/scenes/CharacterSelection.tscn",
	"res://src/scenes/CharacterStatusUI.tscn",
	"res://src/scenes/HUD.tscn",
	"res://src/scenes/InventoryUI.tscn",
	"res://src/scenes/IsometricCamera.tscn",
	"res://src/scenes/Monster.tscn",
	"res://src/scenes/NPC.tscn",
	"res://src/scenes/QuestUI.tscn",
	"res://src/scenes/ShopUI.tscn",
	"res://src/scenes/ShoppingMallUI.tscn",
	"res://src/scenes/SkillsUI.tscn",
	"res://src/scenes/UpgradeMarketUI.tscn",
	"res://src/scenes/WarehouseUI.tscn",
	"res://src/scenes/world/TwinCity.tscn",
	"res://src/scenes/world/DesertLand.tscn",
	"res://src/scenes/world/VolcanoLand.tscn",
	"res://src/scenes/world/IceLand.tscn",
	"res://src/scenes/world/Waterlands.tscn",
	"res://src/scenes/world/DarkForest.tscn"
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for path in SCRIPT_PATHS:
		if load(path) == null:
			failures.append("Script failed to load/parse: " + path)
	for path in SCENE_PATHS:
		var packed := load(path) as PackedScene
		if packed == null:
			failures.append("Scene failed to load: " + path)

	var project_source := FileAccess.get_file_as_string("res://project.godot")
	var class_index := project_source.find("ClassSystem=")
	var database_index := project_source.find("GearDatabase=")
	var gear_index := project_source.find("GearSystem=")
	var economy_index := project_source.find("GlobalEconomy=")
	var state_index := project_source.find("GameState=")
	if not (class_index >= 0 and database_index > class_index and gear_index > database_index and economy_index > gear_index and state_index > economy_index):
		failures.append("Autoload order changed or is incomplete")
	if project_source.contains("WorldManager=") or project_source.contains("QuestSystem=") or project_source.contains("NPCSystem="):
		failures.append("World/quest/NPC managers must remain scene-local, not Autoloads")

	var economy_source := FileAccess.get_file_as_string("res://src/scripts/GlobalEconomy.gd")
	var game_state_source := FileAccess.get_file_as_string("res://scripts/game_state.gd")
	var gear_source := FileAccess.get_file_as_string("res://src/scripts/GearSystem.gd")
	var warehouse_source := FileAccess.get_file_as_string("res://src/scripts/WarehouseUI.gd")
	var hud_source := FileAccess.get_file_as_string("res://src/scripts/HUD.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var world_source := FileAccess.get_file_as_string("res://src/scripts/WorldManager.gd")
	var monster_source := FileAccess.get_file_as_string("res://src/scripts/Monster.gd")
	var drop_source := FileAccess.get_file_as_string("res://src/scripts/CPDrop.gd")

	if not economy_source.contains("SAVE_VERSION := 5") or not economy_source.contains("_normalize_persistent_state()") or not economy_source.contains("warehouse_items.size() < 80"):
		failures.append("Save v5 / 80-slot safe initialization is incomplete")
	if not economy_source.contains("NOTIFICATION_APPLICATION_PAUSED") or not economy_source.contains("NOTIFICATION_WM_CLOSE_REQUEST"):
		failures.append("Automatic pause/close save hooks are missing")
	if not game_state_source.contains("f.close()") or not game_state_source.contains("var merged :="):
		failures.append("GameState JSON load must close the file and merge safe defaults")
	if gear_source.contains('game_state.profile["inventory"] = inventory.duplicate(true)'):
		failures.append("Gear inventory must not overwrite general item inventory")
	if not gear_source.contains("_migrate_legacy_inventory()"):
		failures.append("Legacy gear inventory migration is missing")
	if not warehouse_source.contains("CAPACITY=80") or not warehouse_source.contains('["gem","plus_stone"]'):
		failures.append("Warehouse capacity or plus-stone/gem routing is incomplete")
	for ui_path in ["QuestUI.gd","ShopUI.gd","ShoppingMallUI.gd","WarehouseUI.gd"]:
		var ui_source := FileAccess.get_file_as_string("res://src/scripts/" + ui_path)
		if not ui_source.contains("panel.hide()"):
			failures.append("UI panel must start hidden: " + ui_path)

	if not main_source.contains("KEY_I") or not main_source.contains("KEY_U"):
		failures.append("I/U keyboard shortcuts are missing")
	if not hud_source.contains("KEY_C") or not hud_source.contains("KEY_K") or not hud_source.contains("KEY_M"):
		failures.append("C/K/M keyboard shortcuts are missing")
	if not hud_source.contains("_build_step12_widgets()") or not hud_source.contains("_interact_nearest_npc"):
		failures.append("Step 12 touch controls are not connected")
	if not world_source.contains("MAX_MONSTER_POOL") or not world_source.contains("MAX_GOLD_POOL") or not world_source.contains("MAX_IMPACT_POOL") or not world_source.contains("CACHE_MODE_IGNORE_DEEP"):
		failures.append("Bounded pools or clean world streaming are missing")
	if not monster_source.contains("death_token == _death_generation") or not drop_source.contains("collection_generation != _pool_generation"):
		failures.append("Async pooled-object reuse race guard is missing")

	var economy = root.get_node_or_null("GlobalEconomy")
	if is_instance_valid(economy):
		var warehouse_data = economy.get("warehouse_items")
		if typeof(warehouse_data) != TYPE_ARRAY or warehouse_data.size() != 80:
			failures.append("Runtime warehouse does not contain exactly 80 slots")
	var game_state = root.get_node_or_null("GameState")
	if is_instance_valid(game_state):
		var profile_data = game_state.get("profile")
		if typeof(profile_data) != TYPE_DICTIONARY or typeof(profile_data.get("inventory", [])) != TYPE_ARRAY:
			failures.append("Runtime GameState inventory is not a valid Array")

	if failures.is_empty():
		print("STEP12_STATIC_RESOURCE_AND_ARCHITECTURE_AUDIT_PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("STEP12_STATIC_RESOURCE_AND_ARCHITECTURE_AUDIT_FAIL: %d issue(s)" % failures.size())
		quit(1)

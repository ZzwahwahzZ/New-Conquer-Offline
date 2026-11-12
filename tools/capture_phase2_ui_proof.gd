extends SceneTree
## Phase 2 real-render UI proof: six distinct 1280x720 runtime captures.
const MAIN_SCENE := "res://scenes/main.tscn"
const OUT := "res://reports/phase2-ui"
const ThemeManager = preload("res://src/scripts/ui/RPGIconThemeManager.gd")
func _initialize() -> void:
	call_deferred("_run")
func _fail(message: String) -> void:
	push_error("PHASE2_UI_FAIL: " + message)
	quit(1)
func _save(name: String) -> bool:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("PHASE2_UI_FAIL: empty viewport for " + name)
		return false
	var path := OUT.path_join(name)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("PHASE2_UI_FAIL: save error %d for %s" % [error, path])
		return false
	print("PHASE2_UI_CAPTURED: %s %dx%d" % [path, image.get_width(), image.get_height()])
	return true
func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("main scene is missing")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	# Resolve autoloads at runtime; never reference their names as parser-time identifiers.
	var gear_database: Node = root.get_node_or_null("GearDatabase")
	var gear_system: Node = root.get_node_or_null("GearSystem")
	if gear_database == null or gear_system == null:
		_fail("GearDatabase or GearSystem autoload is missing at runtime")
		return
	var hud := main.get_node_or_null("HUD") as CanvasLayer
	var classic := main.get_node_or_null("HUD/ClassicHUD") as Control
	var quest := main.get_node_or_null("WorldManager/QuestSystem")
	if hud == null or classic == null:
		_fail("HUD or ClassicHUD missing")
		return
	var bar := classic.get_node_or_null("ClassicConquerBottomBar") as Control
	var row := classic.get_node_or_null("ClassicConquerBottomBar/MainRow")
	if bar == null or row == null:
		_fail("classic bottom bar hierarchy missing")
		return
	if absf(bar.size.y / 720.0 - 0.12) > 0.002:
		_fail("bottom bar is not 12 percent of viewport height")
		return
	for key in ["Bag","Equip","Skills","Mall","Map","Settings"]:
		var button := row.get_node_or_null("Menu" + key) as Button
		if button == null or not button.text.is_empty() or button.icon == null:
			_fail("icon-only PNG menu button missing: " + key)
			return
	for index in range(10):
		var hotkey := row.get_node_or_null("HotkeyF%d" % (index + 1)) as Button
		if hotkey == null or hotkey.icon == null:
			_fail("F%d hotkey is missing its PNG icon" % (index + 1))
			return
	if not ResourceLoader.exists("res://assets/ui/fonts/NotoSansArabic[wght].ttf"):
		_fail("Noto Sans Arabic font missing")
		return
	var orb := row.get_node_or_null("SplitCrystalOrb")
	if orb == null or orb.get_node_or_null("GoldEngravedOrbRim") == null:
		_fail("split HP/MP orb gold rim missing")
		return
	var hud_root := hud.get_node_or_null("HUDRoot")
	var joystick := hud_root.get_node_or_null("VirtualJoystick") if hud_root != null else null
	if joystick == null or joystick.position.y + joystick.size.y >= 720.0 * 0.88:
		_fail("joystick overlaps the 12 percent bottom bar")
		return
	hud.visible = true
	classic.visible = true
	if not await _save("01_twincity_gameplay_hud.png"):
		quit(1); return
	# Runtime-only QA loadout: no save files are modified by the screenshot test.
	var bow: Dictionary = gear_database.create_item("archer_bow")
	bow["quality"] = "Elite"
	bow["plus"] = 12
	bow["socket_count"] = 2
	bow["sockets"] = ["Dragon_Super", "Phoenix_Super"]
	gear_system.equipment["RightHand"] = bow
	var armor: Dictionary = gear_database.create_item("archer_armor_15")
	armor["quality"] = "Elite"
	armor["plus"] = 12
	armor["socket_count"] = 2
	armor["sockets"] = ["Fury_Super", "Kylin_Super"]
	gear_system.equipment["Armor"] = armor
	gear_system.inventory.clear()
	for item_id in ["assassin_throwing_knife", "ninja_katana_15", "warrior_sword_15", "archer_helmet_15", "basic_necklace", "basic_boots", "basic_ring"]:
		var item: Dictionary = gear_database.create_item(item_id)
		if not item.is_empty():
			item["quality"] = "Elite"
			item["plus"] = 1
			gear_system.inventory.append(item)
	for gem_id in gear_database.get_all_gem_ids():
		var gem_name := "%s %s Gem" % [str(gem_id).get_slice("_", 1), str(gem_id).get_slice("_", 0)]
		gear_system.inventory.append({"id": gem_id, "gem_id": gem_id, "name": gem_name, "quantity": 1, "item_type": "gem", "instance_id": "phase2_" + gem_id})
	gear_system.equipment_changed.emit()
	gear_system.inventory_changed.emit()
	hud.call("_toggle_inventory")
	var inventory_ui: Node = get_first_node_in_group("inventory_ui")
	if not is_instance_valid(inventory_ui):
		_fail("Character gear and inventory UI is missing")
		return
	if gear_system.inventory.size() != 28:
		_fail("Expected seven equipment pieces and all 21 gem variants in runtime inventory")
		return
	for gem_id in gear_database.get_all_gem_ids():
		if ThemeManager.item_texture(gem_id) == null:
			_fail("No PNG icon resolved for gem " + gem_id)
			return
	if not await _save("02_character_gear.png"):
		quit(1); return
	inventory_ui.call("_select_inventory_item", 7)
	if not await _save("03_inventory_hotkeys.png"):
		quit(1); return
	hud.call("_toggle_inventory")
	var mall = hud.get("_mall_ui")
	if not is_instance_valid(mall) or not mall.has_method("toggle"):
		_fail("Shopping Mall UI is missing")
		return
	mall.call("toggle")
	if not bool(mall.visible):
		_fail("Shopping Mall did not open")
		return
	if not await _save("04_shopping_mall.png"):
		quit(1); return
	mall.call("toggle")
	var world_manager := main.get_node_or_null("WorldManager")
	if not is_instance_valid(world_manager):
		_fail("WorldManager missing; TwinCity Auto-Quest cannot be proven")
		return
	# The user's saved profile may reopen a different settlement. The TwinCity
	# hunt is location-specific, so wait for initial restore then load TwinCity
	# explicitly before looking for its Pheasant target.
	var world_ready := false
	for frame in range(600):
		if not bool(world_manager.get("_transitioning")) and is_instance_valid(world_manager.get("current_world")):
			world_ready = true
			break
		await process_frame
	if not world_ready:
		_fail("WorldManager did not finish restoring the saved settlement")
		return
	if str(world_manager.get("current_settlement")) != "TwinCity":
		world_manager.call("change_settlement", "TwinCity", false)
		world_ready = false
		for frame in range(600):
			if str(world_manager.get("current_settlement")) == "TwinCity" and not bool(world_manager.get("_transitioning")) and is_instance_valid(world_manager.get("current_world")):
				world_ready = true
				break
			await process_frame
	if not world_ready or str(world_manager.get("current_settlement")) != "TwinCity":
		_fail("Could not load TwinCity for its canonical hunt_twin quest")
		return
	if not is_instance_valid(quest):
		_fail("WorldManager/QuestSystem missing; Auto-Quest cannot be proven")
		return
	var available: Array = quest.call("available")
	var hunt: Dictionary = {}
	for entry in available:
		if str(entry.get("id", "")) == "hunt_twin":
			hunt = entry
			break
	if hunt.is_empty():
		_fail("TwinCity hunt_twin is not available at the current character level")
		return
	if str(hunt.get("state", "")) != "active" and not quest.call("accept", "hunt_twin"):
		_fail("Could not activate the canonical TwinCity hunt quest")
		return
	var target_enemy: Node3D
	for frame in range(120):
		for candidate in get_nodes_in_group("enemies"):
			if str(candidate.get("monster_id")) == str(hunt.get("target", "")):
				target_enemy = candidate
				break
		if is_instance_valid(target_enemy):
			break
		await process_frame
	if not is_instance_valid(target_enemy):
		_fail("No live 3D monster instance matches quest target %s" % str(hunt.get("target", "")))
		return
	var original_target_position: Vector3 = target_enemy.global_position
	quest.call("track", "hunt_twin")
	var player := get_first_node_in_group("player")
	if not is_instance_valid(player) or not bool(player.get("_has_move_target")):
		_fail("Auto-Quest did not set the player movement target")
		return
	var expected_destination: Vector3 = original_target_position + Vector3(0, 0, 2)
	if player.get("_move_target").distance_to(expected_destination) > 0.05:
		_fail("Auto-Quest movement target does not match the live 3D monster coordinates")
		return
	# Prove actual in-world movement and arrival, not merely that a target
	# vector was assigned. The route is short enough for this bounded timeout.
	var arrived := false
	for frame in range(1200):
		await process_frame
		var player_distance := Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(expected_destination.x, expected_destination.z))
		if player_distance <= 0.75 and not bool(player.get("_has_move_target")):
			arrived = true
			break
	if not arrived:
		_fail("Auto-Quest assigned the correct destination but the player did not physically arrive; remaining distance %.2f" % Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(expected_destination.x, expected_destination.z)))
		return
	classic.call("_refresh_quest")
	if not await _save("05_auto_quest_tracking.png"):
		quit(1); return
	var world_manager := main.get_node_or_null("WorldManager")
	if world_manager != null:
		await world_manager.call("change_settlement", "DesertLand", true)
		await process_frame
		await process_frame
	if not await _save("06_desertland_consistent_hud.png"):
		quit(1); return
	var files := DirAccess.get_files_at(OUT)
	var count := 0
	for file_name in files:
		if file_name.ends_with(".png"):
			count += 1
	if count != 6:
		_fail("expected exactly six PNG captures, found %d" % count)
		return
	print("PHASE2_UI_PROOF_PASS: six real screenshots; 12pct bar; six PNG icon buttons; Arabic font; split orb; joystick clear")
	quit(0)

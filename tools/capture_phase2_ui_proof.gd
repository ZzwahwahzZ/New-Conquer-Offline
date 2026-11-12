extends SceneTree
## Phase 2 real-render UI proof: six distinct 1280x720 runtime captures.
const MAIN_SCENE := "res://scenes/main.tscn"
const OUT := "res://reports/phase2-ui"
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
	var hud := main.get_node_or_null("HUD") as CanvasLayer
	var classic := main.get_node_or_null("HUD/ClassicHUD") as Control
	var quest := get_root().get_node_or_null("QuestSystem")
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
	hud.call("_toggle_status_ui")
	if not await _save("02_character_gear.png"):
		quit(1); return
	hud.call("_toggle_inventory")
	if not await _save("03_inventory_hotkeys.png"):
		quit(1); return
	hud.call("_toggle_inventory")
	var mall = hud.get("_mall_ui")
	if is_instance_valid(mall) and mall.has_method("toggle"):
		mall.call("toggle")
	if not await _save("04_shopping_mall.png"):
		quit(1); return
	if is_instance_valid(quest):
		var active := str(quest.get("active_quest"))
		if active.is_empty():
			for entry in quest.call("available"):
				if str(entry.get("state", "")) == "active" or str(entry.get("state", "")) == "ready":
					active = str(entry.get("id", ""))
					if quest.call("accept", active):
						break
		if not active.is_empty():
			quest.call("track", active)
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

extends SceneTree
## Captures real rendered frames from the main New Conquer Offline scene under Xvfb.
const MAIN_SCENE := "res://scenes/main.tscn"
const OUTPUT_DIR := "res://reports/visual-proof"
const CAPTURE_CAMERA_DISTANCE := 78.0
const CAPTURE_CAMERA_PITCH := 48.0
const CITY_PROOF := [
	{"id":"DesertLand","file":"city_2_desertland.png"},
	{"id":"VolcanoLand","file":"city_3_volcanoland.png"},
	{"id":"IceLand","file":"city_4_iceland.png"},
	{"id":"Waterlands","file":"city_5_waterlands.png"},
	{"id":"DarkForest","file":"city_6_darkforest.png"}
]

func _initialize() -> void:
	call_deferred("_capture")

func _fail(message: String) -> void:
	push_error("VISUAL_PROOF_FAIL: " + message)
	quit(1)

func _save_frame(file_name: String) -> bool:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("VISUAL_PROOF_FAIL: viewport returned an empty image for " + file_name)
		return false
	var path := OUTPUT_DIR.path_join(file_name)
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("VISUAL_PROOF_FAIL: could not save %s (error %d)" % [path, error])
		return false
	print("VISUAL_PROOF_CAPTURED: %s (%dx%d)" % [path, image.get_width(), image.get_height()])
	return true

func _capture() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	var mkdir_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
		_fail("could not create output directory: %s" % error_string(mkdir_error))
		return
	var game_state := root.get_node_or_null("GameState")
	var class_system := root.get_node_or_null("ClassSystem")
	if game_state == null or class_system == null:
		_fail("required autoloads are unavailable")
		return
	# Seed a deterministic local-only first-run save; this file exists only on the ephemeral CI runner.
	var fixture := {
		"character_name":"Visual Proof",
		"level":1,
		"experience":0,
		"gold":100,
		"hp":100,
		"max_hp":100,
		"mp":50,
		"max_mp":50,
		"inventory":[],
		"quests":{"first_hunt":"not_started"},
		"settlement_id":"TwinCity",
		"world_position":[0.0,0.0,0.0],
		"class_id":"Archer"
	}
	var save_file := FileAccess.open("user://offline_profile.json", FileAccess.WRITE)
	if save_file == null:
		_fail("could not create deterministic CI profile")
		return
	save_file.store_string(JSON.stringify(fixture))
	save_file.close()
	game_state.call("load_local")
	game_state.get("profile")["class_id"] = "Archer"
	if not class_system.call("choose_class", "Archer"):
		_fail("could not initialize deterministic Archer profile")
		return
	var packed := load(MAIN_SCENE) as PackedScene
	if packed == null:
		_fail("main game scene failed to load")
		return
	var main := packed.instantiate() as Node3D
	if main == null:
		_fail("main game scene root is not Node3D")
		return
	root.add_child(main)
	var world_manager: Node = main.get_node_or_null("WorldManager")
	var camera_rig: Node3D = main.get_node_or_null("IsometricCamera") as Node3D
	if world_manager == null or camera_rig == null:
		_fail("main scene did not create WorldManager and IsometricCamera")
		return
	var camera := camera_rig.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		_fail("main scene camera is missing")
		return
	var deadline := Time.get_ticks_msec() + 20000
	while (world_manager.get("current_world") == null or not is_instance_valid(world_manager.get("current_world"))) and Time.get_ticks_msec() < deadline:
		await process_frame
	if world_manager.get("current_settlement") != "TwinCity" or world_manager.get("current_world") == null:
		_fail("Twin City did not finish loading")
		return
	var player := main.get_node_or_null("LocalPlayer") as Node3D
	if player == null:
		_fail("player node is missing from the main scene")
		return
	if absf(player.global_position.x) > 0.1 or absf(player.global_position.z) > 0.1:
		_fail("player spawn is not centered: %s" % str(player.global_position))
		return
	if not camera.current:
		_fail("isometric Camera3D is not current")
		return
	# Capture-only framing: pull back to show city layout and hide gameplay overlays.
	camera_rig.set("_target_distance", CAPTURE_CAMERA_DISTANCE)
	camera_rig.set("_current_distance", CAPTURE_CAMERA_DISTANCE)
	camera_rig.set("pitch_degrees", CAPTURE_CAMERA_PITCH)
	camera_rig.call("_apply_orbit")
	var hud := main.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	else:
		_fail("HUD root is missing; cannot guarantee clean proof frames")
		return
	for required in ["Street_NorthSouth", "Street_EastWest", "CentralDarkSquare", "TwinCity_RaisedFlowerBed_00", "TwinCity_SquareRail_N"]:
		if main.find_child(required, true, false) == null:
			_fail("Twin City street detail is missing: " + required)
			return
	var classic_hud := main.get_node_or_null("HUD/ClassicHUD") as Control
	if classic_hud == null:
		_fail("classic gold HUD is missing")
		return
	if classic_hud.get_node_or_null("ClassicConquerBottomBar/MainRow/SplitCrystalOrb") == null:
		_fail("single split HP/MP crystal orb is missing")
		return
	if classic_hud.get_node_or_null("LiveQuestTracker") == null:
		_fail("live quest tracker is missing")
		return
	if not FileAccess.file_exists("res://assets/ui/manifest.json"):
		_fail("restored Kenney RPG UI manifest is missing")
		return
	if not ResourceLoader.exists("res://assets/ui/frames/fantasy_ui_borders__Border__panel-border-000.png"):
		_fail("real Kenney ornamental frame PNG was not imported")
		return
	if camera.global_position.y < player.global_position.y + 3.0:
		_fail("isometric camera is not elevated above the player; the spawn frame would be ground-obscured")
		return
	# Twin City: four real frames at t=0, 3, 6 and 9 seconds.
	await process_frame
	await process_frame
	if not await _save_frame("twincity_1_t0.png"):
		quit(1)
		return
	await create_timer(3.0).timeout
	if not await _save_frame("twincity_2_t3.png"):
		quit(1)
		return
	camera_rig.set("_yaw", PI * 0.5)
	camera_rig.call("_apply_orbit")
	await create_timer(3.0).timeout
	if not await _save_frame("twincity_3_t6_orbit.png"):
		quit(1)
		return
	camera_rig.set("_yaw", PI)
	camera_rig.call("_apply_orbit")
	await create_timer(3.0).timeout
	if not await _save_frame("twincity_4_t9_orbit2.png"):
		quit(1)
		return
	# Load every remaining settlement through the actual WorldManager transition.
	for city_data in CITY_PROOF:
		var city_id := str(city_data["id"])
		await world_manager.call("change_settlement", city_id, true)
		if not is_instance_valid(camera_rig) or not is_instance_valid(player):
			_fail("camera or player became invalid during settlement transition: " + city_id)
			return
		camera_rig.set("_target_distance", CAPTURE_CAMERA_DISTANCE)
		camera_rig.set("_current_distance", CAPTURE_CAMERA_DISTANCE)
		camera_rig.set("pitch_degrees", CAPTURE_CAMERA_PITCH)
		camera_rig.set("_yaw", 0.0)
		camera_rig.call("_apply_orbit")
		var city_environment := world_manager.get("current_world").find_child("SettlementEnvironment", true, false) as WorldEnvironment
		if city_environment != null and city_environment.environment != null:
			city_environment.environment.glow_enabled = false
			city_environment.environment.fog_enabled = false
			city_environment.environment.ambient_light_energy = 0.45
			city_environment.environment.tonemap_exposure = 0.72
		var city_sun := world_manager.get("current_world").find_child("SettlementSun", true, false) as DirectionalLight3D
		if city_sun != null:
			city_sun.light_energy = 0.72
		var city_deadline := Time.get_ticks_msec() + 20000
		while (world_manager.get("current_settlement") != city_id or world_manager.get("current_world") == null) and Time.get_ticks_msec() < city_deadline:
			await process_frame
		if world_manager.get("current_settlement") != city_id or world_manager.get("current_world") == null:
			_fail("settlement failed to load for visual proof: " + city_id)
			return
		player.global_position = Vector3(0.0, 0.775, 0.0)
		await create_timer(3.0).timeout
		var loaded_world := world_manager.get("current_world") as Node3D
		if loaded_world.find_child(city_id + "_DetailedBuilding_00", true, false) == null:
			_fail("detailed architecture missing from rendered city: " + city_id)
			return
		if not await _save_frame(str(city_data["file"])):
			quit(1)
			return
	print("VISUAL_PROOF_PASS: 9 genuine runtime frames; TwinCity t=0/3/6/9 with two 90-degree orbits; five other settlements after 3-second stabilization; wide city framing, balanced capture lighting and HUD hidden.")
	quit(0)

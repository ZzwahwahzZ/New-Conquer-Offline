extends SceneTree
## Captures real rendered frames from the main New Conquer Offline scene under Xvfb.
const MAIN_SCENE := "res://scenes/main.tscn"
const OUTPUT_DIR := "res://reports/visual-proof"
const RUN_SECONDS := 3.0

func _initialize() -> void:
	call_deferred("_capture")

func _fail(message: String) -> void:
	push_error("VISUAL_PROOF_FAIL: " + message)
	quit(1)

func _save_frame(file_name: String) -> bool:
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
	await create_timer(RUN_SECONDS * 0.5).timeout
	if not await _save_frame("screenshot_1_spawn.png"):
		quit(1)
		return
	camera_rig.set("_yaw", PI * 0.5)
	camera_rig.call("_apply_orbit")
	await create_timer(RUN_SECONDS * 0.5).timeout
	if not await _save_frame("screenshot_2_orbit.png"):
		quit(1)
		return
	print("VISUAL_PROOF_PASS: main-scene Twin City frames captured; orbit delta=90 degrees; runtime=%.1fs" % RUN_SECONDS)
	quit(0)

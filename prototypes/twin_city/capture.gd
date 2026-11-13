extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("TWIN_CITY_CAPTURE_FAIL: " + message)
	quit(1)

func _run() -> void:
	var packed := load("res://TwinCity.tscn") as PackedScene
	if packed == null: _fail("TwinCity scene missing."); return
	var city := packed.instantiate() as Node3D
	if city == null: _fail("TwinCity root is not Node3D."); return
	root.add_child(city)
	for i in range(12): await process_frame
	var aerial := city.get_node_or_null("TwinCityProofCameras/AerialCamera") as Camera3D
	var street := city.get_node_or_null("TwinCityProofCameras/StreetCamera") as Camera3D
	if aerial == null or street == null: _fail("Proof camera missing."); return
	var captures := ProjectSettings.globalize_path("res://captures")
	var reports := ProjectSettings.globalize_path("res://reports")
	DirAccess.make_dir_recursive_absolute(captures)
	DirAccess.make_dir_recursive_absolute(reports)
	aerial.make_current()
	for i in range(8): await process_frame
	await create_timer(1.5).timeout
	var image_a := root.get_texture().get_image()
	if image_a.get_size() != Vector2i(1920,1080): _fail("Aerial image size mismatch: " + str(image_a.get_size())); return
	var path_a := captures.path_join("twin_city_aerial.png")
	if image_a.save_png(path_a) != OK: _fail("Aerial image save failed."); return
	street.make_current()
	for i in range(8): await process_frame
	await create_timer(1.5).timeout
	var image_b := root.get_texture().get_image()
	if image_b.get_size() != Vector2i(1920,1080): _fail("Street image size mismatch: " + str(image_b.get_size())); return
	var path_b := captures.path_join("twin_city_street.png")
	if image_b.save_png(path_b) != OK: _fail("Street image save failed."); return
	var report: Dictionary = city.get_meta("build_stats",{})
	report["screenshot_width"] = 1920
	report["screenshot_height"] = 1080
	report["godot_version"] = Engine.get_version_info().string
	report["capture_mode"] = "Godot 4.3 Xvfb OpenGL Compatibility"
	report["average_fps_after_capture"] = Engine.get_frames_per_second()
	var file := FileAccess.open(reports.path_join("twin_city_build_report.json"),FileAccess.WRITE)
	if file == null: _fail("Report file could not be opened."); return
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("TWIN_CITY_AERIAL_SCREENSHOT_PASS: " + path_a)
	print("TWIN_CITY_STREET_SCREENSHOT_PASS: " + path_b)
	print("TWIN_CITY_CAPTURE_DIMENSIONS_PASS: 1920x1080 x 2")
	print("TWIN_CITY_FINAL_REPORT: " + JSON.stringify(report))
	quit(0)

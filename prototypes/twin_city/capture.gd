extends SceneTree

const VIEWS := [
	{"file":"01_aerial_full.png","position":Vector3(0,390,330),"target":Vector3(0,0,0),"orthographic":true,"size":560.0},
	{"file":"02_aerial_oblique.png","position":Vector3(245,235,260),"target":Vector3(0,8,0),"orthographic":true,"size":390.0},
	{"file":"03_street_scale.png","position":Vector3(0,10,48),"target":Vector3(0,6,78),"orthographic":false,"fov":58.0},
	{"file":"04_central_plaza.png","position":Vector3(68,38,76),"target":Vector3(0,4,0),"orthographic":false,"fov":55.0},
	{"file":"05_imperial_palace.png","position":Vector3(0,48,-148),"target":Vector3(0,10,-76),"orthographic":false,"fov":52.0},
	{"file":"06_district_density.png","position":Vector3(96,34,90),"target":Vector3(72,5,72),"orthographic":false,"fov":60.0}
]

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	push_error("TWIN_CITY_CAPTURE_FAIL: " + message)
	quit(1)

func _run() -> void:
	var packed := load("res://TwinCity.tscn") as PackedScene
	if packed == null:
		_fail("TwinCity scene missing.")
		return
	var city := packed.instantiate() as Node3D
	if city == null:
		_fail("TwinCity root is not Node3D.")
		return
	root.add_child(city)
	for i in range(24):
		await process_frame
	var captures := ProjectSettings.globalize_path("res://captures")
	var reports := ProjectSettings.globalize_path("res://reports")
	DirAccess.make_dir_recursive_absolute(captures)
	DirAccess.make_dir_recursive_absolute(reports)
	var camera_root := Node3D.new()
	camera_root.name = "SixRequiredProofCameras"
	city.add_child(camera_root)
	var fps_sum := 0.0
	var fps_samples := 0
	var started := Time.get_ticks_msec()
	for view in VIEWS:
		var camera := Camera3D.new()
		camera.name = str(view.file).get_basename()
		if bool(view.orthographic):
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = float(view.size)
		else:
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = float(view.fov)
		camera.position = view.position
		camera_root.add_child(camera)
		camera.look_at(view.target, Vector3.UP)
		camera.make_current()
		for frame in range(12):
			await process_frame
			if frame >= 4:
				fps_sum += float(Engine.get_frames_per_second())
				fps_samples += 1
		await create_timer(0.35).timeout
		var image := root.get_texture().get_image()
		if image.get_size() != Vector2i(1920,1080):
			_fail(str(view.file) + " size mismatch: " + str(image.get_size()))
			return
		if image.get_used_rect().size == Vector2i.ZERO:
			_fail(str(view.file) + " is empty.")
			return
		var path := captures.path_join(str(view.file))
		if image.save_png(path) != OK:
			_fail("Could not save " + path)
			return
		print("TWIN_CITY_IMAGE_VERIFIED: " + str(view.file) + " 1920x1080 " + str(FileAccess.get_file_as_bytes(path).size()) + " bytes")
		camera.queue_free()
		await process_frame
	var report: Dictionary = city.get_meta("build_stats", {})
	report["screenshot_width"] = 1920
	report["screenshot_height"] = 1080
	report["required_screenshots"] = VIEWS.map(func(v): return v.file)
	report["screenshots_created"] = VIEWS.size()
	report["godot_version"] = Engine.get_version_info().string
	report["capture_mode"] = "Godot 4.3 Xvfb OpenGL Compatibility"
	report["measured_capture_fps_average"] = fps_sum / maxf(1.0, float(fps_samples))
	report["capture_elapsed_seconds"] = float(Time.get_ticks_msec() - started) / 1000.0
	report["fps_target_30_pass"] = report["measured_capture_fps_average"] >= 30.0
	var file := FileAccess.open(reports.path_join("twin_city_build_report.json"), FileAccess.WRITE)
	if file == null:
		_fail("Report file could not be opened.")
		return
	file.store_string(JSON.stringify(report, "\\t"))
	file.close()
	print("TWIN_CITY_SIX_SCREENSHOTS_PASS: " + JSON.stringify(report["required_screenshots"]))
	print("TWIN_CITY_PERFORMANCE_AUDIT: " + str(report["measured_capture_fps_average"]) + " FPS; target 30 = " + str(report["fps_target_30_pass"]))
	print("TWIN_CITY_FINAL_REPORT: " + JSON.stringify(report))
	quit(0)

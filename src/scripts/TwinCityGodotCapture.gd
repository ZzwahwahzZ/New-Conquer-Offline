extends SceneTree

const VIEWS := [
 {"file":"01_aerial_full.png","position":Vector3(0,520,560),"target":Vector3(0,0,0),"ortho":true,"size":660.0},
 {"file":"02_aerial_oblique.png","position":Vector3(280,300,330),"target":Vector3(0,6,0),"ortho":true,"size":440.0},
 {"file":"03_street_scale.png","position":Vector3(0,1.8,178),"target":Vector3(0,3.0,92),"ortho":false,"fov":72.0},
 {"file":"04_central_plaza.png","position":Vector3(0,34,56),"target":Vector3(0,8,0),"ortho":false,"fov":55.0},
 {"file":"05_imperial_palace.png","position":Vector3(0,72,-245),"target":Vector3(0,12,-145),"ortho":false,"fov":52.0},
 {"file":"06_district_density.png","position":Vector3(218,18,12),"target":Vector3(145,7,0),"ortho":false,"fov":64.0}
]

func _initialize() -> void:
 call_deferred("_capture")

func _fail(message: String) -> void:
 push_error("TWIN_CITY_CAPTURE_FAIL: " + message)
 quit(1)

func _capture() -> void:
 var packed := load("res://src/scenes/world/TwinCity.tscn") as PackedScene
 if packed == null:
  _fail("TwinCity scene could not be loaded")
  return
 root.size = Vector2i(1280,720)
 var city := packed.instantiate() as Node3D
 if city == null:
  _fail("TwinCity root is not Node3D")
  return
 root.add_child(city)
 for frame in range(24):
  await process_frame
 var captures := ProjectSettings.globalize_path("res://prototypes/twin_city/captures")
 var reports := ProjectSettings.globalize_path("res://prototypes/twin_city/reports")
 DirAccess.make_dir_recursive_absolute(captures)
 DirAccess.make_dir_recursive_absolute(reports)
 var camera_root := Node3D.new()
 camera_root.name = "TwinCityProofCameras"
 city.add_child(camera_root)
 var fps_sum := 0.0
 var fps_samples := 0
 var start_ms := Time.get_ticks_msec()
 for view in VIEWS:
  var camera := Camera3D.new()
  camera.name = str(view.file).get_basename()
  if bool(view.ortho):
   camera.projection = Camera3D.PROJECTION_ORTHOGONAL
   camera.size = float(view.size)
  else:
   camera.projection = Camera3D.PROJECTION_PERSPECTIVE
   camera.fov = float(view.fov)
  camera.position = view.position
  camera_root.add_child(camera)
  camera.look_at(view.target, Vector3.UP)
  camera.make_current()
  for frame in range(14):
   await process_frame
   if frame >= 4:
    fps_sum += float(Engine.get_frames_per_second())
    fps_samples += 1
  await create_timer(0.35).timeout
  var image := root.get_texture().get_image()
  if image.get_size() != Vector2i(1280,720):
   _fail(str(view.file) + " wrong viewport size: " + str(image.get_size()))
   return
  var output := captures.path_join(str(view.file))
  if image.save_png(output) != OK:
   _fail("Could not save " + output)
   return
  print("TWIN_CITY_IMAGE_VERIFIED: " + str(view.file) + " 1280x720")
  camera.queue_free()
  await process_frame
 var nodes := get_nodes_in_group("twin_city_building")
 var counts := {"residential":0,"commercial":0,"service":0,"landmark":0,"palace":0,"pagoda":0}
 for node in nodes:
  var category := str(node.get_meta("twin_city_category", ""))
  if counts.has(category):
   counts[category] += 1
 var avg_fps := fps_sum/maxf(1.0,float(fps_samples))
 var report := {
  "architecture_style":"imperial_chinese",
  "buildings":nodes.size(),
  "building_categories":counts,
  "city_core_m":360,
  "perimeter_diameter_m":380,
  "plaza_diameter_m":56,
  "palace_dimensions_m":"85x75",
  "blueprint":"GODOT_MASTER_ARCHITECTURAL_BLUEPRINT; four-pass CAD grid; AABB ground snap; warm imperial palette",
  "street_camera_clearance_required_m":6.0,
  "world_m":800,
  "screenshot_width":1280,
  "screenshot_height":720,
  "screenshots_created":VIEWS.size(),
  "required_screenshots":VIEWS.map(func(v): return v.file),
  "godot_version":Engine.get_version_info().string,
  "measured_capture_fps_average":avg_fps,
  "fps_target_30_pass":avg_fps>=30.0,
  "target_device_fps_verified":false,
  "renderer_backend":"Mobile Vulkan",
  "renderer_icd":OS.get_environment("VK_ICD_FILENAMES"),
  "street_camera_height_m":1.8,
  "fps_measurement_note":"GitHub capture uses Lavapipe software Vulkan; this is not a physical Android GPU benchmark.",
  "capture_elapsed_seconds":float(Time.get_ticks_msec()-start_ms)/1000.0
 }
 var file := FileAccess.open(reports.path_join("twin_city_build_report.json"),FileAccess.WRITE)
 if file == null:
  _fail("Could not write visual report")
  return
 file.store_string(JSON.stringify(report,"\t"))
 file.close()
 print("TWIN_CITY_CAPTURE_SUMMARY: "+JSON.stringify(report))
 if nodes.size()<220 or nodes.size()>260:
  _fail("Expected 220-260 structures; got "+str(nodes.size()))
  return
 if avg_fps<30.0 and not OS.get_environment("VK_ICD_FILENAMES").to_lower().contains("lvp"):
  _fail("Measured hardware renderer FPS below 30: "+str(avg_fps))
  return
 if avg_fps<30.0:
  print("TWIN_CITY_PERFORMANCE_WARNING: Lavapipe software Vulkan averaged "+str(avg_fps)+" FPS; physical Android GPU verification remains pending.")
 print("TWIN_CITY_SIX_VIEW_CAPTURE_PASS")
 quit(0)

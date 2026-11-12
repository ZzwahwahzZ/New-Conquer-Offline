extends SceneTree

func get_tree() -> SceneTree:
	return self

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false

func _run() -> void:
	var packed := ResourceLoader.load("res://src/scenes/world/TwinCity.tscn") as PackedScene
	if not _require(packed != null, "TwinCity scene failed to load"):
		return
	var city := packed.instantiate() as Node3D
	if not _require(city != null, "TwinCity scene root is not Node3D"):
		return
	root.add_child(city)
	await process_frame
	await physics_frame

	var environment_node := city.get_node_or_null("SettlementEnvironment") as WorldEnvironment
	if not _require(environment_node != null and environment_node.environment != null, "TwinCity WorldEnvironment is missing"):
		return
	if not _require(environment_node.environment.sky != null, "Procedural sky is missing"):
		return
	if not _require(environment_node.environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "Ambient light must use sky source"):
		return
	if not _require(is_equal_approx(environment_node.environment.ambient_light_energy, 0.85), "Ambient energy must be 0.85"):
		return
	var sun := city.find_child("SettlementSun", true, false) as DirectionalLight3D
	if not _require(sun != null and sun.visible, "Active DirectionalLight3D is missing"):
		return
	if not _require(is_equal_approx(sun.light_energy, 1.3), "Sun energy must be 1.3"):
		return

	var plaza := city.find_child("TwinCityFlatPlaza", true, false) as StaticBody3D
	if not _require(plaza != null, "TwinCity solid plaza is missing"):
		return
	var stone := plaza.find_child("TwinCityImperialStonePlaza", true, false) as MeshInstance3D
	if not _require(stone != null and stone.material_override is StandardMaterial3D, "Twin City stone PBR surface is missing"):
		return
	var stone_material := stone.material_override as StandardMaterial3D
	if not _require(stone_material.albedo_texture != null and stone_material.normal_enabled and stone_material.normal_texture != null and stone_material.roughness_texture != null, "Stone PBR maps (albedo/normal/roughness) are incomplete"):
		return
	if not _require(stone_material.albedo_texture.resource_path.contains("Ground044_2K-JPG") and stone_material.normal_texture.resource_path.contains("Ground044_2K-JPG") and stone_material.roughness_texture.resource_path.contains("Ground044_2K-JPG"), "Stone surface is not using the restored Ground044 source maps"):
		return
	if not _require(stone_material.uv1_triplanar and stone_material.uv1_scale.x >= 0.60 and stone_material.normal_scale >= 1.40 and stone_material.detail_enabled and stone_material.detail_albedo == stone_material.albedo_texture, "Stone PBR detail, contrast and triplanar scale are not configured"):
		return

	var grass := city.find_child("TerrainSurface", true, false) as MeshInstance3D
	if not _require(grass != null and grass.material_override is StandardMaterial3D, "Natural grass surface is missing"):
		return
	var grass_material := grass.material_override as StandardMaterial3D
	if not _require(grass_material.albedo_texture != null and grass_material.normal_enabled and grass_material.normal_texture != null and grass_material.roughness_texture != null, "Grass PBR maps (albedo/normal/roughness) are incomplete"):
		return
	if not _require(grass_material.albedo_texture.resource_path.contains("Ground053_2K-JPG") and grass_material.normal_texture.resource_path.contains("Ground053_2K-JPG") and grass_material.roughness_texture.resource_path.contains("Ground053_2K-JPG"), "Grass surface is not using the restored Ground053 source maps"):
		return
	if not _require(grass_material.uv1_triplanar and grass_material.uv1_scale.x >= 0.45, "Grass PBR tiling/triplanar scale is not configured for visible detail"):
		return

	var architecture := city.get_node_or_null("ArchitectureAssetSlot/TwinCity_ImperialChina_GLBAsset") as Node3D
	if not _require(architecture != null and architecture.get_child_count() > 0, "Imported TwinCity imperial architecture GLB is missing or empty"):
		return
	var spawn := city.get_node_or_null("ArchitectureAssetSlot/PlayerSpawn") as Marker3D
	if not _require(spawn != null and spawn.position.is_zero_approx(), "TwinCity player spawn anchor must be centered at X=0, Y=0, Z=0"):
		return
	var landmarks := city.find_child("TwinCityReferenceLandmarks", true, false) as Node3D
	if not _require(landmarks != null and landmarks.get_child_count() >= 5, "TwinCity reference columns and gate are missing"):
		return
	if not _require(landmarks.get_node_or_null("TwinCitySouthGate") != null, "TwinCity orientation gate landmark is missing"):
		return

	var collision := plaza.find_child("TwinCityFlatPlazaCollision", true, false) as CollisionShape3D
	if not _require(collision != null and collision.shape is BoxShape3D, "TwinCity ground collision must remain a stable box collider"):
		return
	var ground_box := collision.shape as BoxShape3D
	if not _require(is_equal_approx(collision.position.y + ground_box.size.y * 0.5, 0.0), "TwinCity collision top must remain exactly at Y=0"):
		return

	var probe := Node3D.new()
	probe.name = "PlayerProbe"
	probe.position = Vector3(0.0, 0.02, 0.0)
	root.add_child(probe)
	var camera_pack := ResourceLoader.load("res://src/scenes/IsometricCamera.tscn") as PackedScene
	if not _require(camera_pack != null, "Isometric camera scene is missing"):
		return
	var rig := camera_pack.instantiate() as Node3D
	rig.set("target_path", NodePath("../PlayerProbe"))
	root.add_child(rig)
	await process_frame
	var camera := rig.get_node_or_null("Camera3D") as Camera3D
	if not _require(camera != null and camera.current, "Orbit Camera3D is not the active current camera"):
		return
	var yaw_before := float(rig.get("_yaw"))
	var mouse_down := InputEventMouseButton.new()
	mouse_down.button_index = MOUSE_BUTTON_MIDDLE
	mouse_down.pressed = true
	mouse_down.position = Vector2(100.0, 100.0)
	rig.call("_input", mouse_down)
	var mouse_move := InputEventMouseMotion.new()
	mouse_move.position = Vector2(180.0, 100.0)
	rig.call("_input", mouse_move)
	if not _require(not is_equal_approx(float(rig.get("_yaw")), yaw_before), "Mouse drag did not rotate the camera"):
		return
	var yaw_after_mouse := float(rig.get("_yaw"))
	var touch_down := InputEventScreenTouch.new()
	touch_down.index = 0
	touch_down.pressed = true
	touch_down.position = Vector2(700.0, 180.0)
	rig.call("_input", touch_down)
	var touch_move := InputEventScreenDrag.new()
	touch_move.index = 0
	touch_move.position = Vector2(760.0, 180.0)
	rig.call("_input", touch_move)
	if not _require(not is_equal_approx(float(rig.get("_yaw")), yaw_after_mouse), "Touch drag did not rotate the camera"):
		return
	var distance_before_pinch := float(rig.get("_target_distance"))
	var touch_two := InputEventScreenTouch.new()
	touch_two.index = 1
	touch_two.pressed = true
	touch_two.position = Vector2(820.0, 180.0)
	rig.call("_input", touch_two)
	var pinch_drag := InputEventScreenDrag.new()
	pinch_drag.index = 1
	pinch_drag.position = Vector2(880.0, 180.0)
	rig.call("_input", pinch_drag)
	if not _require(float(rig.get("_target_distance")) < distance_before_pinch, "Two-finger pinch did not zoom smoothly toward the player"):
		return

	print("TWIN_CITY_PBR_PASS: restored Ground053 grass + Ground044 stone, albedo/normal/roughness, triplanar tiling")
	print("TWIN_CITY_SPAWN_PASS: centered player anchor at Y=0 + visible reference pillars/gate")
	print("ISOMETRIC_ORBIT_PASS: active camera + mouse drag + touch orbit + pinch zoom")
	city.queue_free()
	rig.queue_free()
	probe.queue_free()
	get_tree().quit(0)

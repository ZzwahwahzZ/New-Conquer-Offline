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
	var surface := plaza.find_child("TwinCityImperialStonePlaza", true, false) as MeshInstance3D
	if not _require(surface != null and surface.material_override is StandardMaterial3D, "Twin City stone plaza material is missing"):
		return
	if not _require((surface.material_override as StandardMaterial3D).albedo_texture != null, "Procedural stone tile texture is missing"):
		return

	var grass := city.find_child("TerrainSurface", true, false) as MeshInstance3D
	if not _require(grass != null and grass.material_override is StandardMaterial3D, "Natural grass surface is missing"):
		return
	if not _require((grass.material_override as StandardMaterial3D).albedo_texture != null, "Procedural grass noise texture is missing"):
		return

	var imperial_architecture := city.get_node_or_null("ArchitectureAssetSlot/TwinCity_ImperialChina_GLBAsset") as Node3D
	if not _require(imperial_architecture != null and imperial_architecture.get_child_count() > 0, "Imported TwinCity imperial architecture GLB is missing or empty"):
		return

	var collision := plaza.find_child("TwinCityFlatPlazaCollision", true, false) as CollisionShape3D
	if not _require(collision != null and collision.shape is BoxShape3D, "TwinCity ground collision must remain a stable box collider"):
		return
	var ground_box := collision.shape as BoxShape3D
	if not _require(is_equal_approx(collision.position.y + ground_box.size.y * 0.5, 0.0), "TwinCity collision top must remain exactly at Y=0"):
		return

	print("WORLD_ENVIRONMENT_PASS: ProceduralSky + sky ambient 0.85 + active directional sun 1.3")
	print("TWIN_CITY_VISUAL_PASS: procedural grass + stone paving + imported imperial architecture + stable ground collision")
	city.queue_free()
	get_tree().quit(0)

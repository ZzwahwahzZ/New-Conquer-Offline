extends SceneTree
## Runtime regression for settlement lighting and solid Twin City ground.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://src/scenes/world/TwinCity.tscn") as PackedScene
	assert(packed != null, "TwinCity scene failed to load")
	var city := packed.instantiate() as Node3D
	root.add_child(city)
	await process_frame
	await physics_frame
	var environment_node := city.get_node_or_null("SettlementEnvironment") as WorldEnvironment
	assert(environment_node != null, "WorldEnvironment is missing from settlement")
	assert(environment_node.environment != null, "Environment resource is missing")
	assert(environment_node.environment.sky != null, "Procedural sky is missing")
	assert(environment_node.environment.ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "Ambient light must use sky source")
	assert(is_equal_approx(environment_node.environment.ambient_light_energy, 0.85), "Ambient energy must be 0.85")
	var sun := city.find_child("SettlementSun", true, false) as DirectionalLight3D
	assert(sun != null and sun.visible, "Active DirectionalLight3D is missing")
	assert(is_equal_approx(sun.light_energy, 1.3), "Sun energy must be 1.3")
	var plaza := city.find_child("TwinCityFlatPlaza", true, false) as StaticBody3D
	assert(plaza != null, "TwinCity solid plaza is missing")
	var surface := plaza.find_child("TwinCityGreenPlazaSurface", true, false) as MeshInstance3D
	assert(surface != null and surface.material_override is StandardMaterial3D, "TwinCity ground material is missing")
	var collision := plaza.find_child("TwinCityFlatPlazaCollision", true, false) as CollisionShape3D
	assert(collision != null and collision.shape != null, "TwinCity ground collision is missing")
	print("WORLD_ENVIRONMENT_PASS: ProceduralSky + sky ambient 0.85 + active directional sun 1.3")
	print("TWIN_CITY_GROUND_PASS: visible StandardMaterial3D + solid static collision")
	city.queue_free()
	quit(0)

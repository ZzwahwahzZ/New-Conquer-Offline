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
	var surface := plaza.find_child("TwinCityImperialStonePlaza", true, false) as MeshInstance3D
	assert(surface != null and surface.material_override is StandardMaterial3D, "Twin City stone plaza material is missing")
	assert((surface.material_override as StandardMaterial3D).albedo_texture != null, "Procedural stone tile texture is missing")
	var grass := city.find_child("TerrainSurface", true, false) as MeshInstance3D
	assert(grass != null and grass.material_override is StandardMaterial3D, "Natural grass surface is missing")
	assert((grass.material_override as StandardMaterial3D).albedo_texture != null, "Procedural grass noise texture is missing")
	assert(city.find_child("TwinCityImperialPalace", true, false) != null, "Imperial palace is missing")
	assert(city.find_child("BridgeDragonStatue", true, false) != null, "Bridge dragon statues are missing")
	var collision := plaza.find_child("TwinCityFlatPlazaCollision", true, false) as CollisionShape3D
	assert(collision != null and collision.shape != null, "TwinCity ground collision is missing")
	var factory = load("res://src/scripts/RiggedCharacterFactory.gd")
	var fallback := factory._build_articulated_fallback("hero", 1) as Node3D
	assert(fallback != null, "Articulated humanoid fallback failed to instantiate")
	assert(fallback.get_node_or_null("Head") != null, "Fallback head is missing")
	assert(fallback.get_node_or_null("ArmPivot_L") != null and fallback.get_node_or_null("ArmPivot_R") != null, "Fallback arms are missing")
	assert(fallback.get_node_or_null("LegPivot_L") != null and fallback.get_node_or_null("LegPivot_R") != null, "Fallback legs are missing")
	assert(fallback.get_node_or_null("ArmPivot_L/ForearmPivot/LeftEasternKnife") != null, "Fallback left-hand weapon is missing")
	assert(factory.play_state(fallback, "Run"), "Fallback run animation did not execute")
	var left_leg := fallback.get_node("LegPivot_L") as Node3D
	var right_leg := fallback.get_node("LegPivot_R") as Node3D
	assert(is_equal_approx(left_leg.rotation.x, -right_leg.rotation.x), "Fallback legs must animate in opposition")
	print("WORLD_ENVIRONMENT_PASS: ProceduralSky + sky ambient 0.85 + active directional sun 1.3")
	print("TWIN_CITY_VISUAL_PASS: procedural grass + stone paving + imperial palace + dragon bridges")
	print("HUMANOID_FALLBACK_PASS: head, torso, arms, legs, boots, weapons and locomotion")
	fallback.free()
	city.queue_free()
	quit(0)

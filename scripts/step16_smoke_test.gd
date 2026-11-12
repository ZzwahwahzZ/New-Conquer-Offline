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
	# Step 11 already performs runtime instantiation of all six cities and
	# validates their terrain, collisions, anchors and architecture. Keep this
	# second-stage guard resource-only: repeatedly creating/freeing hundreds of
	# MeshInstance3D nodes under Godot 4.3's dummy --headless renderer triggers
	# the known mesh_get_surface_count null-RID shutdown bug (godotengine/godot#86806).
	var cities := ["TwinCity", "DesertLand", "VolcanoLand", "IceLand", "Waterlands", "DarkForest"]
	for city in cities:
		var path := "res://src/scenes/world/%s.tscn" % city
		if not _require(ResourceLoader.exists(path), "Missing city scene resource: " + city):
			return
		var packed := ResourceLoader.load(path) as PackedScene
		if not _require(packed != null, "City scene resource failed to load: " + city):
			return

	var source := FileAccess.get_file_as_string("res://project.godot")
	var order := ["ClassSystem=", "GearDatabase=", "GearSystem=", "GlobalEconomy=", "GameState="]
	var previous := -1
	for key in order:
		var at := source.find(key)
		if not _require(at > previous, "Autoload order changed at " + key):
			return
		previous = at
	if not _require(source.contains('renderer/rendering_method="mobile"'), "Canonical Mobile renderer setting changed"):
		return
	if not _require(ResourceLoader.load("res://src/scripts/CityArchitectureBuilder.gd") != null, "CityArchitectureBuilder failed to load"):
		return
	if not _require(ResourceLoader.load("res://src/scripts/WorldManager.gd") != null, "WorldManager failed to load"):
		return
	if not _require(ResourceLoader.load("res://src/scripts/WorldTerrainBuilder.gd") != null, "WorldTerrainBuilder failed to load"):
		return
	print("STEP16_PHASE1_SIX_CITY_RESOURCES_AND_CANONICAL_SETTINGS_PASS")
	get_tree().quit(0)

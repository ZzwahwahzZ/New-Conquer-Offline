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
	var cities := ["TwinCity", "DesertLand", "VolcanoLand", "IceLand", "Waterlands", "DarkForest"]
	for city in cities:
		var path := "res://src/scenes/world/%s.tscn" % city
		var packed := ResourceLoader.load(path) as PackedScene
		if not _require(packed != null, "Missing or unloadable city scene: " + city):
			return
		var scene := packed.instantiate() as Node3D
		if not _require(scene != null, "City scene root is not Node3D: " + city):
			return
		root.add_child(scene)
		await process_frame
		if not _require(scene.get_node_or_null("TerrainCollision") is StaticBody3D, "Terrain collision missing: " + city):
			return
		if not _require(scene.get_node_or_null("ArchitectureAssetSlot") is Node3D, "Architecture asset slot missing: " + city):
			return
		if not _require(scene.get_node_or_null("WorldBoundary_0") is StaticBody3D, "Safety bounds missing: " + city):
			return
		if not _require(scene.get_node_or_null("SanctuaryAnchors/RareSanctuaryNorthEast") != null, "Rare sanctuary anchor missing: " + city):
			return
		if city == "TwinCity":
			var imperial_asset := scene.get_node_or_null("ArchitectureAssetSlot/TwinCity_ImperialChina_GLBAsset")
			if not _require(imperial_asset is Node3D, "Imported Chinese Imperial GLB architecture is missing from TwinCity"):
				return
		scene.queue_free()
		await process_frame

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
	if not _require(ResourceLoader.load("res://src/scripts/ChineseImperialBuilder.gd") != null, "ChineseImperialBuilder failed to load"):
		return
	if not _require(ResourceLoader.load("res://src/scripts/WorldManager.gd") != null, "WorldManager failed to load"):
		return
	if not _require(ResourceLoader.load("res://src/scripts/WorldTerrainBuilder.gd") != null, "WorldTerrainBuilder failed to load"):
		return
	print("STEP16_PHASE1_SIX_CITIES_TERRAIN_COLLISION_TWINCITY_IMPERIAL_ARCHITECTURE_AUTOLOAD_PASS")
	get_tree().quit(0)

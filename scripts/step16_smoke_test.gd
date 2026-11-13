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
	if not _require(ResourceLoader.load("res://src/scripts/ChineseImperialBuilder.gd") != null, "ChineseImperialBuilder failed to load"):
		return
	for asset_path in [
		"res://assets/environment/architecture/imperial_china_palace_and_garden.glb",
		"res://assets/environment/architecture/ceremonial_hall.glb",
		"res://assets/environment/architecture/gate_tower.glb",
		"res://assets/environment/architecture/water_pavilion.glb"
	]:
		if not _require(ResourceLoader.exists(asset_path), "Required CC0 Chinese architecture asset missing: " + asset_path):
			return
	if not _require(ResourceLoader.load("res://src/scripts/WorldManager.gd") != null, "WorldManager failed to load"):
		return
	if not _require(ResourceLoader.load("res://src/scripts/WorldTerrainBuilder.gd") != null, "WorldTerrainBuilder failed to load"):
		return
	var architecture_source := FileAccess.get_file_as_string("res://src/scripts/CityArchitectureBuilder.gd")
	if not _require(architecture_source.contains("OpenCentralPlaza_80x80") and architecture_source.contains("CentralEngravedStoneMedallion"), "Open 80x80 plaza and engraved medallion builder are missing"):
		return
	if not _require(architecture_source.contains("detailed_buildings=24") and architecture_source.contains("_GrandCityGate") and architecture_source.contains("GateGuardian_"), "24-building urban fabric, cardinal gates or guardians are missing"):
		return
	if not _require(architecture_source.contains("ChineseImperialBuilder.build("), "TwinCity CC0 Chinese imperial architecture is not connected to the city builder"):
		return
	if not _require(architecture_source.contains("_OpenWorld_800x800") and architecture_source.contains("MultiMeshInstance3D"), "450x450 open-world biome or MultiMesh foliage builder is missing"):
		return
	var settlement_source := FileAccess.get_file_as_string("res://src/scripts/SettlementWorld.gd")
	if not _require(not settlement_source.contains("ChineseImperialBuilder.build("), "Obsolete enclosed TwinCity imperial block is still being instanced"):
		return
	var capture_source := FileAccess.get_file_as_string("res://tools/capture_visual_proof.gd")
	if not _require(capture_source.contains("CITY_IDS") and capture_source.contains("SHOTS") and capture_source.contains("05_aerial_oblique") and capture_source.contains("PI * 0.5"), "Six-city five-view proof capture or aerial oblique camera is missing"):
		return
	if not _require(capture_source.contains("const CITY_IDS := [\"TwinCity\",\"DesertLand\",\"VolcanoLand\",\"IceLand\",\"Waterlands\",\"DarkForest\"]") and capture_source.contains("\"suffix\":\"05_aerial_oblique\""), "Six-city proof set or named aerial oblique frame is incomplete"):
		return
	print("STEP16_PHASE1_OPEN_PLAZA_24_BUILDINGS_FOUR_GATES_800M_WORLD_AND_36_FRAME_PROOF_PASS")
	get_tree().quit(0)

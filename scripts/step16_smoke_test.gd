extends SceneTree

const CITIES := ["TwinCity", "DesertLand", "VolcanoLand", "IceLand", "Waterlands", "DarkForest"]
const REQUIRED_AUTOLOAD_ORDER := ["ClassSystem=", "GearDatabase=", "GearSystem=", "GlobalEconomy=", "GameState="]

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("STEP16_CITY_CONTRACT_FAIL: " + message)
	quit(1)
	return false

func _count_group_recursive(node: Node, group_name: String) -> int:
	var total := 1 if node.is_in_group(group_name) else 0
	for child in node.get_children():
		total += _count_group_recursive(child, group_name)
	return total

func _count_named_gates(city: Node) -> int:
	var total := 0
	for direction in ["North", "East", "South", "West"]:
		if city.find_child(direction + "_GrandCityGate", true, false) != null:
			total += 1
	return total

func _run() -> void:
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	var previous := -1
	for key in REQUIRED_AUTOLOAD_ORDER:
		var at := project_source.find(key)
		if not _require(at > previous, "Autoload order changed at " + key):
			return
		previous = at
	if not _require(project_source.contains('renderer/rendering_method="mobile"'), "canonical Mobile renderer setting changed"):
		return

	var builder_path := "res://src/scripts/CityArchitectureBuilder.gd"
	var settlement_path := "res://src/scripts/SettlementWorld.gd"
	if not _require(ResourceLoader.load(builder_path) != null, "CityArchitectureBuilder failed to load"):
		return
	var builder_source := FileAccess.get_file_as_string(builder_path)
	var settlement_source := FileAccess.get_file_as_string(settlement_path)
	if not _require(settlement_source.contains("CityArchitectureBuilder.build(get_node(\"ArchitectureAssetSlot\"), settlement_id"), "SettlementWorld does not invoke build_city before validation"):
		return
	if not _require(builder_source.contains("_instantiate_quaternius_building(slot") and builder_source.contains("detailed_buildings=80"), "imported modular building generation is not connected to the 80-building city builder"):
		return
	if not _require(builder_source.contains("gate.add_to_group(\"cardinal_gates\")") and builder_source.contains("guard.add_to_group(\"city_guardians\")"), "cardinal gate or guardian groups are not registered"):
		return
	if not _require(builder_source.contains("ChineseImperialBuilder.build("), "Chinese imperial architectural assets are not connected"):
		return
	if not _require(builder_source.contains("_OpenWorld_800x800") and builder_source.contains("MultiMeshInstance3D"), "open-world biome and batched foliage builder are missing"):
		return

	for city_id in CITIES:
		var scene_path := "res://src/scenes/world/%s.tscn" % city_id
		var packed := ResourceLoader.load(scene_path) as PackedScene
		if not _require(packed != null, "missing or invalid city scene: " + city_id):
			return
		var city := packed.instantiate() as Node3D
		if not _require(city != null, "city root is not Node3D: " + city_id):
			return
		# Adding the actual scene runs SettlementWorld._ready(), which calls build_city()
		# and constructs its architecture before any structural counts are performed.
		root.add_child(city)
		await process_frame
		await process_frame
		var building_count := _count_group_recursive(city, "city_building")
		var gate_count := _count_group_recursive(city, "cardinal_gates")
		var guardian_count := _count_group_recursive(city, "city_guardians")
		if not _require(building_count >= 70, "%s generated only %d grouped buildings (minimum 70)" % [city_id, building_count]):
			return
		if not _require(gate_count == 4 and _count_named_gates(city) == 4, "%s has %d/4 cardinal gates" % [city_id, gate_count]):
			return
		if not _require(guardian_count == 8, "%s has %d/8 city guardians" % [city_id, guardian_count]):
			return
		for direction in ["North", "East", "South", "West"]:
			var gate := city.find_child(direction + "_GrandCityGate", true, false)
			if not _require(gate != null and gate.is_in_group("cardinal_gates"), "%s %s gate missing its group" % [city_id, direction]):
				return
		print("STEP16_CITY_PASS: %s buildings=%d cardinal_gates=%d city_guardians=%d" % [city_id, building_count, gate_count, guardian_count])
		city.queue_free()
		await process_frame

	print("STEP16_PHASE3A_CITY_CONTRACT_PASS: six cities; >=70 buildings, 4 cardinal gates and 8 guardians per city; runtime build_city invocation verified; Mobile renderer and Autoload order preserved.")
	quit(0)

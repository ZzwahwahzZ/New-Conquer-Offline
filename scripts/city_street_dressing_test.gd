extends SceneTree
## Structural regression test for the six classic city street environments.
const CITIES := ["TwinCity", "DesertLand", "VolcanoLand", "IceLand", "Waterlands", "DarkForest"]

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
	if ok:
		return true
	push_error("CITY_STREET_TEST_FAIL: " + message)
	quit(1)
	return false

func _run() -> void:
	for city_name in CITIES:
		var path: String = "res://src/scenes/world/" + str(city_name) + ".tscn"
		var packed := load(path) as PackedScene
		if not _check(packed != null, city_name + " scene missing"):
			return
		var city := packed.instantiate() as Node3D
		if not _check(city != null, city_name + " root is not Node3D"):
			return
		root.add_child(city)
		await process_frame
		var streets := city.get_node_or_null("TerrainAssetSlot")
		if not _check(streets != null, city_name + " terrain slot missing"):
			return
		for node_name in ["Street_NorthSouth", "Street_EastWest", "CentralDarkSquare"]:
			if not _check(city.find_child(node_name, true, false) is MeshInstance3D, city_name + " missing " + node_name):
				return
		var planters := 0
		var railings := 0
		var flower_batches := 0
		var shrub_batches := 0
		var pending: Array[Node] = [streets]
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			for child in node.get_children():
				pending.append(child)
			if node.name.begins_with(city_name + "_RaisedFlowerBed_"):
				planters += 1
			if node.name.contains("SquareRail_") or node.name.contains("BridgeRail_"):
				railings += 1
			if node.name == "FlowerCluster_MultiMesh":
				flower_batches += 1
			if node.name == "EvergreenShrubs_MultiMesh":
				shrub_batches += 1
		if not _check(planters >= 12 and flower_batches >= 12 and shrub_batches >= 12, city_name + " flowerbeds/shrub MultiMeshes incomplete"):
			return
		if not _check(railings >= 4, city_name + " ornamental railings incomplete"):
			return
		var env_node := city.get_node_or_null("SettlementEnvironment") as WorldEnvironment
		if not _check(env_node != null and env_node.environment.tonemap_mode == Environment.TONE_MAPPER_ACES and env_node.environment.ssao_enabled, city_name + " ACES/SSAO environment missing"):
			return
		var sun := city.get_node_or_null("SettlementSun") as DirectionalLight3D
		if not _check(sun != null and sun.shadow_enabled, city_name + " directional shadows disabled"):
			return
		if city_name == "Waterlands" and not _check(city.find_child("ApeCityCanal_East", true, false) != null, "Waterlands canal missing"):
			return
		if city_name == "VolcanoLand" and not _check(city.find_child("PhoenixLavaRunoff_East", true, false) != null, "VolcanoLand lava channel missing"):
			return
		if city_name == "IceLand" and not _check(city.find_child("IceCrystalLantern_00", true, false) != null, "IceLand crystal beds missing"):
			return
		if city_name == "DarkForest" and not _check(city.find_child("ForestSpiritLantern_00", true, false) != null, "DarkForest lanterns missing"):
			return
		print("CITY_STREET_TEST_PASS: " + city_name + " planters=" + str(planters) + " flower_multimeshes=" + str(flower_batches) + " railings=" + str(railings))
		city.queue_free()
		await process_frame
	print("ALL_SIX_CITY_STREET_ENVIRONMENTS_PASS")
	quit(0)

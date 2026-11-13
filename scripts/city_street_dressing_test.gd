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

func _has_renderable_mesh(root_node: Node) -> bool:
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
			return true
		if current is MultiMeshInstance3D:
			var instance := current as MultiMeshInstance3D
			if instance.multimesh != null and instance.multimesh.mesh != null:
				return true
	return false

func _has_invalid_mesh(root_node: Node) -> bool:
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if current is MeshInstance3D:
			var mesh := (current as MeshInstance3D).mesh
			if mesh == null:
				return true
		if current is MultiMeshInstance3D:
			var multi := (current as MultiMeshInstance3D).multimesh
			if multi == null or multi.mesh == null:
				return true
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
		var bridge_count := 0
		var bridge_stack: Array[Node] = [city]
		while not bridge_stack.is_empty():
			var bridge_node: Node = bridge_stack.pop_back()
			for child in bridge_node.get_children():
				bridge_stack.append(child)
			if bridge_node.is_in_group("world_bridge"):
				bridge_count += 1
				if not _check(bridge_node.find_child("BridgeWalkableCollision", true, false) is CollisionShape3D, city_name + " bridge deck has no walkable collision"):
					return
				if city_name in ["TwinCity", "Waterlands"]:
					var imported_model := bridge_node.find_child("KenneyBridgeModel", true, false) as Node3D
					if not _check(imported_model != null, city_name + " bridge is missing its imported Kenney 3D model"):
						return
					var model_stack: Array[Node] = [imported_model]
					var model_meshes := 0
					var null_meshes := 0
					while not model_stack.is_empty():
						var model_node: Node = model_stack.pop_back()
						for model_child in model_node.get_children():
							model_stack.append(model_child)
						if model_node is MeshInstance3D:
							var model_mesh := (model_node as MeshInstance3D).mesh
							if model_mesh == null:
								null_meshes += 1
							else:
								model_meshes += 1
					print("KENNEY_BRIDGE_MODEL_AUDIT: " + city_name + " meshes=" + str(model_meshes) + " null_meshes=" + str(null_meshes))
					if not _check(model_meshes > 0 and null_meshes == 0, city_name + " imported Kenney bridge contains no renderable geometry or still has null mesh nodes"):
						return
		if city_name in ["TwinCity", "Waterlands"] and not _check(bridge_count == 6, city_name + " must have six walkable canal bridges (found %d)" % bridge_count):
			return
		if city_name == "TwinCity":
			if not _check(city.find_child("TwinCityImperialCanal_East", true, false) is MeshInstance3D and city.find_child("TwinCityImperialCanal_West", true, false) is MeshInstance3D, "TwinCity imperial canals are missing"):
				return
		if city_name == "Waterlands":
			if not _check(city.find_child("Waterlands_ArchipelagoWaterSurface", true, false) is MeshInstance3D and city.find_child("ApeCityCanal_East", true, false) is MeshInstance3D and city.find_child("ApeCityCanal_West", true, false) is MeshInstance3D, "Waterlands archipelago water/island channels are missing"):
				return
		for node_name in ["Street_NorthSouth", "Street_EastWest", "CentralDarkSquare"]:
			if not _check(city.find_child(node_name, true, false) is MeshInstance3D, city_name + " missing " + node_name):
				return
		var terrain_body := city.find_child("TerrainCollision", true, false) as StaticBody3D
		var terrain_collider := city.find_child("TerrainSurfaceCollision", true, false) as CollisionShape3D
		if not _check(terrain_body != null and terrain_collider != null and terrain_collider.shape is HeightMapShape3D and (terrain_collider.shape as HeightMapShape3D).map_width == 129 and (terrain_collider.shape as HeightMapShape3D).map_depth == 129, city_name + " full heightfield terrain collision is missing"):
			return
		await physics_frame
		await physics_frame
		var terrain_visual := city.find_child("TerrainSurface", true, false) as MeshInstance3D
		if not _check(terrain_visual != null and terrain_visual.mesh is ArrayMesh, city_name + " heightfield render mesh is missing"):
			return
		var terrain_arrays := (terrain_visual.mesh as ArrayMesh).surface_get_arrays(0)
		var terrain_vertices: PackedVector3Array = terrain_arrays[Mesh.ARRAY_VERTEX]
		var highest := Vector3(0.0, -INF, 0.0)
		var lowest_y := INF
		for vertex in terrain_vertices:
			if vertex.y > highest.y:
				highest = vertex
			lowest_y = minf(lowest_y, vertex.y)
		if city_name != "TwinCity" and not _check(highest.y - lowest_y >= 6.0, city_name + " heightmap does not produce meaningful hills/slopes"):
			return
		# Probe a stable interior point instead of a heightfield boundary vertex; edge rays can miss concave terrain triangles, and TwinCity has a separate plaza collider.
		var ray := PhysicsRayQueryParameters3D.create(Vector3(137.0, 160.0, 173.0), Vector3(137.0, -160.0, 173.0))
		ray.collision_mask = 1
		var ground_hit := city.get_world_3d().direct_space_state.intersect_ray(ray)
		print("TERRAIN_RAY_DIAGNOSTIC: " + city_name + " hit=" + str(not ground_hit.is_empty()) + " collider=" + str(ground_hit.get("collider")) + " hit_position=" + str(ground_hit.get("position", Vector3.ZERO)) + " terrain_layer=" + str(terrain_body.collision_layer) + " terrain_mask=" + str(terrain_body.collision_mask) + " collider_disabled=" + str(terrain_collider.disabled))
		if not _check(not ground_hit.is_empty() and ground_hit.collider == terrain_body, city_name + " terrain collision did not match the heightfield surface"):
			return
		var navigation_region := city.find_child("TerrainNavigationRegion", true, false) as NavigationRegion3D
		if not _check(navigation_region != null and navigation_region.navigation_mesh != null and navigation_region.navigation_mesh.get_polygon_count() >= 8000, city_name + " heightfield-aligned navigation mesh is missing or incomplete"):
			return
		await physics_frame
		await physics_frame
		var navigation_map := navigation_region.get_navigation_map()
		var nav_start := NavigationServer3D.map_get_closest_point(navigation_map, Vector3.ZERO)
		var nav_end := NavigationServer3D.map_get_closest_point(navigation_map, Vector3(180.0, 0.0, 180.0))
		var nav_path := NavigationServer3D.map_get_path(navigation_map, nav_start, nav_end, true)
		if not _check(nav_path.size() >= 2, city_name + " navigation mesh cannot route across the terrain"):
			return
		var monster_probe := CharacterBody3D.new()
		monster_probe.set_script(load("res://src/scripts/Enemy.gd"))
		city.add_child(monster_probe)
		await process_frame
		var monster_agent := monster_probe.get_node_or_null("TerrainNavigationAgent") as NavigationAgent3D
		if not _check(monster_agent != null and monster_agent.navigation_layers == 1 and monster_probe.floor_snap_length >= 0.3 and monster_probe.floor_max_angle >= deg_to_rad(41.0), city_name + " monster terrain navigation/floor adhesion is not configured"):
			return
		monster_probe.queue_free()
		var kenney_scatter := city.find_child(city_name + "_KenneyNature_0_MultiMesh", true, false) as MultiMeshInstance3D
		if not _check(kenney_scatter != null and kenney_scatter.multimesh != null and kenney_scatter.multimesh.mesh != null and kenney_scatter.multimesh.instance_count >= 32, city_name + " required Kenney nature MultiMesh has no renderable mesh or instances"):
			return
		var duplicate_nature_source := false
		var nature_stack: Array[Node] = [city]
		while not nature_stack.is_empty():
			var nature_node: Node = nature_stack.pop_back()
			for nature_child in nature_node.get_children():
				nature_stack.append(nature_child)
			if nature_node.name.begins_with(city_name + "_QuaterniusBiomeProp_") or nature_node.name.begins_with(city_name + "_CC0_"):
				duplicate_nature_source = true
		if not _check(not duplicate_nature_source, city_name + " contains duplicate non-Kenney biome nature props"):
			return
		var architecture_slot := city.get_node_or_null("ArchitectureAssetSlot")
		if not _check(architecture_slot != null, city_name + " architecture slot missing"):
			return
		var detailed_buildings := 0
		var imported_buildings: Array[Node] = []
		var brick_normal_found := false
		var roof_detail_found := false
		var pending_arch: Array[Node] = [architecture_slot]
		while not pending_arch.is_empty():
			var arch_node: Node = pending_arch.pop_back()
			for child in arch_node.get_children():
				pending_arch.append(child)
			if arch_node.name.begins_with(city_name + "_DetailedBuilding_"):
				detailed_buildings += 1
			elif arch_node.name.begins_with(city_name + "_QuaterniusBuilding_") or arch_node.name.begins_with(city_name + "_KenneyBuilding_"):
				imported_buildings.append(arch_node)
			if arch_node.name == "ReliefBrickWalls" and arch_node is MeshInstance3D:
				var brick_material := (arch_node as MeshInstance3D).material_override as StandardMaterial3D
				brick_normal_found = brick_material != null and brick_material.normal_enabled and brick_material.normal_texture != null
			if arch_node.name in ["PagodaRoofTier_0", "SandstoneDome", "BasaltBattlement", "SnowRoofTier"]:
				roof_detail_found = true
		var total_buildings := detailed_buildings + imported_buildings.size()
		if not _check(total_buildings == 24, city_name + " must contain 24 buildings (detailed=%d imported=%d)" % [detailed_buildings, imported_buildings.size()]):
			return
		if detailed_buildings > 0 and not _check(brick_normal_found and roof_detail_found, city_name + " fallback facades must retain brick normal and city-specific roof details"):
			return
		var renderable_imports := 0
		for imported_root in imported_buildings:
			if _has_renderable_mesh(imported_root):
				renderable_imports += 1
		if not _check(renderable_imports == imported_buildings.size(), city_name + " has imported buildings without renderable mesh geometry"):
			return
		print("CITY_BUILDING_SOURCE_AUDIT: " + city_name + " detailed=" + str(detailed_buildings) + " imported=" + str(imported_buildings.size()) + " renderable_imports=" + str(renderable_imports))
		var gate_count := 0
		var wall_count := 0
		var kenney_gate_count := 0
		var kenney_tower_count := 0
		var kenney_stall_count := 0
		var kenney_fountain_found := false
		var kenney_wall_multi := city.find_child(city_name + "_KenneyCastlePerimeterWalls_MultiMesh", true, false) as MultiMeshInstance3D
		var open_plaza_found := city.find_child("OpenCentralPlaza_80x80", true, false) != null
		var outer_world_found := city.find_child(city_name + "_OpenWorld_800x800", true, false) != null
		var pending_fortifications: Array[Node] = [architecture_slot]
		while not pending_fortifications.is_empty():
			var fort_node: Node = pending_fortifications.pop_back()
			for child in fort_node.get_children():
				pending_fortifications.append(child)
			if str(fort_node.name).ends_with("_GrandCityGate"):
				gate_count += 1
			if fort_node.is_in_group("city_perimeter_wall"):
				wall_count += 1
			if fort_node.name == "KenneyGateModel":
				kenney_gate_count += 1
			if fort_node.name == "KenneyTowerModel":
				kenney_tower_count += 1
			if fort_node.name.begins_with("KenneyMarketStall_"):
				kenney_stall_count += 1
			if fort_node.name == "KenneyMarketFountain":
				kenney_fountain_found = true
			if fort_node.name in ["KenneyGateModel", "KenneyTowerModel", "KenneyMarketFountain"] or fort_node.name.begins_with("KenneyMarketStall_") or fort_node.name in ["KenneyDesertWindmill", "KenneyWaterlandsWatermill"]:
				if not _check(_has_renderable_mesh(fort_node) and not _has_invalid_mesh(fort_node), city_name + " imported Kenney model has missing/empty mesh geometry: " + str(fort_node.name)):
					return
		var total_mesh_nodes := 0
		var empty_mesh_nodes := 0
		var mesh_scan: Array[Node] = [city]
		while not mesh_scan.is_empty():
			var mesh_node: Node = mesh_scan.pop_back()
			for mesh_child in mesh_node.get_children():
				mesh_scan.append(mesh_child)
			if mesh_node is MeshInstance3D:
				total_mesh_nodes += 1
				if (mesh_node as MeshInstance3D).mesh == null:
					empty_mesh_nodes += 1
			if mesh_node is MultiMeshInstance3D:
				total_mesh_nodes += 1
				var mm := (mesh_node as MultiMeshInstance3D).multimesh
				if mm == null or mm.mesh == null:
					empty_mesh_nodes += 1
		print("CITY_MESH_HANDLE_AUDIT: " + city_name + " total=" + str(total_mesh_nodes) + " empty=" + str(empty_mesh_nodes))
		print("CITY_FORTIFICATION_DEBUG: " + city_name + " gates=" + str(gate_count) + " walls=" + str(wall_count) + " kenney_gates=" + str(kenney_gate_count) + " kenney_towers=" + str(kenney_tower_count) + " kenney_stalls=" + str(kenney_stall_count) + " fountain=" + str(kenney_fountain_found) + " gate_asset=" + str(ResourceLoader.exists("res://assets/environment/kenney/castle-kit/Models/GLB format/gate.glb")) + " tower_asset=" + str(ResourceLoader.exists("res://assets/environment/kenney/castle-kit/Models/GLB format/tower-square.glb")) + " plaza=" + str(open_plaza_found) + " outer=" + str(outer_world_found))
		if not _check(gate_count == 4 and wall_count >= 8 and open_plaza_found and outer_world_found, city_name + " open plaza/perimeter wall/four gates/800x800 outer world incomplete"):
			return
		if not _check(kenney_wall_multi != null and kenney_wall_multi.multimesh != null and kenney_wall_multi.multimesh.mesh != null and kenney_wall_multi.multimesh.instance_count >= 64, city_name + " imported Kenney castle wall modules are missing or non-renderable"):
			return
		if not _check(kenney_gate_count == 4 and kenney_tower_count == 8, city_name + " Kenney gatehouses and towers are incomplete"):
			return
		if not _check(kenney_stall_count == 4 and kenney_fountain_found, city_name + " Kenney market stalls/fountain are incomplete"):
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
		if not _check(env_node != null and env_node.environment.tonemap_mode == Environment.TONE_MAPPER_ACES and env_node.environment.ssao_enabled and not env_node.environment.glow_enabled and not env_node.environment.fog_enabled, city_name + " ACES/SSAO environment missing"):
			return
		var sun := city.get_node_or_null("SettlementSun") as DirectionalLight3D
		if not _check(sun != null and sun.visible and sun.shadow_enabled and is_equal_approx(sun.light_energy, 0.78), city_name + " directional shadows or balanced 0.78 sun energy missing"):
			return
		if city_name == "Waterlands" and not _check(city.find_child("ApeCityCanal_East", true, false) != null, "Waterlands canal missing"):
			return
		if city_name == "VolcanoLand" and not _check(city.find_child("PhoenixLavaRunoff_East", true, false) != null, "VolcanoLand lava channel missing"):
			return
		if city_name == "IceLand" and not _check(city.find_child("IceCrystalLantern_00", true, false) != null, "IceLand crystal beds missing"):
			return
		if city_name == "DarkForest" and not _check(city.find_child("ForestSpiritLantern_00", true, false) != null, "DarkForest lanterns missing"):
			return
		print("CITY_ARCHITECTURE_AND_STREETS_PASS: " + city_name + " buildings=" + str(total_buildings) + " planters=" + str(planters) + " flower_multimeshes=" + str(flower_batches) + " railings=" + str(railings))
		city.queue_free()
		await process_frame
	print("ALL_SIX_CITY_STREET_ENVIRONMENTS_PASS")
	quit(0)

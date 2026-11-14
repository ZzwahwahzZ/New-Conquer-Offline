extends RefCounted
## Twin City is assembled from source GLB scenes and source GLB modules only.
## No procedural BoxMesh/CylinderMesh/SphereMesh building geometry is created here.

const MODEL_ROOT := "res://assets/twin_city_selected/"
const ARCH_BANNER := "models/polygonalmind-lunar-year-001.glb"
const BUILDING_BASE := "models/polygonalmind-lunar-year-005.glb"
const COLUMN := "models/polygonalmind-lunar-year-008.glb"
const COLUMN_BASE := "models/polygonalmind-lunar-year-009.glb"
const DOOR := "models/polygonalmind-lunar-year-011.glb"
const ENTRANCE_STAIRS := "models/polygonalmind-lunar-year-014.glb"
const FENCE_01 := "models/polygonalmind-lunar-year-015.glb"
const FENCE_02 := "models/polygonalmind-lunar-year-016.glb"
const FLOOR_01 := "models/polygonalmind-lunar-year-017.glb"
const FLOOR_02 := "models/polygonalmind-lunar-year-018.glb"
const BELL_STRUCTURE := "models/polygonalmind-lunar-year-004.glb"
const ROOM_DOOR := "models/polygonalmind-lunar-year-042.glb"
const ROOM_FLOOR := "models/polygonalmind-lunar-year-043.glb"
const ROOM_ROOF := "models/polygonalmind-lunar-year-044.glb"
const ROOM_ROOF_BEAM := "models/polygonalmind-lunar-year-045.glb"
const ROOM_WALL := "models/polygonalmind-lunar-year-046.glb"
const PAGODA := "models/innerscene-buddhist-temple-pagoda-c5ebacdc.glb"

static func build(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "TwinCity_ImperialReconstruction"
	parent.add_child(root)

	var source_pack := load("res://assets/environment/architecture/imperial_china_palace_and_garden.glb") as PackedScene
	if source_pack == null:
		push_error("TWIN_CITY_GLB_FAIL: original Imperial China source pack is missing")
		return
	var source_instance := source_pack.instantiate() as Node3D
	if source_instance == null:
		push_error("TWIN_CITY_GLB_FAIL: Imperial China source pack root is not Node3D")
		return
	root.add_child(source_instance)
	source_instance.visible = false
	var source_container := source_instance.find_child("walled-palace-courtyard-and-lotus-garden", true, false) as Node3D
	if source_container == null:
		push_error("TWIN_CITY_GLB_FAIL: Imperial China model container is missing")
		return

	# 4-PASS MASTER BLUEPRINT: ground/paving first, then lots, then living props, then fortifications.
	_build_ground(root)
	_build_full_city_paving(root, source_container)
	_build_plaza(root, source_container)
	_build_palace(root, source_container)
	var census := _build_districts(root, source_container)
	_build_city_greenery_and_props(root, source_container)
	_build_perimeter(root, source_container)
	_build_outer_wildlands(root, source_container)

	print("TWIN_CITY_GLB_BUILD_PASS: total=%d categories=%s procedural_box_meshes=0 source=GLB" % [census.values().reduce(func(a, b): return a + b, 0), str(census)])

static func _build_ground(parent: Node3D) -> void:
	var foundation := Node3D.new()
	foundation.name = "TwinCity_800m_TerrainFoundation"
	parent.add_child(foundation)

static func _build_palace(parent: Node3D, source: Node3D) -> void:
	var platform := _spawn_glb_node(parent, BUILDING_BASE, "ImperialPalace_StoneTerrace_85x75x5", Vector3(0.0, 0.0, -145.0), 0.0, 1.0, "")
	if platform != null:
		_normalize_node_to_dimensions(platform, Vector3(85.0, 5.0, 75.0))
	var palace := source.duplicate(true) as Node3D
	if palace == null:
		push_error("TWIN_CITY_GLB_FAIL: palace compound clone failed; procedural fallback is forbidden")
		return
	palace.name = "ImperialPalace_85x75"
	palace.position = Vector3(0.0, 5.0, -145.0)
	palace.rotation = Vector3.ZERO
	palace.scale = Vector3.ONE
	parent.add_child(palace)
	_normalize_node_to_dimensions(palace, Vector3(85.0, 27.0, 75.0))
	palace.add_to_group("twin_city_imperial_source_compound")

static func _build_perimeter(parent: Node3D, source: Node3D) -> void:
	var fort := Node3D.new()
	fort.name = "TwinCity_ImperialPerimeter_380m"
	parent.add_child(fort)

	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color("#1E464A")
	water_material.roughness = 0.18
	water_material.metallic = 0.08
	for side in range(4):
		var water := MeshInstance3D.new()
		water.name = "DeepContinuousWaterMoat_440m" if side == 0 else "MoatWaterSegment_%d" % side
		var water_mesh := PlaneMesh.new()
		water_mesh.size = Vector2(380.0, 18.0)
		water.mesh = water_mesh
		water.position = [Vector3(0.0, -0.05, -198.0), Vector3(198.0, -0.05, 0.0), Vector3(0.0, -0.05, 198.0), Vector3(-198.0, -0.05, 0.0)][side]
		water.rotation.y = PI * 0.5 if side % 2 == 1 else 0.0
		fort.add_child(water)
		water.material_override = water_material

	var wall_template := "064-palace-wall-straight"
	var corner_template := "060-palace-wall-corner"
	var moon_gate_template := "087-palace-wall-moon-gate"
	var end_pier_template := "088-palace-wall-end-pier"
	for side in range(4):
		var yaw := float(side) * PI * 0.5
		for segment in range(28):
			if segment == 13 or segment == 14:
				continue
			var along := -182.25 + float(segment) * 13.5
			var pos := Vector3(along, 0.0, -190.0)
			if side == 1:
				pos = Vector3(190.0, 0.0, along)
			elif side == 2:
				pos = Vector3(-along, 0.0, 190.0)
			elif side == 3:
				pos = Vector3(-190.0, 0.0, -along)
			var wall_name := "TwinCity_ImperialWall_%02d_%02d" % [side, segment]
		if _clone_source_model(fort, source, wall_template, wall_name, pos, yaw, 1.0, ""):
			var wall_node := fort.get_node_or_null(NodePath(wall_name)) as Node3D
			if wall_node != null:
				_normalize_node_to_dimensions(wall_node, Vector3(13.5, 15.0, 4.5))
		var corner_positions := [Vector3(-190.0, 0.0, -190.0), Vector3(190.0, 0.0, -190.0), Vector3(190.0, 0.0, 190.0), Vector3(-190.0, 0.0, 190.0)]
		_clone_source_model(fort, source, corner_template, "TwinCity_ImperialWallCorner_%02d" % side, corner_positions[side], yaw, 1.4, "")

		var gate_direction := Vector3(sin(yaw), 0.0, -cos(yaw))
		var gate_center := gate_direction * 190.0
		_clone_source_model(fort, source, moon_gate_template, "TwinCity_ImperialMoonGate_%02d" % side, gate_center, yaw, 1.55, "")
		_clone_source_model(fort, source, end_pier_template, "TwinCity_ImperialGatePierA_%02d" % side, gate_center + Vector3(-sin(yaw) * 18.0, 0.0, cos(yaw) * 18.0), yaw, 1.5, "")
		_clone_source_model(fort, source, end_pier_template, "TwinCity_ImperialGatePierB_%02d" % side, gate_center + Vector3(sin(yaw) * 18.0, 0.0, -cos(yaw) * 18.0), yaw, 1.5, "")
		var gate_tower_name := "TwinCity_GrandGateTower_%02d" % side
		if _clone_source_model(fort, source, "131-gate-tower", gate_tower_name, gate_center, yaw, 1.0, ""):
			var gate_tower := fort.get_node_or_null(NodePath(gate_tower_name)) as Node3D
			if gate_tower != null:
				_normalize_node_to_dimensions(gate_tower, Vector3(14.0, 19.0, 14.0))
		_clone_source_model(fort, source, "135-arched-stone-bridge", "TwinCity_GrandStoneBridge_%02d" % side, gate_center + gate_direction * 12.0, yaw, 1.0, "")
		for tower_index in range(7):
			var tower_along := -162.0 + float(tower_index) * 54.0
			var tower_pos := Vector3(tower_along, 0.0, -190.0)
			if side == 1:
				tower_pos = Vector3(190.0, 0.0, tower_along)
			elif side == 2:
				tower_pos = Vector3(-tower_along, 0.0, 190.0)
			elif side == 3:
				tower_pos = Vector3(-190.0, 0.0, -tower_along)
			var watch_name := "TwinCity_WatchTower_%02d_%02d" % [side, tower_index]
			if _clone_source_model(fort, source, "131-gate-tower", watch_name, tower_pos, yaw, 1.0, ""):
				var watch := fort.get_node_or_null(NodePath(watch_name)) as Node3D
				if watch != null:
					_normalize_node_to_dimensions(watch, Vector3(12.0, 19.0, 12.0))

static func _build_full_city_paving(parent: Node3D, source: Node3D) -> void:
	var template := source.find_child("059-courtyard-paving-module", true, false) as Node3D
	if template == null:
		push_error("TWIN_CITY_GLB_FAIL: original engraved courtyard paving module is missing")
		return
	var mesh_nodes := template.find_children("*", "MeshInstance3D", true, false)
	if mesh_nodes.is_empty():
		push_error("TWIN_CITY_GLB_FAIL: paving module contains no MeshInstance3D")
		return
	var source_mesh := (mesh_nodes[0] as MeshInstance3D).mesh
	if source_mesh == null or source_mesh.get_surface_count() == 0:
		push_error("TWIN_CITY_GLB_FAIL: paving source mesh is null or has no surfaces")
		return

	var tile_mesh := source_mesh
	var block_transforms: Array[Transform3D] = []
	var road_transforms: Array[Transform3D] = []
	var plaza_warm_transforms: Array[Transform3D] = []
	var plaza_dark_transforms: Array[Transform3D] = []
	var curb_transforms: Array[Transform3D] = []
	for xi in range(120):
		var x := -178.5 + float(xi) * 3.0
		for zi in range(120):
			var z := -178.5 + float(zi) * 3.0
			var point := Vector3(x, 0.025, z)
			var radius := Vector2(x, z).length()
			var on_main_avenue := absf(x) < 8.0 or absf(z) < 7.0
			var on_secondary := absf(absf(x) - round(absf(x) / 45.0) * 45.0) < 4.5 or absf(absf(z) - round(absf(z) / 45.0) * 45.0) < 4.5
			var basis := Basis().scaled(Vector3(3.0, 1.0, 3.0)) * (mesh_nodes[0] as MeshInstance3D).transform.basis
			var origin := point + (mesh_nodes[0] as MeshInstance3D).transform.origin * 3.0
			var transform := Transform3D(basis, origin)
			if radius <= 28.0:
				if int(floor(radius / 4.0)) % 2 == 0:
					plaza_warm_transforms.append(transform)
				else:
					plaza_dark_transforms.append(transform)
			elif on_main_avenue or on_secondary:
				road_transforms.append(transform)
			else:
				block_transforms.append(transform)
	for block_x in range(8):
		for block_z in range(8):
			var cx := -157.5 + float(block_x) * 45.0
			var cz := -157.5 + float(block_z) * 45.0
			for edge in [-1.0, 1.0]:
				for step in range(-5, 6):
					var along := float(step) * 3.0
					curb_transforms.append(Transform3D(Basis().scaled(Vector3(3.0, 1.0, 3.0)), Vector3(cx + edge * 17.25, 0.15, cz + along)))
					curb_transforms.append(Transform3D(Basis().scaled(Vector3(3.0, 1.0, 3.0)), Vector3(cx + along, 0.15, cz + edge * 17.25)))
	_create_paving_batch(parent, "TwinCity_WarmBlockAndCourtyardPaving", tile_mesh, block_transforms, Color("#85796A"), 0.92)
	_create_paving_batch(parent, "TwinCity_DarkBasaltRoadwayPaving", tile_mesh, road_transforms, Color("#5E646B"), 0.92)
	_create_paving_batch(parent, "TwinCity_CentralPlazaWarmStone", tile_mesh, plaza_warm_transforms, Color("#7A7267"), 0.92)
	_create_paving_batch(parent, "TwinCity_CentralPlazaDarkStone", tile_mesh, plaza_dark_transforms, Color("#5A5E63"), 0.92)
	_create_paving_batch(parent, "TwinCity_RaisedPaleBlockCurbs", tile_mesh, curb_transforms, Color("#9E9589"), 0.92)
	print("TWIN_CITY_GLB_PAVING_PASS: blocks=%d roads=%d plaza=%d curbs=%d; 4-pass CAD grid=360m" % [block_transforms.size(), road_transforms.size(), plaza_warm_transforms.size()+plaza_dark_transforms.size(), curb_transforms.size()])

static func _build_plaza(parent: Node3D, source: Node3D) -> void:
	var plaza := Node3D.new()
	plaza.name = "CircularImperialPlaza_Diameter56m"
	parent.add_child(plaza)
	var pagoda := _spawn_glb_node(plaza, PAGODA, "CentralPagoda_22m", Vector3(0.0, 1.2, 0.0), 0.0, 1.0, "landmark")
	if pagoda != null:
		_normalize_node_to_dimensions(pagoda, Vector3(14.0, 22.0, 14.0))
	var plinth := _spawn_glb_node(plaza, BUILDING_BASE, "CentralPagoda_StonePlinth_1p2m", Vector3(0.0, 0.6, 0.0), 0.0, 1.0, "")
	if plinth != null:
		_normalize_node_to_dimensions(plinth, Vector3(20.0, 1.2, 20.0))
	for i in range(8):
		var angle := TAU * float(i) / 8.0
		_clone_source_model(plaza, source, "146-plum-tree-in-blossom", "TwinCity_PlazaCherry_%02d" % i, Vector3(cos(angle) * 18.0, 0.0, sin(angle) * 18.0), -angle, 1.0, "")

static func _build_districts(parent: Node3D, source: Node3D) -> Dictionary:
	var districts := Node3D.new()
	districts.name = "TwinCity_OrthogonalSiheyuanDistricts_360m"
	parent.add_child(districts)
	var census := {"commercial": 0, "residential": 0, "service": 0, "landmark": 0}
	var blocks: Array[Dictionary] = []
	for ix in range(8):
		for iz in range(8):
			var center := Vector3(-157.5 + float(ix) * 45.0, 0.0, -157.5 + float(iz) * 45.0)
			blocks.append({"center": center, "ix": ix, "iz": iz, "score": absf(center.x) + absf(center.z)})
	blocks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.score) < float(b.score))
	var residential_offsets := [Vector3(-8.0, 0.0, -8.0), Vector3(8.0, 0.0, -8.0), Vector3(-8.0, 0.0, 8.0), Vector3(8.0, 0.0, 8.0)]
	var shop_x := [-12.9, -4.3, 4.3, 12.9]
	for block_index in range(64):
		var block: Dictionary = blocks[block_index]
		var center: Vector3 = block.center
		var kind := "commercial" if block_index < 12 else ("residential" if block_index < 30 else ("service" if block_index < 44 else ("landmark" if block_index < 52 else "open")))
		if kind == "open":
			continue
		if kind == "landmark":
			for hall_index in range(2):
				var local: Vector3 = Vector3(-8.0 if hall_index == 0 else 8.0, 0.0, 0.0)
				var pos := center + local
				var template := "130-ceremonial-hall" if (block_index + hall_index) % 2 == 0 else "134-water-pavilion"
				var name := "TwinCity_landmark_%03d" % census.landmark
				if _clone_source_model(districts, source, template, name, pos, 0.0, 1.0, "landmark"):
					var hall := districts.get_node_or_null(NodePath(name)) as Node3D
					if hall != null:
						_normalize_node_to_dimensions(hall, Vector3(16.0, 16.0, 16.0))
					census.landmark += 1
			continue
		if kind == "commercial":
			var face_yaw := 0.0
			if absf(center.x) < absf(center.z):
				face_yaw = PI if center.z < 0.0 else 0.0
			else:
				face_yaw = -PI * 0.5 if center.x < 0.0 else PI * 0.5
			for shop_index in range(4):
				var shop_pos := center + Vector3(shop_x[shop_index], 0.0, -11.5)
				var shop_name := "TwinCity_commercial_%03d" % census.commercial
				var shop := _spawn_modular_building(districts, shop_name, shop_pos, face_yaw, 1.0, "commercial", shop_index)
				if shop != null:
					_normalize_node_to_dimensions(shop, Vector3(7.0, 6.75, 8.5))
					census.commercial += 1
			for house_index in range(4):
				var house_local := [Vector3(-8.0,0.0,0.0), Vector3(8.0,0.0,0.0), Vector3(-8.0,0.0,11.0), Vector3(8.0,0.0,11.0)][house_index]
				var house_name := "TwinCity_residential_%03d" % census.residential
				var house := _spawn_modular_building(districts, house_name, center + house_local, face_yaw, 1.0, "residential", house_index)
				if house != null:
					_normalize_node_to_dimensions(house, Vector3(9.5, 10.25, 10.5))
					census.residential += 1
			continue
		for local_index in range(4):
			var local: Vector3 = residential_offsets[local_index]
			var pos := center + local
			var yaw := 0.0
			if absf(local.z) >= absf(local.x):
				yaw = 0.0 if local.z < 0.0 else PI
			else:
				yaw = -PI * 0.5 if local.x > 0.0 else PI * 0.5
			var node_name := "TwinCity_%s_%03d" % [kind, census[kind]]
			var dims := Vector3(9.5, 10.25, 10.5) if kind == "residential" else Vector3(10.0, 9.0, 10.0)
			var building := _spawn_modular_building(districts, node_name, pos, yaw, 1.0, kind, local_index)
			if building != null:
				_normalize_node_to_dimensions(building, dims)
				census[kind] += 1
	print("TWIN_CITY_GLB_BUILDING_CENSUS: %s total=%d; 48 shops, 120 houses, 56 services, 16 halls; 12 open courtyard blocks; GLB assemblies only" % [str(census), census.values().reduce(func(a, b): return a + b, 0)])
	return census

static func _spawn_modular_building(parent: Node3D, node_name: String, pos: Vector3, yaw: float, scale_factor: float, category: String, variant: int) -> Node3D:
	var building := Node3D.new()
	building.name = node_name
	building.position = pos
	building.rotation = Vector3(0.0, yaw, 0.0)
	building.scale = Vector3.ONE * scale_factor
	parent.add_child(building)
	_register_building(building, category)
	_spawn_glb(building, BUILDING_BASE, node_name + "_Foundation", Vector3(0.0, -0.6, 0.0), 0.0, 0.72, "")
	_spawn_glb(building, ROOM_FLOOR, node_name + "_Floor", Vector3(0.0, 0.9, 0.0), 0.0, 0.72, "")
	_spawn_glb(building, ROOM_WALL, node_name + "_WallFront", Vector3(0.0, 4.1, -5.8), 0.0, 0.68, "")
	_spawn_glb(building, ROOM_WALL, node_name + "_WallBack", Vector3(0.0, 4.1, 5.8), PI, 0.68, "")
	_spawn_glb(building, ROOM_WALL, node_name + "_WallLeft", Vector3(-5.8, 4.1, 0.0), PI * 0.5, 0.68, "")
	_spawn_glb(building, ROOM_WALL, node_name + "_WallRight", Vector3(5.8, 4.1, 0.0), -PI * 0.5, 0.68, "")
	_spawn_glb(building, ROOM_ROOF_BEAM, node_name + "_RoofBeam", Vector3(0.0, 7.0, 0.0), 0.0, 0.68, "")
	_spawn_glb(building, ROOM_ROOF, node_name + "_Roof", Vector3(0.0, 7.9, 0.0), 0.0, 0.78, "")
	_spawn_glb(building, ROOM_DOOR, node_name + "_RoomDoor", Vector3(0.0, 4.1, -5.9), 0.0, 0.68, "")
	_spawn_glb(building, DOOR, node_name + "_Door", Vector3(0.0, 0.1, -6.0), 0.0, 0.56, "")
	_spawn_glb(building, ENTRANCE_STAIRS, node_name + "_EntranceStairs", Vector3(0.0, -0.2, -9.0), 0.0, 0.62, "")
	for corner in [Vector2(-5.0, -5.0), Vector2(5.0, -5.0), Vector2(-5.0, 5.0), Vector2(5.0, 5.0)]:
		_spawn_glb(building, COLUMN_BASE, node_name + "_ColumnBase", Vector3(corner.x, 0.0, corner.y), 0.0, 0.62, "")
		_spawn_glb(building, COLUMN, node_name + "_Column", Vector3(corner.x, 0.0, corner.y), 0.0, 0.62, "")
	if category == "commercial":
		_spawn_glb(building, ARCH_BANNER, node_name + "_ShopArch", Vector3(0.0, 7.0, -7.0), 0.0, 0.68, "")
		_spawn_glb(building, BELL_STRUCTURE, node_name + "_ShopBell", Vector3(7.0, 0.0, -3.0), 0.0, 0.62, "")
		_spawn_glb(building, FENCE_01, node_name + "_ShopFence", Vector3(0.0, 0.0, 10.0), 0.0, 0.7, "")
	elif category == "service":
		_spawn_glb(building, FLOOR_02 if variant % 2 == 0 else FLOOR_01, node_name + "_ServiceWing", Vector3(0.0, 0.0, 0.0), 0.0, 0.42, "")
		_spawn_glb(building, FENCE_02, node_name + "_ServiceCourtyard", Vector3(0.0, 0.0, 12.0), 0.42, 0.42, "")
	else:
		_spawn_glb(building, FENCE_01, node_name + "_ResidentialFenceA", Vector3(-7.0, 0.0, 9.0), 0.0, 0.58, "")
		_spawn_glb(building, FENCE_01, node_name + "_ResidentialFenceB", Vector3(7.0, 0.0, 9.0), 0.0, 0.58, "")
	return building

static func _decorate_building(building: Node3D, category: String, scale_factor: float, variant: int) -> void:
	_spawn_glb(building, BUILDING_BASE, building.name + "_Foundation", Vector3(0.0, -0.7, 0.0), 0.0, 0.68, "")
	_spawn_glb(building, DOOR, building.name + "_EntranceDoor", Vector3(0.0, 0.0, -11.0), 0.0, 0.55, "")
	_spawn_glb(building, ENTRANCE_STAIRS, building.name + "_EntranceStairs", Vector3(0.0, -0.2, -13.0), 0.0, 0.56, "")
	if variant % 2 == 0:
		_spawn_glb(building, COLUMN, building.name + "_EntryColumnA", Vector3(-5.5, 0.0, -8.0), 0.0, 0.58, "")
		_spawn_glb(building, COLUMN, building.name + "_EntryColumnB", Vector3(5.5, 0.0, -8.0), 0.0, 0.58, "")
		_spawn_glb(building, COLUMN_BASE, building.name + "_EntryColumnBaseA", Vector3(-5.5, 0.0, -8.0), 0.0, 0.58, "")
		_spawn_glb(building, COLUMN_BASE, building.name + "_EntryColumnBaseB", Vector3(5.5, 0.0, -8.0), 0.0, 0.58, "")
static func _build_city_greenery_and_props(parent: Node3D, source: Node3D) -> void:
	var living := Node3D.new()
	living.name = "TwinCity_GreeneryAndStreetLife"
	parent.add_child(living)
	for i in range(140):
		var angle := float(i) * 2.399963
		var radius := 42.0 + float((i * 37) % 128)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var tree_paths := ["models/grab3d-birch-grove.glb", "models/grab3d-jungle-tree.glb", "models/grab3d-mangrove-tree.glb", "models/grab3d-baobab-tree.glb"]
		var tree := _spawn_glb_node(living, tree_paths[i % tree_paths.size()], "TwinCity_InteriorTree_%03d" % i, pos, -angle, 1.0, "")
		if tree != null:
			_normalize_node_to_dimensions(tree, Vector3(7.0, 9.5, 7.0))
	for i in range(180):
		var angle := float(i) * 2.399963
		var radius := 36.0 + float((i * 19) % 126)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var template := "154-standing-garden-lantern" if i % 4 == 0 else ("158-hanging-silk-lantern" if i % 4 == 1 else ("153-garden-stone-bench" if i % 4 == 2 else "150-peony-planter"))
		_clone_source_model(living, source, template, "TwinCity_StreetProp_%03d" % i, pos, -angle, 1.0, "")

static func _build_outer_wildlands(parent: Node3D, source: Node3D) -> void:
	var wildlands := Node3D.new()
	wildlands.name = "TwinCity_OuterWildlands_800m"
	parent.add_child(wildlands)
	for i in range(260):
		var angle := float(i) * 2.399963
		var radius := 242.0 + float((i * 29) % 150)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var tree_paths := ["models/grab3d-birch-grove.glb", "models/grab3d-jungle-tree.glb", "models/grab3d-mangrove-tree.glb", "models/grab3d-baobab-tree.glb"]
		var tree := _spawn_glb_node(wildlands, tree_paths[i % tree_paths.size()], "TwinCity_OuterTree_%03d" % i, pos, -angle, 1.0, "")
		if tree != null:
			_normalize_node_to_dimensions(tree, Vector3(8.0, 11.0, 8.0))
	for i in range(80):
		var angle := TAU * float(i) / 80.0 + 0.13
		var radius := 260.0 + float(i % 4) * 18.0
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_clone_source_model(wildlands, source, "145-rockery-outcrop", "TwinCity_OuterRockery_%03d" % i, pos, -angle, 1.0, "")

static func _spawn_glb(parent: Node3D, relative_path: String, node_name: String, pos: Vector3, yaw: float, scale_factor: float, category: String) -> bool:
	return _spawn_glb_node(parent, relative_path, node_name, pos, yaw, scale_factor, category) != null

static func _spawn_glb_node(parent: Node3D, relative_path: String, node_name: String, pos: Vector3, yaw: float, scale_factor: float, category: String) -> Node3D:
	var path := MODEL_ROOT.path_join(relative_path)
	if not ResourceLoader.exists(path):
		push_error("TWIN_CITY_GLB_MISSING: " + path)
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("TWIN_CITY_GLB_LOAD_FAIL: " + path)
		return null
	var instance := packed.instantiate() as Node3D
	if instance == null:
		push_error("TWIN_CITY_GLB_ROOT_FAIL: " + path)
		return null
	instance.name = node_name
	instance.position = pos
	instance.rotation = Vector3(0.0, yaw, 0.0)
	instance.scale = Vector3.ONE * scale_factor
	parent.add_child(instance)
	_register_building(instance, category)
	return instance

static func _clone_source_model(parent: Node3D, source: Node3D, model_name: String, node_name: String, pos: Vector3, yaw: float, scale_factor: float, category: String) -> bool:
	var template := source.find_child(model_name, true, false) as Node3D
	if template == null:
		push_error("TWIN_CITY_IMPERIAL_TEMPLATE_MISSING: " + model_name)
		return false
	var clone := template.duplicate(true) as Node3D
	if clone == null:
		push_error("TWIN_CITY_IMPERIAL_TEMPLATE_CLONE_FAIL: " + model_name)
		return false
	clone.name = node_name
	clone.position = pos
	clone.rotation = Vector3(0.0, yaw, 0.0)
	clone.scale = template.scale * scale_factor
	parent.add_child(clone)
	_register_building(clone, category)
	return true

static func _register_building(root: Node3D, category: String) -> void:
	if category.is_empty():
		return
	root.add_to_group("twin_city_building", true)
	root.set_meta("twin_city_category", category)
	root.add_to_group("twin_city_glb_backed", true)
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if current is GeometryInstance3D:
			var geometry := current as GeometryInstance3D
			geometry.visibility_range_end = 420.0
			geometry.visibility_range_end_margin = 30.0

static func _create_paving_batch(parent: Node3D, node_name: String, source_mesh: Mesh, transforms: Array[Transform3D], tint: Color, roughness: float) -> void:
	if transforms.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	parent.add_child(instance)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = roughness
	material.metallic = 0.0
	instance.material_override = material

static func _apply_imperial_palette(root: Node3D) -> void:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children():
			pending.append(child)
		if not node is MeshInstance3D:
			continue
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		var lower_name := mesh_node.name.to_lower()
		var tint_color := Color("#B89F82")
		if lower_name.contains("roof") or lower_name.contains("eave"):
			tint_color = Color("#2E3238")
		elif lower_name.contains("wood") or lower_name.contains("column") or lower_name.contains("beam"):
			tint_color = Color("#5C3A21")
		elif lower_name.contains("gold") or lower_name.contains("trim"):
			tint_color = Color("#C8963E")
		elif lower_name.contains("stone") or lower_name.contains("floor") or lower_name.contains("base"):
			tint_color = Color("#857D72")
		for surface in range(mesh_node.mesh.get_surface_count()):
			var original := mesh_node.get_active_material(surface)
			if original is StandardMaterial3D:
				var material := (original as StandardMaterial3D).duplicate() as StandardMaterial3D
				material.albedo_color = material.albedo_color * tint_color
				material.roughness = maxf(material.roughness, 0.82)
				mesh_node.set_surface_override_material(surface, material)

static func _node_local_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	var pending: Array[Dictionary] = [{"node": root, "transform": Transform3D.IDENTITY}]
	while not pending.is_empty():
		var item: Dictionary = pending.pop_back()
		var node: Node = item.node
		var transform: Transform3D = item.transform
		if node != root and node is Node3D:
			transform = transform * (node as Node3D).transform
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh != null:
				var local_bounds := mesh_instance.mesh.get_aabb() * transform
				if not has_bounds:
					result = local_bounds
					has_bounds = true
				else:
					result = result.merge(local_bounds)
		for child in node.get_children():
			pending.append({"node": child, "transform": transform})
	return result if has_bounds else AABB()

static func _normalize_node_to_dimensions(root: Node3D, target: Vector3) -> void:
	var bounds := _node_local_aabb(root)
	if bounds.size.x <= 0.001 or bounds.size.y <= 0.001 or bounds.size.z <= 0.001:
		push_error("TWIN_CITY_AABB_FAIL: %s has no valid mesh bounds" % root.name)
		return
	var scale_vector := Vector3(target.x / bounds.size.x, target.y / bounds.size.y, target.z / bounds.size.z)
	root.scale = root.scale * scale_vector
	root.position.y -= bounds.position.y * scale_vector.y
	root.set_meta("twin_city_aabb_normalized", true)
	root.set_meta("twin_city_target_dimensions_m", target)
	_apply_imperial_palette(root)

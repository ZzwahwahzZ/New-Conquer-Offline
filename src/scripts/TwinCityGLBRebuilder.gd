extends RefCounted
## Twin City is assembled from source GLB scenes and source GLB modules only.
## No procedural BoxMesh/CylinderMesh/SphereMesh building geometry is created here.

const MODEL_ROOT := "res://assets/wuxia_imperial_pack/"
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

	_build_ground(root)
	_build_palace(root, source_container)
	_build_perimeter(root, source_container)
	_build_full_city_paving(root, source_container)
	_build_plaza(root, source_container)
	var census := _build_districts(root, source_container)
	_build_outer_wildlands(root, source_container)

	print("TWIN_CITY_GLB_BUILD_PASS: total=%d categories=%s procedural_box_meshes=0 source=GLB" % [census.values().reduce(func(a, b): return a + b, 0), str(census)])

static func _build_ground(parent: Node3D) -> void:
	var ground := MeshInstance3D.new()
	ground.name = "TwinCity_800m_TerrainFoundation"
	var plane := PlaneMesh.new()
	plane.size = Vector2(800.0, 800.0)
	ground.mesh = plane
	ground.position.y = -0.24
	parent.add_child(ground)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#6c8055")
	material.roughness = 1.0
	ground.material_override = material

static func _build_palace(parent: Node3D, source: Node3D) -> void:
	var palace := source.duplicate(true) as Node3D
	if palace == null:
		push_error("TWIN_CITY_GLB_FAIL: palace compound clone failed")
		return
	palace.name = "ImperialPalace_85x75"
	palace.position = Vector3(0.0, 0.0, -108.0)
	palace.rotation = Vector3.ZERO
	palace.scale = Vector3.ONE * 1.35
	parent.add_child(palace)
	palace.add_to_group("twin_city_imperial_source_compound")

static func _build_perimeter(parent: Node3D, source: Node3D) -> void:
	var fort := Node3D.new()
	fort.name = "TwinCity_ImperialPerimeter_440m"
	parent.add_child(fort)

	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = Color("#155c67")
	water_material.roughness = 0.22
	for side in range(4):
		var water := MeshInstance3D.new()
		water.name = "DeepContinuousWaterMoat_440m" if side == 0 else "MoatWaterSegment_%d" % side
		var water_mesh := PlaneMesh.new()
		water_mesh.size = Vector2(440.0, 14.0)
		water.mesh = water_mesh
		water.position = [Vector3(0.0, -0.05, -228.0), Vector3(228.0, -0.05, 0.0), Vector3(0.0, -0.05, 228.0), Vector3(-228.0, -0.05, 0.0)][side]
		water.rotation.y = PI * 0.5 if side % 2 == 1 else 0.0
		fort.add_child(water)
		water.material_override = water_material

	var wall_template := "064-palace-wall-straight"
	var corner_template := "060-palace-wall-corner"
	var moon_gate_template := "087-palace-wall-moon-gate"
	var end_pier_template := "088-palace-wall-end-pier"
	for side in range(4):
		var yaw := float(side) * PI * 0.5
		for segment in range(32):
			if segment == 15 or segment == 16:
				continue
			var along := -216.0 + float(segment) * 13.5
			var pos := Vector3(along, 0.0, -220.0)
			if side == 1:
				pos = Vector3(220.0, 0.0, along)
			elif side == 2:
				pos = Vector3(-along, 0.0, 220.0)
			elif side == 3:
				pos = Vector3(-220.0, 0.0, -along)
			_clone_source_model(fort, source, wall_template, "TwinCity_ImperialWall_%02d_%02d" % [side, segment], pos, yaw, 1.25, "")
		var corner_positions := [Vector3(-220.0, 0.0, -220.0), Vector3(220.0, 0.0, -220.0), Vector3(220.0, 0.0, 220.0), Vector3(-220.0, 0.0, 220.0)]
		_clone_source_model(fort, source, corner_template, "TwinCity_ImperialWallCorner_%02d" % side, corner_positions[side], yaw, 1.4, "")

		var gate_direction := Vector3(sin(yaw), 0.0, -cos(yaw))
		var gate_center := gate_direction * 220.0
		_clone_source_model(fort, source, moon_gate_template, "TwinCity_ImperialMoonGate_%02d" % side, gate_center, yaw, 1.55, "")
		_clone_source_model(fort, source, end_pier_template, "TwinCity_ImperialGatePierA_%02d" % side, gate_center + Vector3(-sin(yaw) * 18.0, 0.0, cos(yaw) * 18.0), yaw, 1.5, "")
		_clone_source_model(fort, source, end_pier_template, "TwinCity_ImperialGatePierB_%02d" % side, gate_center + Vector3(sin(yaw) * 18.0, 0.0, -cos(yaw) * 18.0), yaw, 1.5, "")
		_clone_source_model(fort, source, "131-gate-tower", "TwinCity_GrandGateTower_%02d" % side, gate_center, yaw, 1.35, "")
		_clone_source_model(fort, source, "135-arched-stone-bridge", "TwinCity_GrandStoneBridge_%02d" % side, gate_center + gate_direction * 12.0, yaw, 1.7, "")

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

	var transforms: Array[Transform3D] = []
	for x in range(-216, 217, 6):
		for z in range(-216, 217, 6):
			if absf(float(x)) <= 216.0 and absf(float(z)) <= 216.0:
				transforms.append(Transform3D(Basis().scaled(Vector3(3.0, 1.0, 3.0)), Vector3(float(x), 0.06, float(z))))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = source_mesh
	multi.instance_count = transforms.size()
	for i in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
	var paving := MultiMeshInstance3D.new()
	paving.name = "WallToWallOriginalImperialEngravedFlagstone"
	paving.multimesh = multi
	parent.add_child(paving)
	var source_material := (mesh_nodes[0] as MeshInstance3D).get_active_material(0)
	if source_material != null:
		paving.material_override = source_material
	print("TWIN_CITY_GLB_PAVING_PASS: original_059_module_instances=%d full_city_coverage=1" % transforms.size())

static func _build_plaza(parent: Node3D, source: Node3D) -> void:
	var plaza := Node3D.new()
	plaza.name = "CircularImperialPlaza_60m"
	parent.add_child(plaza)
	_spawn_glb(plaza, PAGODA, "CentralPagoda_20m", Vector3.ZERO, 0.0, 0.66, "landmark")
	for i in range(4):
		var angle := TAU * float(i) / 4.0
		_clone_source_model(plaza, source, "134-water-pavilion", "TwinCity_PlazaWaterPavilion_%02d" % i, Vector3(cos(angle) * 26.0, 0.0, sin(angle) * 26.0), -angle, 0.72, "")

static func _build_districts(parent: Node3D, source: Node3D) -> Dictionary:
	var districts := Node3D.new()
	districts.name = "DenseMixedResidentialCommercialDistricts_GLBBased"
	parent.add_child(districts)
	var census := {"residential": 0, "commercial": 0, "service": 0, "landmark": 1, "defensive": 0, "palace_annex": 0}
	var house_offsets := [
		Vector3(-13.0, 0.0, -13.0), Vector3(0.0, 0.0, -13.0), Vector3(13.0, 0.0, -13.0),
		Vector3(-13.0, 0.0, 0.0), Vector3(13.0, 0.0, 0.0),
		Vector3(-13.0, 0.0, 13.0), Vector3(0.0, 0.0, 13.0), Vector3(13.0, 0.0, 13.0)
	]
	for block in range(12):
		var angle := TAU * float(block) / 12.0
		var radius := 84.0 + float(block % 4) * 17.0
		var center := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var rotation := -angle - PI * 0.5
		for local_index in range(house_offsets.size()):
			var pos: Vector3 = center + Basis(Vector3.UP, rotation) * house_offsets[local_index]
			var shell := FLOOR_01 if (block + local_index) % 2 == 0 else FLOOR_02
			var house := _spawn_glb_node(districts, shell, "TwinCity_residential_%03d" % census.residential, pos, rotation, 0.56, "residential")
			if house != null:
				_decorate_building(house, "residential", 0.56, block + local_index)
				census.residential += 1
		for shop_index in range(2):
			var offset := Vector3(-6.0 + float(shop_index) * 12.0, 0.0, -27.0)
			var pos := center + Basis(Vector3.UP, rotation) * offset
			var shop := _spawn_modular_building(districts, "TwinCity_commercial_%03d" % census.commercial, pos, rotation, 0.62, "commercial", shop_index)
			if shop != null:
				census.commercial += 1
		var service_pos := center + Basis(Vector3.UP, rotation) * Vector3(0.0, 0.0, 27.0)
		var service := _spawn_modular_building(districts, "TwinCity_service_%03d" % census.service, service_pos, rotation, 0.52, "service", block)
		if service != null:
			census.service += 1
		if block < 11:
			var landmark_pos := center + Basis(Vector3.UP, rotation) * Vector3(0.0, 0.0, 43.0)
			if block % 2 == 0:
				if _clone_source_model(districts, source, "134-water-pavilion", "TwinCity_landmark_%03d" % census.landmark, landmark_pos, rotation, 0.78, "landmark"):
					census.landmark += 1
			else:
				if _clone_source_model(districts, source, "130-ceremonial-hall", "TwinCity_landmark_%03d" % census.landmark, landmark_pos, rotation, 0.7, "landmark"):
					census.landmark += 1

	for i in range(24):
		var angle := TAU * float(i) / 24.0 + 0.19
		var radius := 56.0 + float(i % 3) * 7.0
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var shell := FLOOR_01 if i % 2 == 0 else FLOOR_02
		var house := _spawn_glb_node(districts, shell, "TwinCity_residential_%03d" % census.residential, pos, -angle - PI * 0.5, 0.54 + float(i % 3) * 0.03, "residential")
		if house != null:
			_decorate_building(house, "residential", 0.55, i)
			census.residential += 1

	for i in range(18):
		var angle := TAU * float(i) / 18.0 + 0.31
		var radius := 64.0 + float(i % 2) * 8.0
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var shop := _spawn_modular_building(districts, "TwinCity_commercial_%03d" % census.commercial, pos, -angle - PI * 0.5, 0.58, "commercial", i)
		if shop != null:
			census.commercial += 1

	for i in range(10):
		var angle := TAU * float(i) / 10.0 + 0.27
		var pos := Vector3(cos(angle) * 151.0, 0.0, sin(angle) * 151.0)
		var service := _spawn_modular_building(districts, "TwinCity_service_%03d" % census.service, pos, -angle - PI * 0.5, 0.5, "service", i)
		if service != null:
			census.service += 1

	for i in range(20):
		var angle := TAU * float(i) / 20.0
		var pos := Vector3(cos(angle) * 190.0, 0.0, sin(angle) * 190.0)
		if _clone_source_model(districts, source, "131-gate-tower", "TwinCity_defensive_%03d" % census.defensive, pos, angle, 1.0, "defensive"):
			census.defensive += 1

	for i in range(8):
		var angle := TAU * float(i) / 8.0
		var pos := Vector3(cos(angle) * 80.0, 0.0, -108.0 + sin(angle) * 80.0)
		var template_name := "130-ceremonial-hall" if i % 2 == 0 else "134-water-pavilion"
		if _clone_source_model(districts, source, template_name, "TwinCity_palace_annex_%03d" % census.palace_annex, pos, -angle, 0.86, "palace_annex"):
			census.palace_annex += 1

	print("TWIN_CITY_GLB_BUILDING_CENSUS: %s total=%d" % [str(census), census.values().reduce(func(a, b): return a + b, 0)])
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
static func _build_outer_wildlands(parent: Node3D, source: Node3D) -> void:
	var wildlands := Node3D.new()
	wildlands.name = "TwinCity_OuterWildlands_800m"
	parent.add_child(wildlands)
	for i in range(32):
		var angle := float(i) * 2.399963
		var radius := 248.0 + float((i * 29) % 92)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var tree_name := "146-plum-tree-in-blossom" if i % 2 == 0 else "147-bamboo-clump"
		_clone_source_model(wildlands, source, tree_name, "TwinCity_OuterTree_%02d" % i, pos, -angle, 1.8, "")
	for i in range(24):
		var angle := TAU * float(i) / 24.0 + 0.13
		var radius := 265.0 + float(i % 4) * 18.0
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_clone_source_model(wildlands, source, "145-rockery-outcrop", "TwinCity_OuterRockery_%02d" % i, pos, -angle, 2.1, "")

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

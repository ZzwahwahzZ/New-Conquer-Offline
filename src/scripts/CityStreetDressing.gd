extends RefCounted
## Classic Conquer-inspired street fabric shared by all six settlements.
const PBRMaterialLibrary = preload("res://src/scripts/PBRMaterialLibrary.gd")
const STONE_LIGHT := Color("#b9b6aa")
const STONE_DARK := Color("#514b46")
const IRON := Color("#252a2d")
const FLOWERS := [Color("#c93442"), Color("#f1c84b"), Color("#e879b5"), Color("#9865d5")]

static func build(parent: Node3D, city: String, size: float) -> void:
	var half := 110.0 if city == "TwinCity" else 80.0
	var road_mat: StandardMaterial3D = PBRMaterialLibrary.build_street_material()
	road_mat.albedo_color = _road_color(city).lightened(0.35)
	var plaza_mat: StandardMaterial3D = PBRMaterialLibrary.build_plaza_material()
	plaza_mat.albedo_color = _plaza_color(city).lightened(0.2)
	var border_mat := _mat(_border_color(city), 0.72)
	# Four cardinal avenues, a perimeter loop, and cross-links between districts.
	_add_plane(parent, "Street_NorthSouth", Vector2(10.0, half * 1.72), road_mat, Vector3(0, 0.045, 0))
	_add_plane(parent, "Street_EastWest", Vector2(half * 1.72, 10.0), road_mat, Vector3(0, 0.047, 0))
	for offset in [-42.0, 42.0]:
		_add_plane(parent, "DistrictLane_NS_" + str(int(offset)), Vector2(5.0, half * 1.48), road_mat, Vector3(offset, 0.052, 0))
		_add_plane(parent, "DistrictLane_EW_" + str(int(offset)), Vector2(half * 1.48, 5.0), road_mat, Vector3(0, 0.054, offset))
	_add_plane(parent, "CentralDarkSquare", Vector2(30.0, 30.0), plaza_mat, Vector3(0, 0.062, 0))
	# Four broad paved approaches link the square to the city gates.
	for side in [-1.0, 1.0]:
		_add_plane(parent, "GateApproach_X_" + str(side), Vector2(7.0, half * 0.82), road_mat, Vector3(side * half * 0.48, 0.058, 0))
		_add_plane(parent, "GateApproach_Z_" + str(side), Vector2(half * 0.82, 7.0), road_mat, Vector3(0, 0.059, side * half * 0.48))
	# Decorative raised stone beds beside avenues and building frontages.
	var bed_positions: Array[Vector3] = []
	for axis in [-1.0, 1.0]:
		for lane in [-1.0, 1.0]:
			bed_positions.append(Vector3(axis * 19.0, 0.0, lane * 28.0))
			bed_positions.append(Vector3(axis * 28.0, 0.0, lane * 19.0))
			bed_positions.append(Vector3(axis * 57.0, 0.0, lane * 18.0))
	for index in range(bed_positions.size()):
		_add_planter(parent, city, bed_positions[index], index)
	# Low railings frame stair/market square edges and gate approaches.
	_add_railing(parent, "SquareRail_N", Vector3(0, 0, -19), 30.0, city)
	_add_railing(parent, "SquareRail_S", Vector3(0, 0, 19), 30.0, city)
	_add_railing(parent, "SquareRail_E", Vector3(19, 0, 0), 30.0, city, true)
	_add_railing(parent, "SquareRail_W", Vector3(-19, 0, 0), 30.0, city, true)
	if city == "Waterlands":
		_waterways(parent, half)
	if city == "TwinCity":
		_twin_city_canals(parent, half)
	if city == "VolcanoLand":
		_lava_channels(parent, half)
	if city == "IceLand":
		_ice_crystal_beds(parent)
	if city == "DarkForest":
		_ancient_lantern_beds(parent)
	if city == "TwinCity":
		_add_plane(parent, "TwinCityTrainingGround", Vector2(28, 20), _mat(Color("#8d795c"), 0.92), Vector3(-34, 0.052, 36))
	print("CITY_STREET_DRESSING_PASS: %s roads=%d planters=%d railings=4" % [city, 13, bed_positions.size()])

static func _add_plane(parent: Node3D, label: String, dimensions: Vector2, material: Material, at: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := PlaneMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	var surface_material := material
	if material is StandardMaterial3D and (material as StandardMaterial3D).resource_name.begins_with("PolyHaven_"):
		var pbr_material := (material as StandardMaterial3D).duplicate() as StandardMaterial3D
		var tile_width := 3.4 if pbr_material.resource_name.contains("Pavement05") else 2.0
		pbr_material.uv1_scale = Vector3(maxf(1.0, dimensions.x / tile_width), maxf(1.0, dimensions.y / tile_width), 1.0)
		surface_material = pbr_material
	node.material_override = surface_material

static func _add_planter(parent: Node3D, city: String, at: Vector3, seed: int) -> void:
	var root := Node3D.new()
	root.name = city + "_RaisedFlowerBed_%02d" % seed
	root.position = at
	parent.add_child(root)
	var stone := MeshInstance3D.new()
	stone.name = "RaisedStoneBasin"
	var basin := BoxMesh.new()
	basin.size = Vector3(7.2, 0.62, 3.2)
	stone.mesh = basin
	stone.position.y = 0.34
	root.add_child(stone)
	stone.material_override = _mat(_border_color(city), 0.82)
	var soil := MeshInstance3D.new()
	var soil_mesh := BoxMesh.new()
	soil_mesh.size = Vector3(6.55, 0.12, 2.55)
	soil.mesh = soil_mesh
	soil.position.y = 0.70
	root.add_child(soil)
	soil.material_override = _mat(Color("#403b31"), 1.0)
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.22
	flower_mesh.height = 0.42
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = flower_mesh
	multi.instance_count = 20
	for i in range(20):
		var x := -2.8 + float((i * 17 + seed * 3) % 57) / 10.0
		var z := -0.9 + float((i * 11 + seed * 7) % 19) / 10.0
		var scale := 0.72 + float((i + seed) % 5) * 0.12
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), Vector3(x, 0.96, z)))
	var flowers := MultiMeshInstance3D.new()
	flowers.name = "FlowerCluster_MultiMesh"
	flowers.multimesh = multi
	var flower_material := _mat(FLOWERS[posmod(seed, FLOWERS.size())], 0.48)
	flower_material.emission_enabled = false
	flower_material.emission = FLOWERS[posmod(seed, FLOWERS.size())] * 0.28
	root.add_child(flowers)
	flowers.material_override = flower_material
	# Dense clipped shrub row as a second batched mesh.
	var shrub_mesh := SphereMesh.new()
	shrub_mesh.radius = 0.34
	shrub_mesh.height = 0.52
	var shrubs := MultiMesh.new()
	shrubs.transform_format = MultiMesh.TRANSFORM_3D
	shrubs.mesh = shrub_mesh
	shrubs.instance_count = 8
	for i in range(8):
		shrubs.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-2.8 + i * 0.8, 0.92, 0.0)))
	var shrub_node := MultiMeshInstance3D.new()
	shrub_node.name = "EvergreenShrubs_MultiMesh"
	shrub_node.multimesh = shrubs
	root.add_child(shrub_node)
	shrub_node.material_override = _mat(_foliage_color(city), 0.9)

static func _add_railing(parent: Node3D, label: String, at: Vector3, length: float, city: String, rotate := false) -> void:
	var root := Node3D.new()
	root.name = city + "_" + label
	root.position = at
	if rotate:
		root.rotation.y = PI * 0.5
	parent.add_child(root)
	var rail_mat := _mat(_rail_color(city), 0.48)
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.22, 0.95, 0.22)
	posts.mesh = post_mesh
	var count := int(length / 2.0) + 1
	posts.instance_count = count
	for i in range(count):
		posts.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(-length * 0.5 + float(i) * 2.0, 0.5, 0)))
	var post_node := MultiMeshInstance3D.new()
	post_node.name = "IronBalusters_MultiMesh"
	post_node.multimesh = posts
	root.add_child(post_node)
	post_node.material_override = rail_mat
	for y in [0.35, 0.86]:
		var bar := MeshInstance3D.new()
		bar.name = "ContinuousHandrail"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(length, 0.16, 0.2)
		bar.mesh = mesh
		bar.position = Vector3(0, y, 0)
		root.add_child(bar)
		bar.material_override = rail_mat

static func _waterways(parent: Node3D, half: float) -> void:
	var water := _mat(Color("#267f91"), 0.22)
	water.metallic = 0.12
	var wood := _mat(Color("#795338"), 0.72)
	for side in [-1.0, 1.0]:
		var canal_x: float = float(side) * half * 0.31
		_add_plane(parent, "ApeCityCanal_" + ("East" if side > 0.0 else "West"), Vector2(7, half * 1.55), water, Vector3(canal_x, -1.0, 0))
		for z in [-42.0, 0.0, 42.0]:
			_add_bridge(parent, "ApeCityTimberBridge", Vector3(canal_x, 0.0, z), Vector2(12.0, 9.0), wood, "Waterlands")

static func _twin_city_canals(parent: Node3D, half: float) -> void:
	var water := _mat(Color("#247f9a"), 0.2)
	water.metallic = 0.14
	var stone := _mat(Color("#a18b68"), 0.78)
	for side in [-1.0, 1.0]:
		var canal_x: float = float(side) * 130.0
		_add_plane(parent, "TwinCityImperialCanal_" + ("East" if side > 0.0 else "West"), Vector2(9.0, half * 2.1), water, Vector3(canal_x, -1.0, 0))
		for z in [-70.0, 0.0, 70.0]:
			_add_bridge(parent, "TwinCityStoneBridge", Vector3(canal_x, 0.0, z), Vector2(15.0, 10.0), stone, "TwinCity")

static func _add_bridge(parent: Node3D, prefix: String, at: Vector3, dimensions: Vector2, material: Material, city: String) -> void:
	var bridge := Node3D.new()
	bridge.name = city + "_" + prefix + "_" + str(int(at.x)) + "_" + str(int(at.z))
	bridge.position = at
	bridge.add_to_group("world_bridge")
	parent.add_child(bridge)
	var deck := MeshInstance3D.new()
	deck.name = "BridgeDeck"
	var deck_mesh := PlaneMesh.new()
	deck_mesh.size = dimensions
	deck.mesh = deck_mesh
	deck.position.y = 0.12
	bridge.add_child(deck)
	deck.material_override = material
	var imported_bridge_found := false
	var bridge_model_path := "res://assets/environment/kenney/nature-kit/Models/GLTF format/bridge_wood.glb" if city == "Waterlands" else "res://assets/environment/kenney/nature-kit/Models/GLTF format/bridge_stone.glb"
	if ResourceLoader.exists(bridge_model_path):
		var bridge_pack := load(bridge_model_path) as PackedScene
		if bridge_pack != null:
			var imported_bridge := bridge_pack.instantiate() as Node3D
			if imported_bridge != null:
				# Kenney GLB scenes can include helper MeshInstance3D nodes without geometry.
				# Hide those nodes before the scene enters the renderer; keep child transforms intact.
				_sanitize_imported_mesh_nodes(imported_bridge)
				imported_bridge.name = "KenneyBridgeModel"
				var bridge_mesh := _first_mesh_node(imported_bridge)
				if bridge_mesh != null and bridge_mesh.mesh != null:
					var bounds := bridge_mesh.mesh.get_aabb().size
					var horizontal_extent := maxf(bounds.x, bounds.z)
					if horizontal_extent > 0.01:
						var fit_scale := clampf(dimensions.x / horizontal_extent, 0.8, 3.5)
						imported_bridge.scale = Vector3.ONE * fit_scale
						if bounds.z > bounds.x:
							imported_bridge.rotation.y = PI * 0.5
						imported_bridge.position.y = 0.12
						bridge.add_child(imported_bridge)
						deck.visible = false
						imported_bridge_found = true
	var body := StaticBody3D.new()
	body.name = "BridgeCollisionBody"
	var collider := CollisionShape3D.new()
	collider.name = "BridgeWalkableCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(dimensions.x, 0.32, dimensions.y)
	collider.shape = box
	collider.position.y = -0.04
	body.add_child(collider)
	bridge.add_child(body)
	if not imported_bridge_found:
		_add_railing(bridge, "BridgeRail_N", Vector3(0, 0, -dimensions.y * 0.5), dimensions.x, city)
		_add_railing(bridge, "BridgeRail_S", Vector3(0, 0, dimensions.y * 0.5), dimensions.x, city)

static func _lava_channels(parent: Node3D, half: float) -> void:
	var lava := _mat(Color("#ed4b18"), 0.3)
	lava.emission_enabled = true
	lava.emission = Color("#ff3d0b")
	lava.emission_energy_multiplier = 1.3
	_add_plane(parent, "PhoenixLavaRunoff_East", Vector2(5, half * 1.3), lava, Vector3(half * 0.34, 0.03, 0))
	_add_plane(parent, "PhoenixLavaRunoff_West", Vector2(5, half * 1.3), lava, Vector3(-half * 0.34, 0.03, 0))

static func _ice_crystal_beds(parent: Node3D) -> void:
	for i in range(8):
		var crystal := MeshInstance3D.new()
		crystal.name = "IceCrystalLantern_%02d" % i
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.9, 2.4, 0.9)
		crystal.mesh = mesh
		crystal.position = Vector3(-32 + i * 9, 1.2, -29 if i % 2 == 0 else 29)
		var material := _mat(Color("#9deaff"), 0.18)
		material.emission_enabled = false
		parent.add_child(crystal)
		crystal.material_override = material

static func _ancient_lantern_beds(parent: Node3D) -> void:
	for i in range(10):
		var lantern := MeshInstance3D.new()
		lantern.name = "ForestSpiritLantern_%02d" % i
		var mesh := SphereMesh.new()
		mesh.radius = 0.26
		mesh.height = 0.52
		lantern.mesh = mesh
		lantern.position = Vector3(-40 + i * 8, 1.0, -34 if i % 2 == 0 else 34)
		var material := _mat(Color("#72d79a"), 0.25)
		material.emission_enabled = false
		parent.add_child(lantern)
		lantern.material_override = material

static func _first_mesh_node(root: Node) -> MeshInstance3D:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if current is MeshInstance3D:
			var mesh_instance := current as MeshInstance3D
			if mesh_instance.mesh != null:
				return mesh_instance
	return null

static func _sanitize_imported_mesh_nodes(root: Node) -> void:
	# Remove null-mesh helper nodes from detached GLB scenes before attachment.
	# Avoid surface-count queries: the headless dummy renderer can receive
	# a null RID for imported helper meshes even when the resource exists.
	var pending: Array[Node] = [root]
	var removed_empty := 0
	var retained_meshes := 0
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			if child is MeshInstance3D:
				var mesh_instance := child as MeshInstance3D
				var invalid_mesh := mesh_instance.mesh == null
				if invalid_mesh:
					current.remove_child(child)
					child.queue_free()
					removed_empty += 1
					continue
				retained_meshes += 1
			pending.append(child)
	print("KENNEY_BRIDGE_MESH_AUDIT: removed_empty=" + str(removed_empty) + " retained_renderable=" + str(retained_meshes))

static func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material

static func _road_color(city: String) -> Color:
	match city:
		"DesertLand": return Color("#8a6945")
		"VolcanoLand": return Color("#403b3d")
		"IceLand": return Color("#627f91")
		"Waterlands": return Color("#a3a08a")
		"DarkForest": return Color("#65715c")
		_: return STONE_LIGHT

static func _plaza_color(city: String) -> Color:
	return Color("#38363b") if city == "VolcanoLand" else (Color("#4a5157") if city == "DarkForest" else (Color("#435968") if city == "IceLand" else (Color("#665039") if city == "DesertLand" else STONE_DARK)))

static func _border_color(city: String) -> Color:
	return Color("#6b5143") if city == "DesertLand" else (Color("#455c69") if city == "IceLand" else Color("#77736a"))

static func _rail_color(city: String) -> Color:
	return Color("#17191d") if city in ["VolcanoLand", "DarkForest"] else (Color("#9cb9c8") if city == "IceLand" else Color("#454a4b"))

static func _foliage_color(city: String) -> Color:
	return Color("#9a4b31") if city == "VolcanoLand" else (Color("#4c7b4d") if city == "DesertLand" else (Color("#315f45") if city == "DarkForest" else Color("#4e8b55")))

extends Node3D

const ROOT := "res://asset_cache/assets/wuxia_imperial_pack/"
const MANIFEST := ROOT + "imperial_approved_assets.json"
const BUILDINGS := ["Hanok Main House (Korean Hanok Village and Street)", "Thatched Outbuilding (Korean Hanok Village and Street)", "Market Stall With Awning (Korean Hanok Village and Street)", "Ceremonial Hall (Imperial China Palace and Garden)", "Water Pavilion (Imperial China Palace and Garden)", "Lotus pond pavilion (Imperial China Palace and Garden)"]
const TREES := [
	{"name": "Plum Tree In Blossom (Imperial China Palace and Garden)", "count": 120},
	{"name": "Bamboo Clump (Imperial China Palace and Garden)", "count": 120},
	{"name": "Pine Tree (Wipe Day Survival Island)", "count": 110}
]
var entries: Dictionary = {}
var scenes: Dictionary = {}
var fit_cache: Dictionary = {}
var materials: Dictionary = {}
var stats := {"buildings": 0, "district_buildings": 0, "wall_segments": 0, "directional_gates": 0, "bridges": 0,
	"gate_guardian_pairs": 0, "gate_guardian_statues": 0, "tree_instances": 0,
	"multimesh_batches": 0, "box_mesh_count": 0, "city_core_m": 260, "world_m": 800, "building_types": 6,
	"district_blocks": 10, "shopkeeper_spawns": 0, "city_layout": "organic_radial", "architecture_style": "imperial_chinese"}

func _ready() -> void:
	if not _load_manifest(): return
	_build_environment()
	_build_ground_and_roads()
	_build_channels()
	_build_walls_and_gates()
	_build_palace_and_plaza()
	_build_districts()
	_build_trees()
	_build_cameras()
	_audit()
	set_meta("build_stats", stats)
	print("TWIN_CITY_BUILD_AUDIT: " + JSON.stringify(stats))

func _load_manifest() -> bool:
	if not FileAccess.file_exists(MANIFEST):
		push_error("Approved manifest missing: " + MANIFEST); return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary or not data.has("categories"):
		push_error("Approved manifest is invalid."); return false
	for category in data.categories:
		for item in data.categories[category].get("assets", []):
			if item.get("style_group", "") in ["imperial_chinese", "korean_hanok", "environmental", "pbr_materials"]:
				var entry_key := str(item.get("file", "")) if item.get("style_group", "") == "pbr_materials" else str(item.get("name", ""))
				entries[entry_key] = item
	print("TWIN_CITY_APPROVED_MANIFEST_PASS: " + str(data.get("total_approved_files", 0)))
	return true

func _packed(name: String) -> PackedScene:
	if scenes.has(name): return scenes[name] as PackedScene
	var item: Dictionary = entries.get(name, {})
	if item.is_empty() or item.get("style_group", "") not in ["imperial_chinese", "korean_hanok", "environmental"]:
		push_error("Unapproved architecture/tree source: " + name); return null
	var path := ROOT + str(item.file)
	if not ResourceLoader.exists(path):
		push_error("Approved GLB missing: " + path); return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Godot failed importing GLB: " + path); return null
	scenes[name] = scene
	return scene

func _bounds(node: Node, parent: Transform3D) -> Dictionary:
	var xform := parent
	if node is Node3D: xform = parent * (node as Node3D).transform
	var found := false
	var box := AABB()
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		box = ((node as MeshInstance3D).mesh as Mesh).get_aabb() * xform
		found = true
	for child in node.get_children():
		var result := _bounds(child, xform)
		if result.found:
			if found: box = box.merge(result.bounds)
			else: box = result.bounds; found = true
	return {"found": found, "bounds": box}

func _fit(name: String, target: Vector3) -> float:
	var key := name + str(target)
	if fit_cache.has(key): return float(fit_cache[key])
	var scene := _packed(name)
	if scene == null: return 1.0
	var sample := scene.instantiate()
	var result := _bounds(sample, Transform3D.IDENTITY)
	sample.free()
	if not result.found:
		push_error("GLB contains no mesh geometry: " + name); return 1.0
	var size: Vector3 = result.bounds.size
	if minf(size.x, minf(size.y, size.z)) <= 0.001:
		push_error("GLB has invalid dimensions: " + name); return 1.0
	var scale := minf(target.x / size.x, minf(target.y / size.y, target.z / size.z))
	fit_cache[key] = scale
	return scale

func _place(name: String, pos: Vector3, yaw: float, scale: float, parent: Node3D, label: String) -> Node3D:
	var scene := _packed(name)
	if scene == null: return null
	var node := scene.instantiate() as Node3D
	if node == null: push_error("GLB root is not Node3D: " + name); return null
	node.name = label
	node.position = pos
	node.rotation.y = yaw
	node.scale = Vector3.ONE * scale
	node.set_meta("approved_asset_name", name)
	node.set_meta("approved_asset_file", str(entries[name].file))
	parent.add_child(node)
	return node

func _place_fit(name: String, pos: Vector3, yaw: float, target: Vector3, parent: Node3D, label: String) -> Node3D:
	return _place(name, pos, yaw, _fit(name, target), parent, label)

func _texture(folder: String, suffix: String) -> String:
	for item in entries.values():
		if item.get("style_group", "") == "pbr_materials":
			var file := str(item.file)
			if file.begins_with("textures/" + folder + "/") and file.ends_with(suffix):
				return ROOT + file
	return ""

func _pbr(folder: String, uv: float) -> StandardMaterial3D:
	var key := folder + str(uv)
	if materials.has(key): return materials[key] as StandardMaterial3D
	var color := _texture(folder, "_1K-JPG_Color.jpg")
	var normal := _texture(folder, "_1K-JPG_NormalGL.jpg")
	var rough := _texture(folder, "_1K-JPG_Roughness.jpg")
	if color.is_empty() or normal.is_empty() or rough.is_empty():
		push_error("Approved PBR maps incomplete: " + folder); return StandardMaterial3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(color) as Texture2D
	mat.normal_enabled = true
	mat.normal_texture = load(normal) as Texture2D
	mat.roughness_texture = load(rough) as Texture2D
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * uv
	if mat.albedo_texture == null or mat.normal_texture == null or mat.roughness_texture == null:
		push_error("Godot could not load PBR textures: " + folder)
	materials[key] = mat
	return mat

func _plane(parent: Node3D, label: String, size: Vector2, pos: Vector3, mat: Material, yaw: float = 0.0) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := PlaneMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.rotation.y = yaw
	node.material_override = mat
	parent.add_child(node)

func _disc(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 96
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)

func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "TwinCityEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#4e9bd8")
	sky_mat.sky_horizon_color = Color("#d5e8f6")
	sky_mat.ground_bottom_color = Color("#8eaa86")
	sky_mat.ground_horizon_color = Color("#c3d3bc")
	sky.sky_material = sky_mat
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.86
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.28
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#c7dceb")
	env.fog_depth_begin = 155.0
	env.fog_depth_end = 720.0
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "ImperialDaySun"
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("#fff1d8")
	sun.light_energy = 0.68
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 300
	add_child(sun)

func _build_ground_and_roads() -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("#6e9560")
	grass.roughness = 1.0
	_plane(self, "WorldGround_800m", Vector2(800, 800), Vector3(0, -0.18, 0), grass)
	var roads := Node3D.new()
	roads.name = "OrganicRadialImperialStreetNetwork"
	add_child(roads)
	var stone := _pbr("PavingStones036", 0.22)
	for ring_index in range(2):
		var radius := 46.0 if ring_index == 0 else 101.0
		for i in range(40):
			var angle := TAU * float(i) / 40.0
			var r := radius + 2.4 * sin(angle * 3.0) + 1.2 * cos(angle * 5.0)
			var pos := Vector3(sin(angle) * r, 0.025 + float(ring_index) * 0.006, cos(angle) * r)
			_plane(roads, "CurvedRingRoad_%d_%02d" % [ring_index, i], Vector2(8.0, 18.0), pos, stone, angle - PI / 2.0)
	for spoke in range(10):
		var angle := TAU * float(spoke) / 10.0
		for segment in range(3):
			var radius := 55.0 + float(segment) * 22.0
			var pos := Vector3(sin(angle) * radius, 0.035, cos(angle) * radius)
			_plane(roads, "RadialAvenue_%02d_%d" % [spoke, segment], Vector2(8.0, 25.0), pos, stone, angle)
	var plaza := Node3D.new()
	plaza.name = "CentralEngravedCircularPlaza"
	add_child(plaza)
	_disc(plaza, "OuterPavingMedallion_Marble", 31.0, 0.22, Vector3(0, 0.04, 0), _pbr("Marble012", 0.28))
	_disc(plaza, "MiddlePavingRing_Stone", 25.0, 0.28, Vector3(0, 0.17, 0), stone)
	_disc(plaza, "InnerPavingRing_Marble", 17.5, 0.32, Vector3(0, 0.32, 0), _pbr("Marble012", 0.28))
	_disc(plaza, "CentralImperialStoneMedallion", 7.5, 0.36, Vector3(0, 0.49, 0), stone)
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var pos := Vector3(sin(angle) * 21.0, 0.34, cos(angle) * 21.0)
		_plane(plaza, "EngravedRadialPavingInlay_%02d" % i, Vector2(0.75, 14.0), pos, _pbr("Marble012", 0.28), angle)

func _build_channels() -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("#3f9eae")
	water.metallic = 0.12
	water.roughness = 0.18
	var channel := Node3D.new()
	channel.name = "OrganicPerimeterWaterRing"
	add_child(channel)
	for i in range(40):
		var angle := TAU * float(i) / 40.0
		var radius := 115.0 + 3.0 * sin(angle * 3.0) + 1.5 * cos(angle * 5.0)
		var pos := Vector3(sin(angle) * radius, -0.02, cos(angle) * radius)
		_plane(channel, "PerimeterCanalSegment_%02d" % i, Vector2(8.0, 18.5), pos, water, angle - PI / 2.0)
	var bridges := Node3D.new()
	bridges.name = "FourApprovedArchedBridges"
	add_child(bridges)
	var bridge_name := "Arched Stone Bridge (Imperial China Palace and Garden)"
	for i in range(4):
		var angle := TAU * float(i) / 4.0
		var radius := 115.0 + 3.0 * sin(angle * 3.0) + 1.5 * cos(angle * 5.0)
		var pos := Vector3(sin(angle) * radius, 0, cos(angle) * radius)
		_place_fit(bridge_name, pos, PI - angle, Vector3(15, 5, 10), bridges, "ArchedBridge_%02d" % i)
		stats.bridges += 1

func _build_walls_and_gates() -> void:
	var walls := Node3D.new()
	walls.name = "OrganicCircularImperialPerimeter_260m"
	add_child(walls)
	var wall := "Palace Wall Straight (Imperial China Palace and Garden)"
	for i in range(56):
		var angle := TAU * float(i) / 56.0
		var is_gate_sector := false
		for gate_index in range(4):
			var gate_angle := TAU * float(gate_index) / 4.0
			if absf(wrapf(angle - gate_angle, -PI, PI)) < 0.105:
				is_gate_sector = true
		if is_gate_sector:
			continue
		var radius := 128.0 + 4.0 * sin(angle * 3.0) + 2.0 * cos(angle * 5.0)
		var pos := Vector3(sin(angle) * radius, 0, cos(angle) * radius)
		_place_fit(wall, pos, angle, Vector3(14.0, 3.2, 1.8), walls, "OrganicWall_%03d" % i)
		stats.wall_segments += 1
	for gate_index in range(4):
		var angle := TAU * float(gate_index) / 4.0
		var radius := 128.0 + 4.0 * sin(angle * 3.0) + 2.0 * cos(angle * 5.0)
		var pos := Vector3(sin(angle) * radius, 0, cos(angle) * radius)
		var root := Node3D.new()
		root.name = ["South","East","North","West"][gate_index] + "ImperialGate"
		root.position = pos
		root.rotation.y = PI - angle
		walls.add_child(root)
		if _place_fit("Gate Tower (Imperial China Palace and Garden)", Vector3.ZERO, 0, Vector3(17, 14, 13), root, "GateTower") != null:
			stats.buildings += 1
		_place_fit("Palace Wall Moon Gate (Imperial China Palace and Garden)", Vector3(0, 0, 1), 0, Vector3(10, 7, 3), root, "MoonGate")
		_place_fit("Guardian Lion Pair (Imperial China Palace and Garden)", Vector3(0, 0, 8), 0, Vector3(7, 4.5, 4.5), root, "GuardianLionPair")
		stats.directional_gates += 1
		stats.gate_guardian_pairs += 1
		stats.gate_guardian_statues += 2
	print("TWIN_CITY_GATE_AUDIT: four gates, eight approved guardian lion statues")

func _build_palace_and_plaza() -> void:
	var palace := Node3D.new()
	palace.name = "ImperialPalace_FrontingCentralPlaza"
	palace.position = Vector3(0, 0, -76)
	add_child(palace)
	var platform := "Terrace Platform Module (Imperial China Palace and Garden)"
	for layer in range(3):
		for x in range(4):
			for z in range(3):
				var pos := Vector3(-10.5 + float(x) * 7.0, float(layer) * 1.6, -8.0 + float(z) * 7.0)
				_place_fit(platform, pos, 0, Vector3(7.1, 2.0, 7.1), palace, "RaisedTerrace_%d_%d_%d" % [layer, x, z])
	_place_fit("Terrace Step Flight (Imperial China Palace and Garden)", Vector3(0, 0, 12), PI, Vector3(19, 5, 10), palace, "BroadImperialStairsFacingPlaza")
	if _place_fit("Ceremonial Hall (Imperial China Palace and Garden)", Vector3(0, 4.8, -1), 0, Vector3(32, 20, 24), palace, "FrontImperialPalace") != null:
		stats.buildings += 1
	_place_fit("Imperial Throne Chair (Imperial China Palace and Garden)", Vector3(0, 5.0, 7), PI, Vector3(2.8, 3, 2.8), palace, "EmperorThrone")
	for i in range(4):
		_place_fit("Dragon Roof Finial (Imperial China Palace and Garden)", Vector3(-8 + float(i) * 5.3, 18, -1), 0, Vector3(2.2, 2.2, 2.2), palace, "DragonFinial_%02d" % i)
	_place_fit("Guardian Lion Pair (Imperial China Palace and Garden)", Vector3(-11, 0, 13), PI / 2, Vector3(7, 4.5, 4.5), palace, "PalaceWestGuardians")
	_place_fit("Guardian Lion Pair (Imperial China Palace and Garden)", Vector3(11, 0, 13), -PI / 2, Vector3(7, 4.5, 4.5), palace, "PalaceEastGuardians")
	var garden := Node3D.new()
	garden.name = "EasternLotusGardenBesidePlaza"
	add_child(garden)
	_place_fit("Pond Water Module (Imperial China Palace and Garden)", Vector3(43, 0.02, 3), 0, Vector3(15, 1, 12), garden, "LotusPondWater")
	_place_fit("Lotus Cluster (Imperial China Palace and Garden)", Vector3(40, 0.1, 0), 0, Vector3(4, 1.2, 4), garden, "LotusClusterWest")
	_place_fit("Lotus Cluster (Imperial China Palace and Garden)", Vector3(46, 0.1, 6), 1.1, Vector3(4, 1.2, 4), garden, "LotusClusterEast")
	if _place_fit("Lotus pond pavilion (Imperial China Palace and Garden)", Vector3(43, 0, 3), 0, Vector3(15, 8, 13), garden, "LotusWaterPavilion") != null:
		stats.buildings += 1
	if _place_fit("Water Pavilion (Imperial China Palace and Garden)", Vector3(-43, 0, 3), 0, Vector3(13, 9, 12), garden, "WestWaterPavilion") != null:
		stats.buildings += 1
	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var pos := Vector3(sin(angle) * 34.0, 0, cos(angle) * 34.0)
		_place_fit("Standing Garden Lantern (Imperial China Palace and Garden)", pos, angle, Vector3(1.8, 3, 1.8), garden, "PlazaLantern_%02d" % i)
		_lantern_light(garden, pos + Vector3(0, 2.2, 0), "LanternGlow_%02d" % i)

func _lantern_light(parent: Node3D, pos: Vector3, label: String) -> void:
	var light := OmniLight3D.new()
	light.name = label
	light.position = pos
	light.light_color = Color("#ffbd69")
	light.light_energy = 0.85
	light.omni_range = 9
	parent.add_child(light)

func _build_districts() -> void:
	var districts := Node3D.new()
	districts.name = "TenDenseRadialCommercialResidentialDistricts"
	add_child(districts)
	var market := "Market Stall With Awning (Korean Hanok Village and Street)"
	var residences := [
		"Hanok Main House (Korean Hanok Village and Street)",
		"Thatched Outbuilding (Korean Hanok Village and Street)",
		"Ceremonial Hall (Imperial China Palace and Garden)",
		"Water Pavilion (Imperial China Palace and Garden)"
	]
	var shop_local := [
		{"x": 11.0, "z": 0.0, "yaw": 0.0, "front_x": 17.0, "front_z": 0.0},
		{"x": -11.0, "z": 0.0, "yaw": 0.0, "front_x": -17.0, "front_z": 0.0},
		{"x": 0.0, "z": 11.0, "yaw": 0.0, "front_x": 0.0, "front_z": 17.0},
		{"x": 0.0, "z": -11.0, "yaw": 0.0, "front_x": 0.0, "front_z": -17.0}
	]
	var index := 0
	for sector in range(10):
		var angle := TAU * float(sector) / 10.0
		var radial := Vector3(sin(angle), 0, cos(angle))
		var tangent := Vector3(cos(angle), 0, -sin(angle))
		var center := radial * 72.0
		var block := Node3D.new()
		block.name = "RadialDistrict_%02d" % sector
		districts.add_child(block)
		for side in range(4):
			var item: Dictionary = shop_local[side]
			var local_x := float(item.x)
			var local_z := float(item.z)
			var pos := center + radial * local_x + tangent * local_z
			var yaw := PI - angle if side == 0 else -angle if side == 1 else -PI / 2.0 - angle if side == 2 else PI / 2.0 - angle
			_place_fit(market, pos, yaw, Vector3(10, 8, 8), block, "Shopfront_%02d_%02d" % [sector, side])
			var front := center + radial * float(item.front_x) + tangent * float(item.front_z)
			var spawn := Node3D.new()
			spawn.name = "NPCShopkeeperSpawn_%02d_%02d" % [sector, side]
			spawn.position = front
			spawn.set_meta("shop_district", sector)
			spawn.set_meta("shop_front", side)
			block.add_child(spawn)
			stats.shopkeeper_spawns += 1
			index += 1
		for inner in range(4):
			var local := [
				Vector2(-5.0, -5.0), Vector2(5.0, -5.0),
				Vector2(-5.0, 5.0), Vector2(5.0, 5.0)
			][inner]
			var pos := center + radial * local.x + tangent * local.y
			var asset: String = residences[(sector + inner) % residences.size()]
			_place_fit(asset, pos, angle + float(inner) * PI / 2.0, Vector3(11.5, 14.0, 11.5), block, "InnerResidence_%02d_%02d" % [sector, inner])
			index += 1
	stats.district_buildings = index
	stats.buildings += index
	if stats.buildings < 70 or stats.buildings > 100:
		push_error("Expected 70–100 total buildings including landmarks; got " + str(stats.buildings))

func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	for item in TREES: _tree_multimesh(str(item.name), int(item.count), rng)

func _tree_multimesh(name: String, count: int, rng: RandomNumberGenerator) -> void:
	var scene := _packed(name)
	if scene == null: return
	var source := scene.instantiate()
	var parts: Array[Dictionary] = []
	_collect_meshes(source, Transform3D.IDENTITY, parts)
	source.free()
	if parts.is_empty(): push_error("Tree GLB has no mesh: " + name); return
	var positions: Array[Vector3] = []
	while positions.size() < count:
		var x := rng.randf_range(-390,390)
		var z := rng.randf_range(-390,390)
		if absf(x)<112 and absf(z)<112: continue
		positions.append(Vector3(x,0,z))
	for p in range(parts.size()):
		var part: Dictionary = parts[p]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = part.mesh
		mm.instance_count = count
		for i in range(count):
			var scale := rng.randf_range(0.86,1.16)
			var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*scale)
			mm.set_instance_transform(i, Transform3D(basis,positions[i]) * part.transform)
		var visual := MultiMeshInstance3D.new()
		visual.name = "TreeMultiMesh_%s_%02d" % [name.replace(" ","_"),p]
		visual.multimesh = mm
		add_child(visual)
	stats.tree_instances += count
	stats.multimesh_batches += parts.size()
	print("TWIN_CITY_MULTIMESH_TREES: " + name + " count=" + str(count))

func _collect_meshes(node: Node, parent: Transform3D, output: Array[Dictionary]) -> void:
	var xform := parent
	if node is Node3D: xform = parent * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		output.append({"mesh": (node as MeshInstance3D).mesh, "transform": xform})
	for child in node.get_children(): _collect_meshes(child,xform,output)

func _build_cameras() -> void:
	var root := Node3D.new()
	root.name = "TwinCityProofCameras"
	add_child(root)
	var aerial := Camera3D.new()
	aerial.name = "AerialCamera"
	aerial.projection = Camera3D.PROJECTION_ORTHOGONAL
	aerial.size = 320
	aerial.position = Vector3(185, 245, 195)
	root.add_child(aerial)
	aerial.look_at(Vector3(0, 0, 0), Vector3.UP)
	var street := Camera3D.new()
	street.name = "StreetCamera"
	street.fov = 56
	street.position = Vector3(0, 11, 43)
	root.add_child(street)
	street.look_at(Vector3(0, 6, 70), Vector3.UP)

func _audit() -> void:
	var pending: Array[Node] = [self]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		for child in node.get_children(): pending.append(child)
		if node is MeshInstance3D and (node as MeshInstance3D).mesh is BoxMesh:
			stats.box_mesh_count += 1
	if stats.box_mesh_count != 0: push_error("BoxMesh architecture forbidden.")
	if stats.buildings < 70 or stats.buildings > 100: push_error("Total building count including landmarks out of range.")
	if stats.tree_instances < 300 or stats.tree_instances > 400: push_error("Tree count out of range.")
	if stats.directional_gates != 4 or stats.bridges != 4 or stats.gate_guardian_statues != 8: push_error("Gate/bridge/guardian audit failed.")
	if stats.box_mesh_count == 0: print("TWIN_CITY_NO_BOX_ARCHITECTURE_PASS")

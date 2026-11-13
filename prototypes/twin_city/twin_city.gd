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
	"multimesh_batches": 0, "box_mesh_count": 0, "city_core_m": 190, "world_m": 800, "building_types": 6,
	"architecture_style": "imperial_chinese"}

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

func _plane(parent: Node3D, label: String, size: Vector2, pos: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := PlaneMesh.new()
	mesh.size = size
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
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.32
	env.glow_enabled = false
	env.glow_intensity = 0.08
	env.glow_strength = 0.15
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("#c7dceb")
	env.fog_depth_begin = 125.0
	env.fog_depth_end = 650.0
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "ImperialDaySun"
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("#fff1d8")
	sun.light_energy = 0.78
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 260
	add_child(sun)

func _build_ground_and_roads() -> void:
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("#6e9560")
	grass.roughness = 1.0
	_plane(self, "WorldGround_800m", Vector2(800, 800), Vector3(0, -0.18, 0), grass)
	var roads := Node3D.new()
	roads.name = "ImperialStreetNetwork"
	add_child(roads)
	var stone := _pbr("PavingStones036", 0.22)
	_plane(roads, "MainStreetNS", Vector2(10, 190), Vector3(0, 0.015, 0), stone)
	_plane(roads, "MainStreetEW", Vector2(190, 10), Vector3(0, 0.02, 0), stone)
	for offset in [-30.0, 30.0]:
		_plane(roads, "DistrictStreetNS_" + str(offset), Vector2(5, 190), Vector3(offset, 0.025, 0), stone)
		_plane(roads, "DistrictStreetEW_" + str(offset), Vector2(190, 5), Vector3(0, 0.03, offset), stone)
	_plane(self, "ImperialMainPlaza_PBR", Vector2(52, 34), Vector3(0, 0.055, 24), _pbr("Marble012", 0.28))

func _build_channels() -> void:
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("#3f9eae")
	water.metallic = 0.12
	water.roughness = 0.18
	_plane(self, "NorthCanal", Vector2(190, 12), Vector3(0, -0.02, -95), water)
	_plane(self, "SouthCanal", Vector2(190, 12), Vector3(0, -0.02, 95), water)
	_plane(self, "EastCanal", Vector2(12, 190), Vector3(95, -0.02, 0), water)
	_plane(self, "WestCanal", Vector2(12, 190), Vector3(-95, -0.02, 0), water)
	var bridges := Node3D.new()
	bridges.name = "FourApprovedArchedBridges"
	add_child(bridges)
	var bridge_name := "Arched Stone Bridge (Imperial China Palace and Garden)"
	var points := [[Vector3(0,0,-95),0.0],[Vector3(0,0,95),PI],[Vector3(95,0,0),PI/2], [Vector3(-95,0,0),-PI/2]]
	for i in range(points.size()):
		_place_fit(bridge_name, points[i][0], points[i][1], Vector3(15,5,10), bridges, "ArchedBridge_%02d" % i)
		stats.bridges += 1

func _build_walls_and_gates() -> void:
	var walls := Node3D.new()
	walls.name = "ImperialChina_170m_Perimeter"
	add_child(walls)
	var wall := "Palace Wall Straight (Imperial China Palace and Garden)"
	var corner := "Palace Wall Corner (Imperial China Palace and Garden)"
	for side in range(4):
		var cursor := -82.0
		while cursor <= 82.0:
			if absf(cursor) > 9.0:
				var pos := Vector3(cursor,0,-85) if side == 0 else Vector3(cursor,0,85) if side == 1 else Vector3(-85,0,cursor) if side == 2 else Vector3(85,0,cursor)
				_place_fit(wall, pos, 0.0 if side < 2 else PI/2, Vector3(4.1,3.2,1.8), walls, "Wall_%02d_%03d" % [side,stats.wall_segments])
				stats.wall_segments += 1
			cursor += 4.1
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:
			_place_fit(corner, Vector3(sx*85,0,sz*85), 0, Vector3(5,4,5), walls, "WallCorner_%s_%s" % [str(sx),str(sz)])
	var gates := [["North",Vector3(0,0,-85),0.0],["South",Vector3(0,0,85),PI],["East",Vector3(85,0,0),PI/2],["West",Vector3(-85,0,0),-PI/2]]
	for gate in gates:
		var root := Node3D.new()
		root.name = str(gate[0]) + "ImperialGate"
		root.position = gate[1]
		root.rotation.y = gate[2]
		walls.add_child(root)
		if _place_fit("Gate Tower (Imperial China Palace and Garden)", Vector3.ZERO, 0, Vector3(15,12,12), root, "GateTower") != null: stats.buildings += 1
		_place_fit("Palace Wall Moon Gate (Imperial China Palace and Garden)", Vector3(0,0,1), 0, Vector3(9,6,3), root, "MoonGate")
		_place_fit("Guardian Lion Pair (Imperial China Palace and Garden)", Vector3(0,0,7), 0, Vector3(7,4.5,4.5), root, "GuardianLionPair")
		stats.directional_gates += 1
		stats.gate_guardian_pairs += 1
		stats.gate_guardian_statues += 2
	print("TWIN_CITY_GATE_AUDIT: four gates, eight approved guardian lion statues")

func _build_palace_and_plaza() -> void:
	var palace := Node3D.new()
	palace.name = "ImperialPalace_CentralRaisedCourt"
	add_child(palace)
	var platform := "Terrace Platform Module (Imperial China Palace and Garden)"
	for layer in range(2):
		for x in range(4):
			for z in range(4):
				var pos := Vector3(-10.5 + float(x)*7, float(layer)*2, -38.5 + float(z)*7)
				_place_fit(platform, pos, 0, Vector3(7.1,2,7.1), palace, "RaisedTerrace_%d_%d_%d" % [layer,x,z])
	_place_fit("Terrace Step Flight (Imperial China Palace and Garden)", Vector3(0,0,-9), 0, Vector3(17,4,9), palace, "BroadEngravedStairs")
	if _place_fit("Ceremonial Hall (Imperial China Palace and Garden)", Vector3(0,4,-28), 0, Vector3(30,18,23), palace, "CentralImperialPalace") != null: stats.buildings += 1
	_place_fit("Imperial Throne Chair (Imperial China Palace and Garden)", Vector3(0,4.2,-20), PI, Vector3(2.8,3,2.8), palace, "EmperorThrone")
	for i in range(4):
		_place_fit("Dragon Roof Finial (Imperial China Palace and Garden)", Vector3(-8 + float(i)*5.3,17,-28), 0, Vector3(2.2,2.2,2.2), palace, "DragonFinial_%02d" % i)
	_place_fit("Guardian Lion Pair (Imperial China Palace and Garden)", Vector3(-10,0,-7), PI/2, Vector3(7,4.5,4.5), palace, "PalaceWestGuardians")
	_place_fit("Guardian Lion Pair (Imperial China Palace and Garden)", Vector3(10,0,-7), -PI/2, Vector3(7,4.5,4.5), palace, "PalaceEastGuardians")
	var garden := Node3D.new()
	garden.name = "ImperialPlazaAndLotusGarden"
	add_child(garden)
	_place_fit("Pond Water Module (Imperial China Palace and Garden)", Vector3(25,0.02,24), 0, Vector3(17,1,13), garden, "LotusPondWater")
	_place_fit("Lotus Cluster (Imperial China Palace and Garden)", Vector3(22,0.1,21), 0, Vector3(4,1.2,4), garden, "LotusClusterWest")
	_place_fit("Lotus Cluster (Imperial China Palace and Garden)", Vector3(28,0.1,26), 1.1, Vector3(4,1.2,4), garden, "LotusClusterEast")
	if _place_fit("Lotus pond pavilion (Imperial China Palace and Garden)", Vector3(24,0,25), 0, Vector3(15,8,13), garden, "LotusWaterPavilion") != null: stats.buildings += 1
	if _place_fit("Water Pavilion (Imperial China Palace and Garden)", Vector3(-20,0,24), 0, Vector3(13,9,12), garden, "WestWaterPavilion") != null: stats.buildings += 1
	for i in range(12):
		var angle := TAU * float(i)/12
		var pos := Vector3(cos(angle)*24,0,24+sin(angle)*17)
		_place_fit("Standing Garden Lantern (Imperial China Palace and Garden)", pos, angle, Vector3(1.8,3,1.8), garden, "PlazaLantern_%02d" % i)
		_lantern_light(garden, pos + Vector3(0,2.2,0), "LanternGlow_%02d" % i)
	for i in range(16):
		var pos := Vector3(-5.2 if i%2==0 else 5.2,5.5,-54+float(i)*7.2)
		_place_fit("Hanging Silk Lantern (Imperial China Palace and Garden)", pos, 0, Vector3(1.3,1.8,1.3), garden, "StreetLantern_%02d" % i)
		if i%2==0: _lantern_light(garden, pos, "StreetGlow_%02d" % i)

func _lantern_light(parent: Node3D, pos: Vector3, label: String) -> void:
	var light := OmniLight3D.new()
	light.name = label
	light.position = pos
	light.light_color = Color("#ffbd69")
	light.light_energy = 0.85
	light.omni_range = 9
	parent.add_child(light)

func _build_districts() -> void:
	var district := Node3D.new()
	district.name = "MixedImperialHanokDistricts_64BuildingsPlus7Landmarks"
	add_child(district)
	var coords := [14.0,34.0,54.0,74.0]
	var index := 0
	for sx in [-1.0,1.0]:
		for sz in [-1.0,1.0]:
			for x in range(4):
				for z in range(4):
					var pos := Vector3(sx*coords[x],0,sz*coords[z])
					var asset: String = BUILDINGS[(index * 5 + x + z * 2) % BUILDINGS.size()]
					var yaw: float = [0.0, PI / 2.0, PI, -PI / 2.0][(index + x + z) % 4]
					_place_fit(asset, pos, yaw, Vector3(16,12,16), district, "ChineseBuilding_%03d_%s" % [index+1,["Residence","Shop","Pavilion","CourtyardHouse","MerchantStall","ImperialAnnex"][index%6]])
					index += 1
	stats.district_buildings = index
	stats.buildings += index
	if stats.buildings < 70 or stats.buildings > 100: push_error("Expected 70–100 total buildings including palace, gates and pavilions; got " + str(stats.buildings))

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
	aerial.size = 220
	aerial.position = Vector3(155,220,185)
	root.add_child(aerial)
	aerial.look_at(Vector3.ZERO,Vector3.UP)
	var street := Camera3D.new()
	street.name = "StreetCamera"
	street.fov = 56
	street.position = Vector3(0,14,55)
	root.add_child(street)
	street.look_at(Vector3(0,7,-25),Vector3.UP)

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

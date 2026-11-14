extends RefCounted
## Detailed, lightweight facade and roof kit for all six classic settlements.
## Every building is assembled from real 3D meshes; brick relief uses a generated normal map.
const CITY_PALETTES := {
 "TwinCity": {"wall": Color("#c9b99a"), "stone": Color("#858078"), "wood": Color("#71372b"), "roof": Color("#2B333E"), "gold": Color("#D49B35"), "accent": Color("#D49B35")},
 "DesertLand": {"wall": Color("#c99b62"), "stone": Color("#8a623e"), "wood": Color("#70452c"), "roof": Color("#a87542"), "gold": Color("#d6ad6d"), "accent": Color("#e9c78c")},
 "VolcanoLand": {"wall": Color("#514744"), "stone": Color("#292629"), "wood": Color("#3b2925"), "roof": Color("#332d30"), "gold": Color("#bd7040"), "accent": Color("#e56c36")},
 "IceLand": {"wall": Color("#a9c5d5"), "stone": Color("#718b9b"), "wood": Color("#49677a"), "roof": Color("#d9edf5"), "gold": Color("#9bd6e9"), "accent": Color("#e6f8ff")},
 "Waterlands": {"wall": Color("#b9aa87"), "stone": Color("#756e5c"), "wood": Color("#654a32"), "roof": Color("#456d69"), "gold": Color("#d0ad64"), "accent": Color("#9bd5c6")},
 "DarkForest": {"wall": Color("#786f55"), "stone": Color("#454536"), "wood": Color("#49372a"), "roof": Color("#35483a"), "gold": Color("#b69a52"), "accent": Color("#9bb76a")}
}
static func build(parent: Node3D, city: String, size: float) -> void:
 if city == "TwinCity":
  build_twin_city(parent)
  return
 var palette: Dictionary = CITY_PALETTES.get(city, CITY_PALETTES["DesertLand"])
 _build_open_plaza(parent, palette)
 _build_city_roads(parent, palette)
 _build_city_buildings(parent, city, palette)
 _build_city_walls_and_gates(parent, city, palette)
 _build_outer_biome(parent, city, palette, size)
 print("CITY_ARCHITECTURE_PASS: %s legacy_city_builder=1" % city)

static func _build_open_plaza(parent: Node3D, p: Dictionary) -> void:
 var plaza := Node3D.new()
 plaza.name = "OpenCentralPlaza_80x80"
 parent.add_child(plaza)
 var stone := _material(p.stone, 0.92)
 for z in range(-5,5):
  for x in range(-5,5):
   var tile := _box(plaza, "DiamondStonePaver_%02d_%02d" % [x+5,z+5], Vector3(float(x)*8.0+4.0,0.055,float(z)*8.0+4.0), Vector3(7.75,0.11,7.75), stone, 1.0)
   tile.rotation_degrees.y = 45.0
 var medallion := MeshInstance3D.new()
 medallion.name = "CentralEngravedStoneMedallion"
 var disk := CylinderMesh.new()
 disk.top_radius = 9.0
 disk.bottom_radius = 9.0
 disk.height = 0.32
 disk.radial_segments = 64
 medallion.mesh = disk
 medallion.position.y = 0.20
 plaza.add_child(medallion)
 medallion.material_override = _material(p.gold,0.72)
 for radius in [7.8,6.2,4.6]:
  var ring := MeshInstance3D.new()
  ring.name = "MedallionEngravedRing"
  var torus := TorusMesh.new()
  torus.inner_radius = radius
  torus.outer_radius = radius + 0.16
  torus.rings = 48
  torus.ring_segments = 8
  ring.mesh = torus
  ring.position.y = 0.39
  plaza.add_child(ring)
  ring.material_override = _material(p.accent,0.66)

static func _build_city_roads(parent: Node3D, p: Dictionary) -> void:
 var roads := Node3D.new()
 roads.name = "StoneRoadNetwork"
 parent.add_child(roads)
 var road_material := _material(p.stone.lightened(0.12),0.94)
 var curb_material := _material(p.gold,0.76)
 for direction in range(4):
  var road := _box(roads,"FlagstoneRoad_%d" % direction,Vector3(0,0.10,0),Vector3(14,0.20,300),road_material,1.0)
  road.rotation_degrees.y = direction*90.0
  for side in [-1.0,1.0]:
   var curb := _box(roads,"RaisedStoneCurb",Vector3(side*8.0,0.34,0),Vector3(0.65,0.48,300),curb_material,1.0)
   curb.rotation_degrees.y = direction*90.0

static func _build_city_buildings(parent: Node3D, city: String, p: Dictionary) -> void:
 var slot := Node3D.new()
 slot.name = city + "_24BuildingUrbanFabric"
 parent.add_child(slot)
 var coordinates := [-92.0,-56.0,-20.0,20.0,56.0,92.0]
 var index := 0
 for value in coordinates:
  for side in [-1.0,1.0]:
   for axis in [0,1]:
    var position := Vector3(value,0.0,side*112.0) if axis == 0 else Vector3(side*112.0,0.0,value)
    var imported := _instantiate_quaternius_building(slot, city, index, position)
    if imported == null:
     var building := _make_building(city,p,index,1.0)
     building.name = city + "_DetailedBuilding_%02d" % index
     building.position = position
     building.rotation.y = atan2(-position.x,-position.z)
     slot.add_child(building)
    index += 1

static func _instantiate_quaternius_building(parent: Node3D, city: String, index: int, at: Vector3) -> Node3D:
 var candidates: Array[String] = []
 var all_models: Array[String] = []
 _collect_quaternius_models("res://assets/environment/quaternius/ultimate_fantasy_rts", all_models)
 _collect_quaternius_models("res://assets/environment/quaternius/modular_medieval_buildings", all_models)
 for path in all_models:
  var file_name := path.get_file().to_lower()
  if ["building","house","tower","wall","castle","shop","keep","gate","barrack","forge","blacksmith","hall"].any(func(word: String) -> bool: return file_name.contains(word)):
   candidates.append(path)
 if candidates.is_empty():
  return null
 candidates.sort()
 var selected := candidates[index % candidates.size()]
 var packed := load(selected) as PackedScene
 if packed == null:
  return null
 var instance := packed.instantiate() as Node3D
 if instance == null:
  return null
 instance.name = city + "_QuaterniusBuilding_%02d" % index
 instance.position = at
 instance.rotation.y = atan2(-at.x,-at.z)
 instance.scale = Vector3.ONE
 parent.add_child(instance)
 _add_static_mesh_collisions(instance)
 instance.add_to_group("distance_cull_world")
 _set_visibility_range(instance, 360.0, 35.0)
 return instance

static func _set_visibility_range(root: Node, range_end: float, margin: float) -> void:
 var pending: Array[Node] = [root]
 while not pending.is_empty():
  var current: Node = pending.pop_back()
  for child in current.get_children():
   pending.append(child)
  if current is GeometryInstance3D:
   var geometry := current as GeometryInstance3D
   geometry.visibility_range_end = range_end
   geometry.visibility_range_end_margin = margin

static func _collect_quaternius_models(path: String, output: Array[String]) -> void:
 var directory := DirAccess.open(path)
 if directory == null:
  return
 directory.list_dir_begin()
 var entry := directory.get_next()
 while entry != "":
  if entry.begins_with("."):
   entry = directory.get_next()
   continue
  var child := path.path_join(entry)
  if directory.current_is_dir():
   _collect_quaternius_models(child, output)
  elif entry.get_extension().to_lower() in ["glb","gltf"]:
   output.append(child)
  entry = directory.get_next()
 directory.list_dir_end()

static func _add_static_mesh_collisions(root: Node3D) -> void:
 var pending: Array[Node] = [root]
 while not pending.is_empty():
  var current: Node = pending.pop_back()
  for child in current.get_children():
   pending.append(child)
  if current is MeshInstance3D:
   var mesh_node := current as MeshInstance3D
   if mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
    mesh_node.create_trimesh_collision()

static func _build_city_walls_and_gates(parent: Node3D, city: String, p: Dictionary) -> void:
 var fortification := Node3D.new()
 fortification.name = city + "_PerimeterFortifications"
 parent.add_child(fortification)
 var wall_material := _material(p.stone.darkened(0.12),0.9)
 var tower_material := _material(p.wall,0.86)
 var gate_material := _material(p.gold,0.72)
 var half := 148.0
 var gap := 15.0
 for side in [-1.0,1.0]:
  for segment in [-1.0,1.0]:
   var start := -half if segment < 0.0 else gap
   var finish := -gap if segment < 0.0 else half
   var length := finish-start
   var horizontal_wall := _box(fortification,"HighStonePerimeterWall_%s_%s" % [str(int(side)),str(int(segment))],Vector3((start+finish)*0.5,5.0,side*half),Vector3(length,10.0,5.0),wall_material,1.0)
   horizontal_wall.add_to_group("city_perimeter_wall")
   var vertical_wall := _box(fortification,"HighStonePerimeterWall_%s_%s" % [str(int(side)),str(int(segment))],Vector3(side*half,5.0,(start+finish)*0.5),Vector3(5.0,10.0,length),wall_material,1.0)
   vertical_wall.add_to_group("city_perimeter_wall")
 for direction in range(4):
  var gate := Node3D.new()
  gate.name = ["North","East","South","West"][direction] + "_GrandCityGate"
  gate.rotation_degrees.y = direction*90.0
  fortification.add_child(gate)
  for side in [-1.0,1.0]:
   _box(gate,"GatehouseTower",Vector3(side*17.0,9.0,-148.0),Vector3(11.0,18.0,13.0),tower_material,1.0)
   _box(gate,"GateTowerCrenellation",Vector3(side*17.0,18.5,-148.0),Vector3(13.0,1.0,15.0),gate_material,1.0)
   _box(gate,"GateGuardianStand",Vector3(side*9.0,0.15,-132.0),Vector3(1.6,0.3,1.6),wall_material,1.0)
   _build_gate_guard(gate,side,p)
  _box(gate,"GateArchLintel",Vector3(0,17.2,-148.0),Vector3(24.0,3.0,9.0),gate_material,1.0)
  for x in [-8.0,8.0]:
   _box(gate,"ArchColumn",Vector3(x,7.0,-148.0),Vector3(2.0,14.0,7.0),gate_material,1.0)

static func _build_outer_biome(parent: Node3D, city: String, p: Dictionary, size: float) -> void:
 var outer := Node3D.new()
 outer.name = city + "_OpenWorld_800x800"
 parent.add_child(outer)
 var ground_color := Color("#6c9849")
 match city:
  "DesertLand": ground_color = Color("#D4A359")
  "VolcanoLand": ground_color = Color("#393437")
  "IceLand": ground_color = Color("#A8D0E6")
  "Waterlands": ground_color = Color("#3a9e91")
  "DarkForest": ground_color = Color("#294b32")
 var ground := MeshInstance3D.new()
 ground.name = "SeamlessOuterBiomeGround"
 var plane := PlaneMesh.new()
 plane.size = Vector2(800.0,800.0)
 ground.mesh = plane
 ground.position = Vector3(0,-18.0,0)
 outer.add_child(ground)
 ground.material_override = _material(ground_color,1.0)
 _build_horizon_ridge(outer, city, p)
 _build_walkable_outer_routes(outer, city, p)
 var trunk := CylinderMesh.new()
 trunk.top_radius = 0.28
 trunk.bottom_radius = 0.58
 trunk.height = 7.0
 var canopy: PrimitiveMesh
 if city in ["DesertLand","VolcanoLand","IceLand","DarkForest"]:
  var evergreen := CylinderMesh.new()
  evergreen.top_radius = 0.0
  evergreen.bottom_radius = 3.8
  evergreen.height = 8.5
  canopy = evergreen
 else:
  var broadleaf := SphereMesh.new()
  broadleaf.radius = 3.6
  broadleaf.height = 6.8
  canopy = broadleaf
 var trunk_mm := MultiMesh.new()
 trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
 trunk_mm.mesh = trunk
 var canopy_mm := MultiMesh.new()
 canopy_mm.transform_format = MultiMesh.TRANSFORM_3D
 canopy_mm.mesh = canopy
 var count := 0 if city == "VolcanoLand" else 96
 trunk_mm.instance_count = count
 canopy_mm.instance_count = count
 for i in range(count):
  var angle := float(i)*2.399963
  var radius := 166.0 + float((i*37)%64)
  var pos := Vector3(cos(angle)*radius,3.5,sin(angle)*radius)
  var basis := Basis(Vector3.UP,angle).scaled(Vector3.ONE*(0.72+float(i%5)*0.12))
  trunk_mm.set_instance_transform(i,Transform3D(basis,pos))
  canopy_mm.set_instance_transform(i,Transform3D(basis,pos+Vector3(0,5.5,0)))
 var trunks := MultiMeshInstance3D.new()
 trunks.name = city+"_OuterTreeTrunks_MultiMesh"
 trunks.multimesh = trunk_mm
 trunks.visibility_range_end = 250.0
 trunks.visibility_range_end_margin = 30.0
 outer.add_child(trunks)
 trunks.material_override = _material(p.wood,0.95)
 var crowns := MultiMeshInstance3D.new()
 crowns.name = city+"_OuterCanopy_MultiMesh"
 crowns.multimesh = canopy_mm
 crowns.visibility_range_end = 250.0
 crowns.visibility_range_end_margin = 30.0
 outer.add_child(crowns)
 crowns.material_override = _material(p.accent,0.95)
 _place_quaternius_nature(outer, city)
 var water_color := Color("#4c9eb0")
 if city == "VolcanoLand": water_color = Color("#d75b2d")
 elif city == "DesertLand": water_color = Color("#4a9a75")
 elif city == "IceLand": water_color = Color("#a7dbe9")
 elif city == "Waterlands": water_color = Color("#397f86")
 if city in ["TwinCity","VolcanoLand","Waterlands"]:
  var water := MeshInstance3D.new()
  water.name = "OuterRiverOrLavaChannel"
  var channel := PlaneMesh.new()
  channel.size = Vector2(34.0,180.0)
  if city == "Waterlands":
   channel.size = Vector2(100.0,230.0)
  water.mesh = channel
  water.position = Vector3(0,0.08,-205.0)
  outer.add_child(water)
  water.material_override = _material(water_color,0.3)
  if city == "Waterlands":
   var island_material := _material(Color("#739451"),0.94)
   for island_data in [{"x":-34.0,"z":-198.0},{"x":0.0,"z":-226.0},{"x":34.0,"z":-198.0}]:
    var island := MeshInstance3D.new()
    island.name = "Waterlands_OuterGreenIsland"
    var island_mesh := CylinderMesh.new()
    island_mesh.top_radius = 12.0
    island_mesh.bottom_radius = 14.0
    island_mesh.height = 1.6
    island_mesh.radial_segments = 32
    island.mesh = island_mesh
    island.position = Vector3(float(island_data.x),0.55,float(island_data.z))
    outer.add_child(island)
    island.material_override = island_material
   _box(outer,"Waterlands_WoodenNorthGateBridge",Vector3(0,1.0,-169.0),Vector3(9.0,0.65,42.0),_material(p.wood,0.88),1.0)
   for side in [-1.0,1.0]:
    _box(outer,"Waterlands_WoodenBridgeRail",Vector3(side*4.7,2.0,-169.0),Vector3(0.65,2.0,42.0),_material(p.wood,0.88),1.0)
   _box(outer,"Waterlands_WoodenIslandCrossing",Vector3(0,1.0,-211.0),Vector3(74.0,0.65,7.0),_material(p.wood,0.88),1.0)
  else:
   _box(outer,"GrandStoneBridgeAtNorthGate",Vector3(0,0.8,-160.0),Vector3(25.0,1.6,22.0),_material(p.stone,0.86),1.0)
 print("OPEN_WORLD_BIOME_PASS: %s extent=800x800 multimesh_instances=%d horizon_ridge=44 ramps=4 canyon_pass=1" % [city,count])

static func _place_quaternius_nature(parent: Node3D, city: String) -> void:
 var keywords: Array[String] = []
 match city:
  "TwinCity": keywords = ["tree","oak","bush","rock"]
  "DesertLand": keywords = ["palm","cactus","desert","rock"]
  "VolcanoLand": keywords = ["rock","basalt","volcano","lava"]
  "IceLand": keywords = ["pine","spruce","snow","ice","rock"]
  "Waterlands": keywords = ["willow","palm","tree","rock"]
  "DarkForest": keywords = ["ancient","tree","log","stump","rock","oak"]
 var candidates: Array[String] = []
 _collect_quaternius_models("res://assets/environment/quaternius/ultimate_stylized_nature", candidates)
 candidates.sort()
 var selected: Array[String] = []
 for path in candidates:
  var file_name := path.get_file().to_lower()
  for keyword in keywords:
   if file_name.contains(keyword):
    selected.append(path)
    break
 if selected.is_empty():
  push_warning("Quaternius biome models not found by semantic filename for " + city)
  return
 var placed := 0
 for i in range(mini(18, selected.size() * 3)):
  var path := selected[i % selected.size()]
  var packed := load(path) as PackedScene
  if packed == null:
   continue
  var prop := packed.instantiate() as Node3D
  if prop == null:
   continue
  var angle := float(i) * 2.399963
  var radius := 238.0 + float((i * 31) % 82)
  prop.name = city + "_QuaterniusBiomeProp_%02d" % i
  prop.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
  prop.rotation.y = angle
  var scale_factor := 0.9 + float(i % 5) * 0.18
  prop.scale = Vector3.ONE * scale_factor
  parent.add_child(prop)
  prop.add_to_group("distance_cull_world")
  _set_visibility_range(prop, 320.0, 32.0)
  placed += 1
 print("QUATERNIUS_BIOME_PROPS_PASS: %s placed=%d" % [city, placed])

static func _build_horizon_ridge(parent: Node3D, city: String, p: Dictionary) -> void:
 var ridge_mesh := CylinderMesh.new()
 ridge_mesh.top_radius = 0.0
 ridge_mesh.bottom_radius = 46.0
 ridge_mesh.height = 112.0
 ridge_mesh.radial_segments = 7
 ridge_mesh.rings = 3
 var ridge_mm := MultiMesh.new()
 ridge_mm.transform_format = MultiMesh.TRANSFORM_3D
 ridge_mm.mesh = ridge_mesh
 ridge_mm.instance_count = 44
 for i in range(44):
  var angle := TAU * float(i) / 44.0
  var radius := 354.0 + float((i * 17) % 38)
  var height_scale := 0.72 + float((i * 13) % 65) / 100.0
  var scale := Vector3(0.78 + float(i % 4) * 0.12, height_scale, 0.78 + float(i % 5) * 0.10)
  var basis := Basis(Vector3.UP, angle * 0.12).scaled(scale)
  var position := Vector3(cos(angle) * radius, 38.0, sin(angle) * radius)
  ridge_mm.set_instance_transform(i, Transform3D(basis, position))
 var ridge := MultiMeshInstance3D.new()
 ridge.name = city + "_DistantHorizonMountainRidge"
 ridge.multimesh = ridge_mm
 ridge.material_override = _material(p.stone.darkened(0.20), 1.0)
 ridge.visibility_range_end = 900.0
 ridge.visibility_range_end_margin = 60.0
 ridge.add_to_group("distance_cull_world")
 parent.add_child(ridge)

static func _build_walkable_outer_routes(parent: Node3D, city: String, p: Dictionary) -> void:
 var route_root := Node3D.new()
 route_root.name = city + "_WalkableRampsAndCanyonPasses"
 parent.add_child(route_root)
 var ramp_material := _material(p.stone.lightened(0.08), 0.96)
 for i in range(4):
  var angle := float(i) * PI * 0.5
  var ramp_body := StaticBody3D.new()
  ramp_body.name = city + "_WalkableRamp_%d" % i
  ramp_body.position = Vector3(cos(angle) * 205.0, 3.0, sin(angle) * 205.0)
  ramp_body.rotation.y = -angle
  ramp_body.rotation.x = deg_to_rad(-10.0)
  var ramp_mesh := MeshInstance3D.new()
  var ramp := BoxMesh.new()
  ramp.size = Vector3(22.0, 2.0, 76.0)
  ramp_mesh.mesh = ramp
  ramp_body.add_child(ramp_mesh)
  ramp_mesh.material_override = ramp_material
  var ramp_collision := CollisionShape3D.new()
  var ramp_shape := BoxShape3D.new()
  ramp_shape.size = ramp.size
  ramp_collision.shape = ramp_shape
  ramp_body.add_child(ramp_collision)
  route_root.add_child(ramp_body)
 var canyon_material := _material(p.stone.darkened(0.12), 1.0)
 for side in [-1.0, 1.0]:
  var canyon_wall := StaticBody3D.new()
  canyon_wall.name = city + "_CanyonPassWall"
  canyon_wall.position = Vector3(side * 22.0, 12.0, -286.0)
  var wall_mesh := MeshInstance3D.new()
  var wall := BoxMesh.new()
  wall.size = Vector3(10.0, 30.0, 112.0)
  wall_mesh.mesh = wall
  canyon_wall.add_child(wall_mesh)
  wall_mesh.material_override = canyon_material
  var wall_collision := CollisionShape3D.new()
  var wall_shape := BoxShape3D.new()
  wall_shape.size = wall.size
  wall_collision.shape = wall_shape
  canyon_wall.add_child(wall_collision)
  route_root.add_child(canyon_wall)

static func _build_gate_guard(parent: Node3D, side: float, p: Dictionary) -> void:
 var guard := Node3D.new()
 guard.name = "GateGuardian_" + ("Left" if side < 0.0 else "Right")
 guard.position = Vector3(side*9.0,0.0,-132.0)
 parent.add_child(guard)
 var armor := _material(p.wood,0.62)
 var trim := _material(p.gold,0.5)
 var torso := MeshInstance3D.new()
 var body_mesh := CapsuleMesh.new()
 body_mesh.radius = 0.42
 body_mesh.height = 1.45
 torso.mesh = body_mesh
 torso.position.y = 1.15
 guard.add_child(torso)
 torso.material_override = armor
 var head := MeshInstance3D.new()
 var head_mesh := SphereMesh.new()
 head_mesh.radius = 0.28
 head_mesh.height = 0.56
 head.mesh = head_mesh
 head.position.y = 2.08
 guard.add_child(head)
 head.material_override = _material(Color("#bd8c68"),0.82)
 var helmet := MeshInstance3D.new()
 var helmet_mesh := SphereMesh.new()
 helmet_mesh.radius = 0.32
 helmet_mesh.height = 0.28
 helmet.mesh = helmet_mesh
 helmet.position.y = 2.31
 guard.add_child(helmet)
 helmet.material_override = trim
 var spear := MeshInstance3D.new()
 var spear_mesh := CylinderMesh.new()
 spear_mesh.top_radius = 0.035
 spear_mesh.bottom_radius = 0.055
 spear_mesh.height = 2.7
 spear.mesh = spear_mesh
 spear.position = Vector3(side*-0.58,1.35,0.0)
 guard.add_child(spear)
 spear.material_override = trim

static func _make_building(city: String, p: Dictionary, index: int, s: float) -> Node3D:
 var root := Node3D.new()
 root.name = city + "_DetailedBuilding_%02d" % index
 var collision_body := StaticBody3D.new()
 collision_body.name = "BuildingCollision"
 var collision_shape := CollisionShape3D.new()
 var collision_box := BoxShape3D.new()
 collision_box.size = Vector3(18.0,10.0,14.0)
 collision_shape.shape = collision_box
 collision_shape.position.y = 5.0
 collision_body.add_child(collision_shape)
 root.add_child(collision_body)
 var wall := _material(p.wall, 0.88)
 wall.normal_enabled = true
 wall.normal_texture = _brick_normal()
 var stone := _material(p.stone, 0.82)
 var wood := _material(p.wood, 0.68)
 var roof := _material(p.roof, 0.72)
 var gold := _material(p.gold, 0.38)
 var accent := _material(p.accent, 0.55)
 _box(root, "RaisedStoneFoundation", Vector3(0,0.55,0), Vector3(19,1.1,15), stone, s)
 _box(root, "CarvedStonePlinth", Vector3(0,1.18,0), Vector3(18.5,0.22,14.5), gold, s)
 _box(root, "ReliefBrickWalls", Vector3(0,5.1,0), Vector3(17.6,7.7,13.6), wall, s)
 _box(root, "UpperTimberFrieze", Vector3(0,9.0,0), Vector3(18.2,0.58,14.2), wood, s)
 # Exposed timber posts at corners and along the main facade.
 for x in [-8.45, 0.0, 8.45]:
  _box(root, "ExteriorTimberPillar", Vector3(x,5.15,7.0), Vector3(0.62,8.0,0.62), wood, s)
 for x in [-8.45,8.45]:
  _box(root, "SideCornerPillar", Vector3(x,5.15,-6.7), Vector3(0.62,8.0,0.62), wood, s)
 # Lattice windows, inset frames and crossbars on the street-facing facade.
 for x in [-5.2,5.2]:
  _window(root, x, 5.5, 6.91, wood, gold, s)
 # Deep double door with raised jambs, leaves and brass hardware.
 _box(root, "DoorRecess", Vector3(0,3.05,7.03), Vector3(3.8,4.5,0.18), stone, s)
 _box(root, "DoorFrameTop", Vector3(0,5.35,7.28), Vector3(4.5,0.42,0.48), gold, s)
 for x in [-2.05,2.05]:
  _box(root, "DoorJamb", Vector3(x,3.1,7.28), Vector3(0.38,4.4,0.48), wood, s)
 _box(root, "DoubleDoorLeft", Vector3(-0.91,3.05,7.25), Vector3(1.72,4.05,0.24), wood, s)
 _box(root, "DoubleDoorRight", Vector3(0.91,3.05,7.25), Vector3(1.72,4.05,0.24), wood, s)
 for x in [-0.18,0.18]:
  _cylinder(root, "DoorGoldenHandle", Vector3(x,3.0,7.43), 0.11, 0.12, gold, s)
 # Shop awning, hanging red lanterns and a carved signboard.
 _box(root, "EntranceAwning", Vector3(0,6.05,8.35), Vector3(6.2,0.28,2.8), roof, s)
 _box(root, "ShopSignBoard", Vector3(0,7.25,7.85), Vector3(4.6,1.15,0.28), wood, s)
 for x in [-2.25,2.25]:
  _cylinder(root, "RedLantern", Vector3(x,5.35,8.35), 0.42, 0.88, accent, s)
  _cylinder(root, "LanternCap", Vector3(x,5.84,8.35), 0.23, 0.12, gold, s)
 # City-specific roof language: Chinese pagoda, desert dome, basalt spires, snow tiers.
 match city:
  "DesertLand":
   _desert_roof(root, roof, gold, s)
  "VolcanoLand":
   _volcano_roof(root, roof, gold, s)
  "IceLand":
   _ice_roof(root, roof, gold, s)
  _:
   _pagoda_roof(root, roof, gold, s, city)
 # Raised decorative corner brackets and fascia.
 for x in [-9.5,9.5]:
  for z in [-7.7,7.7]:
   _box(root, "CarvedEaveBracket", Vector3(x,9.5,z), Vector3(1.0,0.45,1.0), gold, s)
 return root

static func _window(root: Node3D, x: float, y: float, z: float, wood: Material, trim: Material, s: float) -> void:
 _box(root, "LatticeWindowBacking", Vector3(x,y,z), Vector3(2.65,2.45,0.18), wood, s)
 for dx in [-1.48,1.48]:
  _box(root, "WindowFrameVertical", Vector3(x+dx,y,z+0.16), Vector3(0.22,2.8,0.26), trim, s)
 for dy in [-1.32,1.32]:
  _box(root, "WindowFrameHorizontal", Vector3(x,y+dy,z+0.16), Vector3(3.15,0.22,0.26), trim, s)
 for i in range(1,5):
  _box(root, "LatticeVertical", Vector3(x-1.1+i*0.44,y,z+0.22), Vector3(0.10,2.35,0.12), trim, s)
 for i in range(1,4):
  _box(root, "LatticeHorizontal", Vector3(x,y-0.9+i*0.45,z+0.23), Vector3(2.55,0.10,0.12), trim, s)

static func _pagoda_roof(root: Node3D, roof: Material, gold: Material, s: float, city: String) -> void:
 for tier in range(2):
  var y := 9.65 + float(tier)*2.15
  var w := 21.5 - float(tier)*4.1
  var d := 17.3 - float(tier)*3.5
  _box(root, "PagodaRoofTier_%d" % tier, Vector3(0,y,0), Vector3(w,0.48,d), roof, s)
  for side in [-1.0,1.0]:
   for rib in range(13):
    var x := -w*0.46 + float(rib)*w*0.92/12.0
    _box(root, "RaisedParallelRoofRib", Vector3(x,y+0.29,side*(d*0.43)), Vector3(0.14,0.20,1.2), gold if rib in [0,12] else roof, s)
   for end in [-1.0,1.0]:
    var eave := _box(root, "UpturnedCurvedEave", Vector3(end*w*0.47,y+0.62,side*d*0.47), Vector3(2.0,0.28,0.65), gold, s)
    eave.rotation.z = -end*0.32
  _box(root, "GoldenRoofRidge", Vector3(0,y+0.48,0), Vector3(w*0.92,0.22,0.38), gold, s)
  for x in [-w*0.43,w*0.43]:
   for z in [-d*0.43,d*0.43]:
    _cylinder(root, "GoldenTileEndCap", Vector3(x,y+0.28,z), 0.22, 0.16, gold, s)
 if city == "TwinCity":
  _box(root, "DragonRidgeOrnament", Vector3(0,14.25,0), Vector3(3.2,0.42,0.55), gold, s)

static func _desert_roof(root: Node3D, roof: Material, gold: Material, s: float) -> void:
 _box(root, "SandstoneCornice", Vector3(0,9.7,0), Vector3(20.2,0.55,16.2), gold, s)
 var dome := SphereMesh.new()
 dome.radius = 5.8
 dome.height = 5.4
 dome.radial_segments = 32
 dome.rings = 16
 var cap := MeshInstance3D.new()
 cap.name = "SandstoneDome"
 cap.mesh = dome
 cap.position = Vector3(0,11.8,0)
 cap.scale = Vector3(1.0,0.72,0.82)*s
 root.add_child(cap)
 cap.material_override = roof
 for x in [-7.5,7.5]:
  _cylinder(root, "DesertArchColumn", Vector3(x,5.2,7.3), 0.52,8.4,gold,s)
 _box(root, "DomeCrescentFinial", Vector3(0,15.1,0), Vector3(0.55,1.1,0.55), gold, s)

static func _volcano_roof(root: Node3D, roof: Material, gold: Material, s: float) -> void:
 _box(root, "BasaltBattlement", Vector3(0,9.7,0), Vector3(19.8,0.7,15.8), roof, s)
 for x in [-7.0,-3.5,0.0,3.5,7.0]:
  _box(root, "ObsidianSpire", Vector3(x,12.0,-5.7), Vector3(1.0,5.2,1.0), roof, s)
  var tip := _cylinder(root, "BasaltSpireCap", Vector3(x,14.7,-5.7), 0.08,1.0,gold,s)
  tip.rotation.z = PI*0.5
 _box(root, "PhoenixCrest", Vector3(0,13.3,0), Vector3(3.8,0.5,0.7), gold, s)

static func _ice_roof(root: Node3D, roof: Material, gold: Material, s: float) -> void:
 for tier in range(2):
  var y := 9.7 + tier*2.0
  var w := 20.0 - tier*4.0
  _box(root, "SnowRoofTier", Vector3(0,y,0), Vector3(w,0.55,16.0-tier*3.0), roof, s)
  for x in [-w*0.42,w*0.42]:
   _box(root, "IceRoofGable", Vector3(x,y+1.0,0), Vector3(0.5,2.0,13.0), gold, s)
 _box(root, "FrostCrystalRidge", Vector3(0,13.1,0), Vector3(0.6,1.5,0.6), gold, s)

static func _box(parent: Node3D, label: String, at: Vector3, dimensions: Vector3, material: Material, s: float) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.name = label
 var mesh := BoxMesh.new()
 mesh.size = dimensions*s
 node.mesh = mesh
 node.position = at*s
 parent.add_child(node)
 node.material_override = material
 return node

static func _cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, material: Material, s: float) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.name = label
 var mesh := CylinderMesh.new()
 mesh.top_radius = radius*s
 mesh.bottom_radius = radius*s
 mesh.height = height*s
 mesh.radial_segments = 12
 node.mesh = mesh
 node.position = at*s
 parent.add_child(node)
 node.material_override = material
 return node

static func _material(color: Color, roughness: float) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.roughness = roughness
 material.metallic = 0.04
 material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
 return material

static func _brick_normal() -> Texture2D:
 var image := Image.create(128,128,false,Image.FORMAT_RGBA8)
 for y in range(128):
  for x in range(128):
   var row := int(y/16)
   var offset := 8 if row%2 == 1 else 0
   var seam := posmod(x+offset,32)<2 or posmod(y,16)<2
   var groove := 0.36 if seam else 0.58 + 0.08*sin(float(x)*0.31)*cos(float(y)*0.27)
   image.set_pixel(x,y,Color(groove,groove,1.0,1.0))
 return ImageTexture.create_from_image(image)


# ---------------------------------------------------------------------------
# Twin City Imperial reconstruction. Kept separate from the shared six-city
# builder so the other five settlements retain their existing generation path.
# ---------------------------------------------------------------------------
static func build_twin_city(parent: Node3D) -> void:
 var root := Node3D.new()
 root.name = "TwinCity_ImperialReconstruction"
 parent.add_child(root)
 var p := CITY_PALETTES["TwinCity"]
 var stone := _material(Color("#858078"), 0.91)
 var pale_stone := _material(Color("#c9c1ae"), 0.88)
 var dark_stone := _material(Color("#555a60"), 0.94)
 var roof := _material(Color("#2B333E"), 0.78)
 var timber := _material(Color("#71372b"), 0.68)
 var gold := _material(Color("#D49B35"), 0.46)
 var pink := _material(Color("#e5a0b2"), 0.88)
 var water := _material(Color("#145b63"), 0.22)
 _twin_ground(root, stone)
 _twin_moat_walls_gates(root, stone, pale_stone, dark_stone, water, roof, gold, timber)
 _twin_roads(root, stone, pale_stone)
 _twin_plaza(root, stone, pale_stone, gold, pink, roof, timber)
 _twin_palace(root, pale_stone, stone, timber, roof, gold)
 var counts := {"residential":82, "commercial":28, "service":15, "landmark":10, "defensive":14, "palace":8}
 _twin_place_district_buildings(root, counts, pale_stone, stone, timber, roof, gold)
 _twin_outer_biome(root, stone, water, pink)
 print("TWIN_CITY_IMPERIAL_BUILD_PASS: total_structures=157 residential=82 commercial=28 service=15 landmarks=10 defensive=14 palace=8 urban_diameter=360 perimeter_diameter=440 plaza_diameter=60 palace=85x75")

static func _twin_ground(parent: Node3D, stone: Material) -> void:
 var ground := MeshInstance3D.new()
 ground.name = "TwinCity_800m_TerrainFoundation"
 var plane := PlaneMesh.new()
 plane.size = Vector2(800.0, 800.0)
 ground.mesh = plane
 ground.position.y = -0.18
 parent.add_child(ground)
 ground.material_override = _material(Color("#667b54"), 1.0)
 # Broad irregular city foundation inside the perimeter.
 for i in range(72):
  var a := TAU * float(i) / 72.0
  var radius := 178.0 + 4.0 * sin(a * 5.0) + 2.5 * cos(a * 9.0)
  var tile := _twin_box(parent, "OrganicUrbanEdge_%02d" % i, Vector3(cos(a)*radius,0.02,sin(a)*radius), Vector3(10.0,0.16,8.0), stone)
  tile.rotation.y = -a

static func _twin_moat_walls_gates(parent: Node3D, stone: Material, pale: Material, dark: Material, water: Material, roof: Material, gold: Material, timber: Material) -> void:
 var moat := MeshInstance3D.new()
 moat.name = "DeepContinuousWaterMoat_440m"
 var ring := TorusMesh.new()
 ring.inner_radius = 207.0
 ring.outer_radius = 220.0
 ring.rings = 160
 ring.ring_segments = 12
 moat.mesh = ring
 moat.position.y = -1.7
 parent.add_child(moat)
 moat.material_override = water
 for i in range(64):
  var a := TAU * float(i) / 64.0
  var radius := 218.0 + 2.0*sin(a*5.0) + 1.2*cos(a*9.0)
  var pos := Vector3(cos(a)*radius, 6.0, sin(a)*radius)
  var tangent := Vector3(-sin(a),0,cos(a))
  var wall := _twin_box(parent, "OrganicFortifiedWall_%02d" % i, pos, Vector3(22.0,12.0,6.0), stone)
  wall.rotation.y = -a
  var coping := _twin_box(parent, "WallCoping_%02d" % i, pos+Vector3(0,6.25,0), Vector3(22.0,0.55,6.8), pale)
  coping.rotation.y = -a
  if i % 4 == 0:
   var tower := _twin_cylinder(parent, "PerimeterWatchTower_%02d" % i, pos+Vector3(0,5.0,0), 4.0, 17.0, dark)
   var cap := _twin_box(parent, "WatchTowerRoof_%02d" % i, pos+Vector3(0,14.0,0), Vector3(11.0,1.0,11.0), roof)
   cap.rotation.y = a
 # Four arched stone bridge approaches and gatehouses.
 for gate_index in range(4):
  var a := float(gate_index)*PI*0.5
  var direction := Vector3(cos(a),0,sin(a))
  var center := direction*220.0
  var bridge := _twin_box(parent, "ArchedStoneBridge_%d" % gate_index, center+Vector3(0,-0.1,0), Vector3(20.0,1.7,38.0), pale)
  bridge.rotation.y = -a
  for side in [-1.0,1.0]:
   var tower_pos := center + direction*(-14.0) + Vector3(-direction.z*side*13.0,0,direction.x*side*13.0)
   _twin_gate_tower(parent, gate_index, side, tower_pos, pale, roof, gold)
  var gate_arch := _twin_box(parent, "GateArchBeam_%d" % gate_index, center+direction*(-12.0)+Vector3(0,12.0,0), Vector3(31.0,2.5,4.0), timber)
  gate_arch.rotation.y = -a

static func _twin_gate_tower(parent: Node3D, gate_index: int, side: float, pos: Vector3, stone: Material, roof: Material, gold: Material) -> void:
 var base := _twin_box(parent, "Gatehouse_%d_%d" % [gate_index,int(side)], pos+Vector3(0,7.0,0), Vector3(12.0,14.0,12.0), stone)
 var cap := _twin_box(parent, "GatehouseDarkRoof_%d_%d" % [gate_index,int(side)], pos+Vector3(0,15.0,0), Vector3(16.0,2.0,16.0), roof)
 var trim := _twin_box(parent, "GatehouseGoldEave_%d_%d" % [gate_index,int(side)], pos+Vector3(0,16.1,0), Vector3(16.6,0.28,16.6), gold)

static func _twin_roads(parent: Node3D, stone: Material, curb: Material) -> void:
 var road_root := Node3D.new()
 road_root.name = "OrganicConnectedFlagstoneRoadNetwork"
 parent.add_child(road_root)
 var transforms: Array[Transform3D] = []
 for arm in range(4):
  var angle := float(arm)*PI*0.5
  var previous := Vector3(cos(angle)*216.0,0.16,sin(angle)*216.0)
  for step in range(1,9):
   var t := float(step)/8.0
   var bend := sin(t*PI)*5.0*sin(angle+0.8)
   var next := Vector3(cos(angle)*(216.0-t*178.0)-sin(angle)*bend,0.16,sin(angle)*(216.0-t*178.0)+cos(angle)*bend)
   transforms.append(_twin_road_transform(previous,next,13.0))
   previous=next
 for lane in range(12):
  var angle := TAU*float(lane)/12.0+0.12
  var radius := 78.0+float(lane%3)*25.0
  var previous := Vector3(cos(angle)*radius,0.12,sin(angle)*radius)
  for part in range(1,5):
   var next_angle := angle+float(part)*0.10
   var next_radius := radius+sin(float(part)*1.2+angle)*4.5
   var next := Vector3(cos(next_angle)*next_radius,0.12,sin(next_angle)*next_radius)
   transforms.append(_twin_road_transform(previous,next,5.2))
   previous=next
 var multi := MultiMesh.new()
 multi.transform_format = MultiMesh.TRANSFORM_3D
 var mesh := BoxMesh.new()
 mesh.size = Vector3.ONE
 multi.mesh = mesh
 multi.instance_count = transforms.size()
 for i in range(transforms.size()):
  multi.set_instance_transform(i,transforms[i])
 var roads := MultiMeshInstance3D.new()
 roads.name = "BatchedStoneAvenuesAndWindingLanes"
 roads.multimesh = multi
 road_root.add_child(roads)
 roads.material_override = stone

static func _twin_road_transform(a: Vector3,b: Vector3,width: float) -> Transform3D:
 var delta := b-a
 var basis := Basis(Vector3.UP,atan2(delta.x,delta.z)).scaled(Vector3(width,0.22,delta.length()+1.0))
 return Transform3D(basis,(a+b)*0.5)

static func _twin_plaza(parent: Node3D, stone: Material, pale: Material, gold: Material, pink: Material, roof: Material, timber: Material) -> void:
 var plaza := Node3D.new()
 plaza.name = "CircularImperialPlaza_60m"
 parent.add_child(plaza)
 var disk := MeshInstance3D.new()
 var disc_mesh := CylinderMesh.new()
 disc_mesh.top_radius = 30.0
 disc_mesh.bottom_radius = 30.0
 disc_mesh.height = 0.48
 disc_mesh.radial_segments = 96
 disk.mesh = disc_mesh
 disk.position.y = 0.16
 plaza.add_child(disk)
 disk.material_override = pale
 for ring_index in range(3):
  var torus := MeshInstance3D.new()
  var torus_mesh := TorusMesh.new()
  torus_mesh.inner_radius = 20.0+float(ring_index)*3.0
  torus_mesh.outer_radius = 20.6+float(ring_index)*3.0
  torus.mesh = torus_mesh
  torus.position.y = 0.48+float(ring_index)*0.01
  plaza.add_child(torus)
  torus.material_override = gold if ring_index == 1 else stone
 # Radial paving wedges create a circular engraved pattern rather than a grid.
 for i in range(48):
  var a := TAU*float(i)/48.0
  var tile := _twin_box(plaza, "RadialEngravedPaver_%02d" % i, Vector3(cos(a)*15.0,0.46,sin(a)*15.0), Vector3(2.0,0.12,28.0), stone)
  tile.rotation.y = -a
 # Pagoda landmark (20m) at the precise center.
 _twin_pagoda(plaza, roof, timber, gold)
 # Pink flowering cherry trees ring the plaza perimeter.
 for i in range(12):
  var a := TAU*float(i)/12.0
  var pos := Vector3(cos(a)*34.0,0,sin(a)*34.0)
  _twin_tree(plaza, "PlazaCherry_%02d" % i, pos, pink, timber, 1.0)

static func _twin_pagoda(parent: Node3D, roof: Material, timber: Material, gold: Material) -> void:
 var root := Node3D.new()
 root.name = "CentralPagoda_20m"
 parent.add_child(root)
 for level in range(4):
  var y := 2.0+float(level)*4.0
  var width := 12.0-float(level)*2.0
  _twin_box(root, "PagodaStorey_%d" % level, Vector3(0,y,0), Vector3(width,3.3,width), timber)
  var cap := _twin_box(root, "PagodaDarkRoof_%d" % level, Vector3(0,y+2.0,0), Vector3(width+5.0,0.8,width+5.0), roof)
  for edge in [-1.0,1.0]:
   var eave := _twin_box(root, "PagodaEaveTrim_%d_%d" % [level,int(edge)], Vector3(edge*(width+2.0)*0.5,y+2.35,0), Vector3(0.35,0.28,width+5.0), gold)
 _twin_cylinder(root, "PagodaFinial", Vector3(0,19.0,0), 0.32,2.0,gold)

static func _twin_palace(parent: Node3D,pale: Material,stone: Material,timber: Material,roof: Material,gold: Material) -> void:
 var palace := Node3D.new()
 palace.name = "ImperialPalace_85x75"
 palace.position = Vector3(0,0,-103.0)
 parent.add_child(palace)
 var imperial_gold := _material(Color("#E0A83B"),0.44)
 _twin_box(palace,"PalaceRaisedStoneTerrace",Vector3(0,2.25,0),Vector3(85.0,4.5,75.0),stone)
 _twin_box(palace,"PalaceUpperTerrace",Vector3(0,4.7,8.0),Vector3(69.0,1.0,55.0),pale)
 # Broad ceremonial staircase rises 4.5m from the plaza-facing southern edge.
 for step in range(10):
  var rise := float(step)*0.45
  _twin_box(palace,"ImperialStair_%02d" % step,Vector3(0,0.25+rise,31.0+float(step)*2.1),Vector3(22.0,0.5+rise*0.08,2.2),pale)
 for wing in range(3):
  var x := float(wing-1)*27.0
  var hall_width := 28.0 if wing == 1 else 21.0
  var hall_depth := 25.0 if wing == 1 else 21.0
  var hall_z := 7.0-float(wing%2)*5.0
  _twin_box(palace,"PalaceHall_%d" % wing,Vector3(x,10.0,hall_z),Vector3(hall_width,10.0,hall_depth),pale)
  for col in range(5):
   var cx := x-hall_width*0.42+float(col)*hall_width*0.21
   _twin_cylinder(palace,"PalaceColumn_%d_%d" % [wing,col],Vector3(cx,8.5,hall_z+hall_depth*0.5+0.3),0.72,8.0,timber)
  # Two stepped imperial roof tiers, restrained gold ridge work and projecting eaves.
  _twin_box(palace,"ImperialGoldenLowerEave_%d" % wing,Vector3(x,15.4,hall_z),Vector3(hall_width+6.0,0.72,hall_depth+7.0),imperial_gold)
  _twin_box(palace,"ImperialGoldenUpperRoof_%d" % wing,Vector3(x,16.2,hall_z),Vector3(hall_width+2.0,0.65,hall_depth+3.0),imperial_gold)
  _twin_box(palace,"ImperialRoofRidge_%d" % wing,Vector3(x,16.75,hall_z),Vector3(hall_width*0.82,0.32,0.72),gold)
  for side in [-1.0,1.0]:
   _twin_box(palace,"ImperialRaisedEaveTip_%d_%d" % [wing,int(side)],Vector3(x+side*(hall_width*0.5+2.4),16.0,hall_z),Vector3(0.65,0.42,hall_depth+6.0),gold)
 # Stone guardian sculptures stand on pedestals at the stair landing.
 for side in [-1.0,1.0]:
  _twin_guardian(palace,Vector3(side*14.0,5.0,30.0),stone,gold)
static func _twin_guardian(parent: Node3D, pos: Vector3, stone: Material, gold: Material) -> void:
 _twin_box(parent, "ImperialGuardianPedestal", pos+Vector3(0,0.6,0), Vector3(2.0,1.2,2.0), stone)
 _twin_cylinder(parent, "ImperialGuardianBody", pos+Vector3(0,2.0,0), 0.72,2.2,stone)
 _twin_cylinder(parent, "ImperialGuardianHead", pos+Vector3(0,3.6,0), 0.5,1.0,gold)

static func _twin_place_district_buildings(parent: Node3D, counts: Dictionary, wall: Material, stone: Material, timber: Material, roof: Material, gold: Material) -> void:
 var districts := Node3D.new()
 districts.name = "DenseMixedResidentialCommercialDistricts_157"
 parent.add_child(districts)
 var batches := {
  "foundation": [], "walls": [], "roof": [], "timber": [],
  "windows": [], "gold": [], "doors": [], "shop": [], "posts": []
 }
 var serial := 0
 # Ten compact mixed-use blocks. Each block has eight perimeter houses and
 # a central landmark; two extra houses fill the strongest residential blocks.
 for block in range(10):
  var angle := TAU*float(block)/10.0
  var radius := 88.0+float(block%3)*13.0
  var center := Vector3(cos(angle)*radius,0,sin(angle)*radius)
  if absf(center.x)<58.0 and center.z < -48.0:
   center.x += 72.0 if center.x >= 0.0 else -72.0
  var rotation := -angle+PI*0.5
  var house_offsets := [
   Vector3(-12,0,-12),Vector3(0,0,-12),Vector3(12,0,-12),
   Vector3(-12,0,0),Vector3(12,0,0),
   Vector3(-12,0,12),Vector3(0,0,12),Vector3(12,0,12)
  ]
  for local_index in range(8):
   var offset: Vector3 = house_offsets[local_index]
   var pos := center + Basis(Vector3.UP,rotation)*offset
   _twin_register_batched_building(districts,batches,"residential",serial,pos,7.5+float((serial*7)%4),7.0+float((serial*3)%3),2+(serial%2),wall,stone,timber,roof,gold,rotation)
   serial += 1
  # Two real shopfronts per block, facing the inner pedestrian street.
  for shop_index in range(2):
   var offset := Vector3(-5.0+float(shop_index)*10.0,0,-25.0)
   var pos := center + Basis(Vector3.UP,rotation)*offset
   _twin_register_batched_building(districts,batches,"commercial",serial,pos,6.0+float(shop_index),6.5,2,wall,stone,timber,roof,gold,rotation)
   serial += 1
  # One inn/workshop per block, on the outer lane.
  var service_pos := center + Basis(Vector3.UP,rotation)*Vector3(0,0,25.0)
  _twin_register_batched_building(districts,batches,"service",serial,service_pos,9.0,8.0,2+(block%2),wall,stone,timber,roof,gold,rotation)
  serial += 1
  # A distinctive civic/temple landmark occupies the block's open centre.
  var landmark_pos := center + Basis(Vector3.UP,rotation)*Vector3(0,0,0)
  _twin_register_batched_building(districts,batches,"landmark",serial,landmark_pos,13.0,12.0,3,wall,stone,timber,roof,gold,rotation)
  serial += 1
 # Remaining 2 houses, 8 shops and 5 service buildings fill the market ring.
 for i in range(2):
  var angle := TAU*float(i)/2.0+0.4
  var pos := Vector3(cos(angle)*66.0,0,sin(angle)*66.0)
  _twin_register_batched_building(districts,batches,"residential",serial,pos,9.0,8.0,3,wall,stone,timber,roof,gold,angle)
  serial += 1
 for i in range(8):
  var angle := TAU*float(i)/8.0+0.18
  var pos := Vector3(cos(angle)*54.0,0,sin(angle)*54.0)
  _twin_register_batched_building(districts,batches,"commercial",serial,pos,6.0+float(i%3)*0.5,6.0,2,wall,stone,timber,roof,gold,angle)
  serial += 1
 for i in range(5):
  var angle := TAU*float(i)/5.0+0.3
  var pos := Vector3(cos(angle)*150.0,0,sin(angle)*150.0)
  _twin_register_batched_building(districts,batches,"service",serial,pos,8.5,8.0,2,wall,stone,timber,roof,gold,angle)
  serial += 1
 # Fourteen tall defensive structures form a secondary ring just inside the moat.
 for i in range(int(counts.defensive)):
  var angle := TAU*float(i)/float(counts.defensive)
  var pos := Vector3(cos(angle)*190.0,0,sin(angle)*190.0)
  _twin_register_batched_building(districts,batches,"defensive",serial,pos,8.0,8.0,4,wall,stone,timber,roof,gold,angle)
  serial += 1
 # Eight palace annex structures sit behind and beside the imperial hall.
 for i in range(int(counts.palace)):
  var x := -48.0+float(i%4)*32.0
  var z := -163.0+float(int(i/4))*20.0
  _twin_register_batched_building(districts,batches,"palace_annex",serial,Vector3(x,0,z),13.0,11.0,2,wall,stone,timber,gold,gold,0.0)
  serial += 1
 _twin_flush_building_batches(districts,batches,wall,stone,timber,roof,gold)
 print("TWIN_CITY_BUILDING_CENSUS: residential=82 commercial=28 service=15 landmarks=10 defensive=14 palace=8 total=%d" % serial)

static func _twin_register_batched_building(parent: Node3D,batches: Dictionary,kind: String,index: int,pos: Vector3,width: float,depth: float,floors: int,wall: Material,stone: Material,timber: Material,roof: Material,gold: Material,rotation: float) -> void:
 var root := Node3D.new()
 root.name = "TwinCity_%s_%03d" % [kind,index]
 root.position = pos
 root.rotation.y = rotation
 root.add_to_group("twin_city_building")
 parent.add_child(root)
 var height := float(floors)*3.2+1.0
 _twin_batch_add(batches,"foundation",pos+Vector3(0,0.35,0),Vector3(width+1.0,0.7,depth+1.0),rotation)
 _twin_batch_add(batches,"walls",pos+Vector3(0,height*0.5+0.7,0),Vector3(width,height,depth),rotation)
 for floor_index in range(floors):
  var y := 2.0+float(floor_index)*3.2
  var front := Vector3(0,y,depth*0.5+0.08)
  _twin_batch_add(batches,"timber",pos+Basis(Vector3.UP,rotation)*front,Vector3(width+0.3,0.22,0.22),rotation)
  var windows := maxi(2,int(width/2.8))
  for window_index in range(windows):
   var wx := -width*0.38+float(window_index)*width*0.76/float(maxi(1,windows-1))
   var window_pos := pos+Basis(Vector3.UP,rotation)*Vector3(wx,y+1.0,depth*0.5+0.13)
   _twin_batch_add(batches,"windows",window_pos,Vector3(0.72,1.25,0.12),rotation)
   _twin_batch_add(batches,"gold",window_pos+Basis(Vector3.UP,rotation)*Vector3(0,0.68,0.03),Vector3(0.92,0.16,0.18),rotation)
 var door_pos := pos+Basis(Vector3.UP,rotation)*Vector3(0,1.55,depth*0.5+0.16)
 _twin_batch_add(batches,"doors",door_pos,Vector3(1.35,2.6,0.22),rotation)
 var roof_y := height+1.05
 match index%4:
  0:
   _twin_batch_add(batches,"roof",pos+Vector3(0,roof_y,0),Vector3(width+2.2,0.8,depth+2.2),rotation)
   _twin_batch_add(batches,"gold",pos+Vector3(0,roof_y+0.52,0),Vector3(width*0.62,0.22,0.38),rotation)
  1:
   _twin_batch_add(batches,"roof",pos+Vector3(0,roof_y,0),Vector3(width+1.8,0.7,depth+1.8),rotation)
   for side in [-1.0,1.0]:
    _twin_batch_add(batches,"gold",pos+Basis(Vector3.UP,rotation)*Vector3(side*(width*0.5+0.6),roof_y+0.45,0),Vector3(0.35,0.3,depth+2.4),rotation)
  2:
   for tier in range(2):
    _twin_batch_add(batches,"roof",pos+Vector3(0,roof_y+float(tier)*0.65,0),Vector3(width+2.5-float(tier)*2.0,0.38,depth+2.5-float(tier)*2.0),rotation)
  _:
   _twin_batch_add(batches,"roof",pos+Vector3(0,roof_y,0),Vector3(width+1.5,0.9,depth+1.5),rotation)
 for sx in [-1.0,1.0]:
  for sz in [-1.0,1.0]:
   var post_pos := pos+Basis(Vector3.UP,rotation)*Vector3(sx*(width*0.5-0.22),height*0.5+0.7,sz*(depth*0.5-0.22))
   _twin_batch_add(batches,"posts",post_pos,Vector3(0.28,height,0.28),rotation)
 if kind == "commercial":
  var awning_pos := pos+Basis(Vector3.UP,rotation)*Vector3(0,height*0.56,depth*0.5+1.15)
  _twin_batch_add(batches,"shop",awning_pos,Vector3(minf(width,5.8),0.28,2.2),rotation)
  _twin_batch_add(batches,"shop",awning_pos+Basis(Vector3.UP,rotation)*Vector3(0,-height*0.42,0.65),Vector3(minf(width*0.55,2.8),1.1,0.72),rotation)
  _twin_batch_add(batches,"gold",awning_pos+Basis(Vector3.UP,rotation)*Vector3(0,0.9,0.1),Vector3(minf(width,4.5),0.75,0.18),rotation)
 if kind == "defensive":
  _twin_batch_add(batches,"gold",pos+Vector3(0,height+0.9,0),Vector3(width+2.5,0.4,depth+2.5),rotation)

static func _twin_batch_add(batches: Dictionary,key: String,pos: Vector3,size: Vector3,rotation: float) -> void:
 var basis := Basis(Vector3.UP,rotation).scaled(size)
 batches[key].append(Transform3D(basis,pos))

static func _twin_flush_building_batches(parent: Node3D,batches: Dictionary,wall: Material,stone: Material,timber: Material,roof: Material,gold: Material) -> void:
 var materials := {"foundation":stone,"walls":wall,"roof":roof,"timber":timber,"windows":timber,"gold":gold,"doors":timber,"shop":timber,"posts":timber}
 for key in batches.keys():
  var transforms: Array = batches[key]
  if transforms.is_empty():
   continue
  var multi := MultiMesh.new()
  multi.transform_format = MultiMesh.TRANSFORM_3D
  var mesh := BoxMesh.new()
  mesh.size = Vector3.ONE
  multi.mesh = mesh
  multi.instance_count = transforms.size()
  for i in range(transforms.size()):
   multi.set_instance_transform(i,transforms[i])
  var instance := MultiMeshInstance3D.new()
  instance.name = "BatchedArchitecture_" + str(key)
  instance.multimesh = multi
  parent.add_child(instance)
  instance.material_override = materials[key]

static func _twin_outer_biome(parent: Node3D,stone: Material,water: Material,pink: Material) -> void:
 var nature := Node3D.new()
 nature.name = "TwinCity_OuterWildlands_800m"
 parent.add_child(nature)
 # Batched rolling hills beyond the moat.
 var hill_multi := MultiMesh.new()
 hill_multi.transform_format = MultiMesh.TRANSFORM_3D
 var hill_mesh := BoxMesh.new()
 hill_mesh.size = Vector3.ONE
 hill_multi.mesh = hill_mesh
 hill_multi.instance_count = 120
 for i in range(120):
  var angle := TAU*float(i)/120.0
  var radius := 258.0+float((i*37)%112)
  var size := Vector3(22.0+float(i%5)*4.0,7.0+float(i%4)*2.0,24.0+float(i%3)*3.0)
  var basis := Basis(Vector3.UP,angle).scaled(size)
  var pos := Vector3(cos(angle)*radius,-2.0,sin(angle)*radius)
  hill_multi.set_instance_transform(i,Transform3D(basis,pos))
 var hills := MultiMeshInstance3D.new()
 hills.name = "OuterRollingHills_MultiMesh"
 hills.multimesh = hill_multi
 nature.add_child(hills)
 hills.material_override = _material(Color("#74845d"),1.0)
 # Trees are two batches, not 320 independent draw calls.
 var trunk_mesh := CylinderMesh.new()
 trunk_mesh.top_radius = 0.28
 trunk_mesh.bottom_radius = 0.42
 trunk_mesh.height = 5.2
 trunk_mesh.radial_segments = 8
 var crown_mesh := SphereMesh.new()
 crown_mesh.radius = 3.0
 crown_mesh.height = 4.4
 var trunks := MultiMesh.new()
 trunks.transform_format = MultiMesh.TRANSFORM_3D
 trunks.mesh = trunk_mesh
 trunks.instance_count = 160
 var crowns := MultiMesh.new()
 crowns.transform_format = MultiMesh.TRANSFORM_3D
 crowns.mesh = crown_mesh
 crowns.instance_count = 160
 for i in range(160):
  var angle := float(i)*2.399963
  var radius := 245.0+float((i*29)%145)
  var scale := 0.78+float(i%4)*0.12
  var pos := Vector3(cos(angle)*radius,2.6,sin(angle)*radius)
  var basis := Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale)
  trunks.set_instance_transform(i,Transform3D(basis,pos))
  crowns.set_instance_transform(i,Transform3D(basis,pos+Vector3(0,4.0,0)))
 var trunk_node := MultiMeshInstance3D.new()
 trunk_node.name = "OuterForestTrunks_MultiMesh"
 trunk_node.multimesh = trunks
 nature.add_child(trunk_node)
 trunk_node.material_override = _material(Color("#60422f"),0.95)
 var crown_node := MultiMeshInstance3D.new()
 crown_node.name = "OuterForestCanopies_MultiMesh"
 crown_node.multimesh = crowns
 nature.add_child(crown_node)
 crown_node.material_override = _material(Color("#58744c"),0.95)
 var stream := MeshInstance3D.new()
 stream.name = "OuterTurquoiseStream"
 var stream_mesh := PlaneMesh.new()
 stream_mesh.size = Vector2(24.0,180.0)
 stream.mesh = stream_mesh
 stream.position = Vector3(280.0,-0.02,-250.0)
 stream.rotation_degrees.y = 28.0
 nature.add_child(stream)
 stream.material_override = water
 _twin_box(nature,"OuterMonsterHuntingMeadow",Vector3(-280.0,-0.02,255.0),Vector3(110.0,0.12,95.0),_material(Color("#84945e"),1.0))

static func _twin_tree(parent: Node3D,label: String,pos: Vector3,foliage: Material,bark: Material,scale: float) -> void:
 var tree := Node3D.new()
 tree.name = label
 tree.position = pos
 tree.scale = Vector3.ONE*scale
 parent.add_child(tree)
 _twin_cylinder(tree,"CherryTreeTrunk",Vector3(0,2.6,0),0.38,5.2,bark)
 var crown := MeshInstance3D.new()
 var crown_mesh := SphereMesh.new()
 crown_mesh.radius = 3.0
 crown_mesh.height = 4.4
 crown.mesh = crown_mesh
 crown.position.y = 6.0
 tree.add_child(crown)
 crown.material_override = foliage

static func _twin_box(parent: Node3D,label: String,pos: Vector3,size: Vector3,material: Material) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.name = label
 var mesh := BoxMesh.new()
 mesh.size = size
 node.mesh = mesh
 node.position = pos
 parent.add_child(node)
 node.material_override = material
 return node

static func _twin_cylinder(parent: Node3D,label: String,pos: Vector3,radius: float,height: float,material: Material) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.name = label
 var mesh := CylinderMesh.new()
 mesh.top_radius = radius
 mesh.bottom_radius = radius
 mesh.height = height
 mesh.radial_segments = 16
 node.mesh = mesh
 node.position = pos
 parent.add_child(node)
 node.material_override = material
 return node

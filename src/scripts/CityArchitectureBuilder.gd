extends RefCounted
## Detailed, lightweight facade and roof kit for all six classic settlements.
## Every building is assembled from real 3D meshes; brick relief uses a generated normal map.
const CITY_PALETTES := {
 "TwinCity": {"wall": Color("#c9ad83"), "stone": Color("#75634e"), "wood": Color("#71372b"), "roof": Color("#9e3027"), "gold": Color("#d6a64e"), "accent": Color("#f0c66d")},
 "DesertLand": {"wall": Color("#c99b62"), "stone": Color("#8a623e"), "wood": Color("#70452c"), "roof": Color("#a87542"), "gold": Color("#d6ad6d"), "accent": Color("#e9c78c")},
 "VolcanoLand": {"wall": Color("#514744"), "stone": Color("#292629"), "wood": Color("#3b2925"), "roof": Color("#332d30"), "gold": Color("#bd7040"), "accent": Color("#e56c36")},
 "IceLand": {"wall": Color("#a9c5d5"), "stone": Color("#718b9b"), "wood": Color("#49677a"), "roof": Color("#d9edf5"), "gold": Color("#9bd6e9"), "accent": Color("#e6f8ff")},
 "Waterlands": {"wall": Color("#b9aa87"), "stone": Color("#756e5c"), "wood": Color("#654a32"), "roof": Color("#456d69"), "gold": Color("#d0ad64"), "accent": Color("#9bd5c6")},
 "DarkForest": {"wall": Color("#786f55"), "stone": Color("#454536"), "wood": Color("#49372a"), "roof": Color("#35483a"), "gold": Color("#b69a52"), "accent": Color("#9bb76a")}
}
static func build(parent: Node3D, city: String, size: float) -> void:
 var palette: Dictionary = CITY_PALETTES.get(city, CITY_PALETTES["TwinCity"])
 _build_open_plaza(parent, palette)
 _build_city_roads(parent, palette)
 _build_city_buildings(parent, city, palette)
 _build_city_walls_and_gates(parent, city, palette)
 _build_outer_biome(parent, city, palette, size)
 print("CITY_ARCHITECTURE_PASS: %s detailed_buildings=24 walls=4 gates=4 open_plaza=80x80 outer_world=800x800" % city)

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
    var building := _make_building(city,p,index,1.0)
    building.name = city + "_DetailedBuilding_%02d" % index
    building.position = position
    building.rotation.y = atan2(-position.x,-position.z)
    slot.add_child(building)
    index += 1

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

static func _build_horizon_ridge(parent: Node3D, city: String, p: Dictionary) -> void:
 var ridge_mesh := ConeMesh.new()
 ridge_mesh.radial_segments = 7
 ridge_mesh.rings = 3
 ridge_mesh.bottom_radius = 46.0
 ridge_mesh.height = 112.0
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

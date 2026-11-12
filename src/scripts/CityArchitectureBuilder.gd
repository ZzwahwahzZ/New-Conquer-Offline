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
 var scale_factor := 1.0
 var radius := 82.0 if city == "TwinCity" else 70.0
 var positions := [Vector3(-radius,0,-radius), Vector3(radius,0,-radius), Vector3(-radius,0,radius), Vector3(radius,0,radius)]
 for index in range(positions.size()):
  var building := _make_building(city, palette, index, scale_factor)
  building.position = positions[index]
  building.rotation.y = atan2(-positions[index].x, -positions[index].z)
  parent.add_child(building)
 print("CITY_ARCHITECTURE_PASS: %s detailed_buildings=%d" % [city, positions.size()])

static func _make_building(city: String, p: Dictionary, index: int, s: float) -> Node3D:
 var root := Node3D.new()
 root.name = city + "_DetailedBuilding_%02d" % index
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
 cap.material_override = roof
 root.add_child(cap)
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
 node.material_override = material
 parent.add_child(node)
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
 node.material_override = material
 parent.add_child(node)
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

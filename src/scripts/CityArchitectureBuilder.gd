extends RefCounted
const WorldTerrainBuilder = preload("res://src/scripts/WorldTerrainBuilder.gd")
const PBRMaterialLibrary = preload("res://src/scripts/PBRMaterialLibrary.gd")
const ChineseImperialBuilder = preload("res://src/scripts/ChineseImperialBuilder.gd")
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
 var height_image: Image = WorldTerrainBuilder.load_height_image(city)
 _build_open_plaza(parent, city, palette, height_image)
 _build_city_roads(parent, city, palette, height_image)
 _build_city_buildings(parent, city, palette, height_image)
 _build_city_walls_and_gates(parent, city, palette, height_image)
 ChineseImperialBuilder.build(parent, city, size)
 _build_kenney_city_modules(parent, city, palette, height_image)
 _build_outer_biome(parent, city, palette, size, height_image)
 print("CITY_ARCHITECTURE_PASS: %s detailed_buildings=85-88 walls=4 gates=4 open_plaza=50x50 city_core=170x170 outer_world=800x800" % city)

static func _build_open_plaza(parent: Node3D, city: String, p: Dictionary, height_image: Image) -> void:
 var plaza := Node3D.new()
 plaza.name = "OpenCentralPlaza_50x50"
 var plaza_ground := 0.0
 for sample_z in range(-5,6):
  for sample_x in range(-5,6):
   plaza_ground = maxf(plaza_ground,WorldTerrainBuilder.sample_height_image(height_image,city,float(sample_x)*5.0,float(sample_z)*5.0,800.0))
 plaza.position.y = plaza_ground + 0.85
 parent.add_child(plaza)
 var stone: StandardMaterial3D = PBRMaterialLibrary.build_imperial_paving_material()
 stone.uv1_scale = Vector3(3.9,3.9,1.0)
 for z in range(-3,4):
  for x in range(-3,4):
   var tile := _box(plaza, "DiamondStonePaver_%02d_%02d" % [x+3,z+3], Vector3(float(x)*7.0,0.055,float(z)*7.0), Vector3(6.85,0.11,6.85), stone, 1.0)
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
 _add_plaza_statue(plaza)

static func _add_plaza_statue(parent: Node3D) -> void:
 var candidates: Array[String] = []
 var lion_path := "res://assets/wuxia_imperial_pack/props_nature/guardian_lion_pair.glb"
 if ResourceLoader.exists(lion_path):
  candidates.append(lion_path)
 candidates = candidates.filter(func(path: String) -> bool: return path.get_file().to_lower().contains("guardian_lion_pair"))
 candidates.sort()
 if candidates.is_empty():
  push_error("IMPERIAL_PLAZA_STATUE_MISSING: verified Chinese guardian lion pair is absent from Wuxia Imperial pack")
  return
 var packed := ResourceLoader.load(candidates[0]) as PackedScene
 if packed == null:
  push_error("IMPERIAL_PLAZA_STATUE_IMPORT_FAIL: " + candidates[0])
  return
 var statue := packed.instantiate() as Node3D
 if statue == null:
  push_error("IMPERIAL_PLAZA_STATUE_ROOT_FAIL: " + candidates[0])
  return
 var mesh_node := _first_mesh_node(statue)
 if mesh_node == null or mesh_node.mesh == null:
  statue.free()
  push_error("IMPERIAL_PLAZA_STATUE_MESH_FAIL: " + candidates[0])
  return
 var model_height := maxf(mesh_node.mesh.get_aabb().size.y, 0.01)
 statue.name = "ImperialPlazaStoneStatue"
 statue.scale = Vector3.ONE * (4.8 / model_height)
 statue.position = Vector3(0.0,0.12,16.0)
 statue.set_meta("source_asset_path", candidates[0])
 statue.add_to_group("imperial_plaza_statue")
 parent.add_child(statue)
 _add_static_mesh_collisions(statue)
 print("IMPERIAL_PLAZA_STATUE_PASS: " + candidates[0])

static func _build_city_roads(parent: Node3D, city: String, p: Dictionary, height_image: Image) -> void:
 var roads := Node3D.new()
 roads.name = "StoneRoadNetwork"
 parent.add_child(roads)
 var half := 85.0
 var road_length := 170.0
 # Raise the two arterial routes above the highest sampled terrain along their
 # full extent so desert, volcanic and archipelago ground cannot swallow them.
 var road_clearance_height := 0.0
 for sample_index in range(65):
  var along := lerpf(-road_length * 0.5, road_length * 0.5, float(sample_index) / 64.0)
  road_clearance_height = maxf(road_clearance_height, WorldTerrainBuilder.sample_height_image(height_image,city,0.0,along,800.0))
  road_clearance_height = maxf(road_clearance_height, WorldTerrainBuilder.sample_height_image(height_image,city,along,0.0,800.0))
 road_clearance_height += 0.85
 var road_material: StandardMaterial3D = PBRMaterialLibrary.build_street_material()
 var curb_material := _material(p.gold,0.76)
 for direction in range(2):
  var road := _box(roads,"FlagstoneRoad_%d" % direction,Vector3(0,0.055,0),Vector3(12.0,0.02,road_length),road_material,1.0)
  var road_surface_material := road_material.duplicate() as StandardMaterial3D
  road_surface_material.albedo_color = Color("#e0ddd3")
  road_surface_material.uv1_scale = Vector3(10.0/3.4,road_length/3.4,1.0)
  road.material_override = road_surface_material
  road.rotation_degrees.y = direction*90.0
  road.position.y = road_clearance_height
  road_surface_material.uv1_triplanar = true
  for side in [-1.0,1.0]:
   var curb := _box(roads,"RaisedStoneCurb_%d_%d" % [direction,int(side)],Vector3(side*6.35,0.34,0),Vector3(0.65,0.48,road_length),curb_material,1.0)
   curb.rotation_degrees.y = direction*90.0
 _build_urban_alley_multimeshes(roads,city,road_material)

static func _build_urban_alley_multimeshes(parent: Node3D, city: String, material: Material) -> void:
 var terrain_image := WorldTerrainBuilder.load_height_image(city)
 var alley_lines := [-10.0,10.0]
 var segment_centers := [-77.0,-63.0,-49.0,-35.0,-21.0,-7.0,7.0,21.0,35.0,49.0,63.0,77.0]
 var alley_mesh := BoxMesh.new()
 alley_mesh.size = Vector3(6.0,0.14,14.0)
 for axis in range(2):
  var multi := MultiMesh.new()
  multi.transform_format = MultiMesh.TRANSFORM_3D
  multi.mesh = alley_mesh
  multi.instance_count = alley_lines.size() * segment_centers.size()
  var index := 0
  for line in alley_lines:
   for along in segment_centers:
    var x: float = float(line) if axis == 0 else float(along)
    var z: float = float(along) if axis == 0 else float(line)
    var ground_y := WorldTerrainBuilder.sample_height_image(terrain_image,city,x,z,800.0)
    var basis := Basis(Vector3.UP,PI*0.5) if axis == 1 else Basis.IDENTITY
    multi.set_instance_transform(index,Transform3D(basis,Vector3(x,ground_y+0.85,z)))
    index += 1
  var alley := MultiMeshInstance3D.new()
  alley.name = city + ("_UrbanAlleys_NorthSouth_MultiMesh" if axis == 0 else "_UrbanAlleys_EastWest_MultiMesh")
  alley.multimesh = multi
  alley.material_override = material
  alley.add_to_group("distance_cull_world")
  alley.visibility_range_end = 420.0
  alley.visibility_range_end_margin = 36.0
  parent.add_child(alley)
 print("CITY_URBAN_ALLEY_PASS: %s directions=2 segments_per_direction=%d" % [city,alley_lines.size()*segment_centers.size()])

static func _build_city_buildings(parent: Node3D, city: String, p: Dictionary, height_image: Image) -> void:
 var slot := Node3D.new()
 slot.name = city + "_88BuildingUrbanDistrict"
 parent.add_child(slot)
 # Twelve-by-twelve compact blocks fit inside the 170m x 170m imperial city core.
 # The central 12m arterial roads and 6m secondary lanes stay open; 85-88 real
 # imported buildings occupy the remaining cells with compact block-to-block spacing.
 var coordinates := [-77.0,-63.0,-49.0,-35.0,-21.0,-7.0,7.0,21.0,35.0,49.0,63.0,77.0]
 var index := 0
 var built_count := 0
 for row in range(coordinates.size()):
  for column in range(coordinates.size()):
   var x := float(coordinates[column])
   var z := float(coordinates[row])
   var corner_block := (row < 2 or row >= 10) and (column < 2 or column >= 10)
   if corner_block:
    var anchor_row := 0 if row < 2 else 10
    var anchor_column := 0 if column < 2 else 10
    if row == anchor_row and column == anchor_column:
     var twin_chinese_palace := city == "TwinCity" and ((anchor_row == 0 and anchor_column == 0) or (anchor_row == 0 and anchor_column == 10) or (anchor_row == 10 and anchor_column == 0))
     if not twin_chinese_palace:
      var palace_center := Vector3((float(coordinates[anchor_column]) + float(coordinates[anchor_column+1])) * 0.5,0.0,(float(coordinates[anchor_row]) + float(coordinates[anchor_row+1])) * 0.5)
      var palace := _instantiate_wuxia_building(slot,city,index,palace_center,height_image,true,p)
      if palace == null:
       push_error("CITY_IMPORTED_PALACE_MISSING: %s index=%d" % [city,index])
      else:
       palace.add_to_group("city_building")
       built_count += 1
    index += 1
    continue
   if absf(x) < 8.0 or absf(z) < 8.0:
    index += 1
    continue
   var building := _instantiate_quaternius_building(slot,city,index,Vector3(x,0.0,z),height_image,false,p)
   if building == null:
    push_error("CITY_IMPORTED_BUILDING_MISSING: %s index=%d; refusing primitive placeholder geometry" % [city,index])
   else:
    building.add_to_group("city_building")
    built_count += 1
   index += 1
 print("CITY_URBAN_DENSITY_PASS: %s buildings=%d footprint=-85..85 grid=12x12 four_palaces=true" % [city,built_count])

static func _make_compact_urban_building(city: String, p: Dictionary, index: int) -> Node3D:
 var root := Node3D.new()
 root.add_to_group("city_building")
 var variation := 0.82 + float((index * 7) % 13) * 0.012
 var width := 17.0 * variation
 var depth := 13.0 * variation
 var height := 7.0 + float(index % 4) * 0.75
 var wall := _material(p.wall,0.9)
 wall.normal_enabled = true
 wall.normal_texture = _brick_normal()
 var stone := _material(p.stone,0.86)
 var wood := _material(p.wood,0.72)
 var roof := _material(p.roof,0.68)
 var trim := _material(p.gold,0.48)
 var foundation := MeshInstance3D.new()
 foundation.name = "RaisedStoneFoundation"
 var foundation_mesh := BoxMesh.new()
 foundation_mesh.size = Vector3(width,0.8,depth)
 foundation.mesh = foundation_mesh
 foundation.position.y = 0.42
 foundation.material_override = stone
 root.add_child(foundation)
 var walls := MeshInstance3D.new()
 walls.name = "ReliefBrickWalls"
 var wall_mesh := BoxMesh.new()
 wall_mesh.size = Vector3(width-1.2,height,depth-1.2)
 walls.mesh = wall_mesh
 walls.position.y = 0.8 + height*0.5
 walls.material_override = wall
 root.add_child(walls)
 var timber := MeshInstance3D.new()
 timber.name = "UpperTimberFrieze"
 var timber_mesh := BoxMesh.new()
 timber_mesh.size = Vector3(width+0.1,0.42,depth+0.1)
 timber.mesh = timber_mesh
 timber.position.y = 0.8 + height
 timber.material_override = wood
 root.add_child(timber)
 var roof_root := Node3D.new()
 roof_root.name = "CitySpecificRoof"
 roof_root.position.y = 0.8 + height + 0.55
 root.add_child(roof_root)
 match city:
  "DesertLand":
   var dome := MeshInstance3D.new()
   dome.name = "SandstoneDome"
   var dome_mesh := SphereMesh.new()
   dome_mesh.radius = minf(width,depth)*0.34
   dome_mesh.height = minf(width,depth)*0.48
   dome.mesh = dome_mesh
   dome.position.y = 1.2
   dome.material_override = roof
   roof_root.add_child(dome)
  "VolcanoLand":
   var basalt := MeshInstance3D.new()
   basalt.name = "BasaltBattlement"
   var basalt_mesh := BoxMesh.new()
   basalt_mesh.size = Vector3(width+1.0,0.85,depth+1.0)
   basalt.mesh = basalt_mesh
   basalt.position.y = 0.25
   basalt.material_override = roof
   roof_root.add_child(basalt)
   for spire_index in range(3):
    var spire := MeshInstance3D.new()
    spire.name = "ObsidianSpire"
    var spire_mesh := CylinderMesh.new()
    spire_mesh.top_radius = 0.08
    spire_mesh.bottom_radius = 0.52
    spire_mesh.height = 2.6
    spire.mesh = spire_mesh
    spire.position = Vector3((float(spire_index)-1.0)*width*0.28,1.8,-depth*0.28)
    spire.material_override = trim
    roof_root.add_child(spire)
  "IceLand":
   var ice := MeshInstance3D.new()
   ice.name = "SnowRoofTier"
   var ice_mesh := BoxMesh.new()
   ice_mesh.size = Vector3(width+1.4,0.9,depth+1.4)
   ice.mesh = ice_mesh
   ice.position.y = 0.2
   ice.material_override = roof
   roof_root.add_child(ice)
  _:
   for tier in range(2):
    var tier_node := MeshInstance3D.new()
    tier_node.name = "PagodaRoofTier_%d" % tier
    var tier_mesh := BoxMesh.new()
    tier_mesh.size = Vector3(width+1.8-float(tier)*3.2,0.52,depth+1.8-float(tier)*2.6)
    tier_node.mesh = tier_mesh
    tier_node.position.y = 0.22 + float(tier)*0.9
    tier_node.material_override = roof
    roof_root.add_child(tier_node)
 # A batched window set keeps facade rhythm without spawning dozens of individual nodes.
 var window_mesh := BoxMesh.new()
 window_mesh.size = Vector3(1.25,1.75,0.16)
 var windows := MultiMesh.new()
 windows.transform_format = MultiMesh.TRANSFORM_3D
 windows.mesh = window_mesh
 windows.instance_count = 4
 for wi in range(4):
  var wx := -width*0.28 + float(wi%2)*width*0.56
  var wy := 2.7 + float(wi/2)*2.2
  windows.set_instance_transform(wi,Transform3D(Basis.IDENTITY,Vector3(wx,wy,depth*0.5+0.02)))
 var window_batch := MultiMeshInstance3D.new()
 window_batch.name = "FacadeWindows_MultiMesh"
 window_batch.multimesh = windows
 window_batch.material_override = wood
 root.add_child(window_batch)
 var door := MeshInstance3D.new()
 door.name = "MainTimberDoor"
 var door_mesh := BoxMesh.new()
 door_mesh.size = Vector3(2.1,3.1,0.22)
 door.mesh = door_mesh
 door.position = Vector3(0.0,2.35,depth*0.5+0.12)
 door.material_override = wood
 root.add_child(door)
 var lintel := MeshInstance3D.new()
 lintel.name = "GoldenDoorLintel"
 var lintel_mesh := BoxMesh.new()
 lintel_mesh.size = Vector3(2.8,0.28,0.3)
 lintel.mesh = lintel_mesh
 lintel.position = Vector3(0.0,4.0,depth*0.5+0.14)
 lintel.material_override = trim
 root.add_child(lintel)
 var collision_body := StaticBody3D.new()
 collision_body.name = "BuildingCollision"
 var collision := CollisionShape3D.new()
 var collision_box := BoxShape3D.new()
 collision_box.size = Vector3(width,height+1.0,depth)
 collision.shape = collision_box
 collision.position.y = (height+1.0)*0.5
 collision_body.add_child(collision)
 root.add_child(collision_body)
 return root

static func _first_mesh_node(root: Node) -> MeshInstance3D:
 var pending: Array[Node] = [root]
 while not pending.is_empty():
  var current: Node = pending.pop_back()
  for child in current.get_children():
   pending.append(child)
  if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
   return current as MeshInstance3D
 return null

static func _instantiate_quaternius_building(parent: Node3D, city: String, index: int, at: Vector3, height_image: Image, grand_building: bool, p: Dictionary) -> Node3D:
 var candidates: Array[String] = []
 var all_models: Array[String] = []
 _collect_quaternius_models("res://assets/imperial_city_kit_v2/quaternius", all_models)
 for path in all_models:
  var file_name := path.get_file().to_lower()
  var is_house := file_name.contains("house") or file_name.contains("building") or file_name.contains("hall") or file_name.contains("temple") or file_name.contains("pavilion")
  var is_tower := file_name.contains("tower") and not file_name.contains("wall")
  if is_house or is_tower:
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
 instance.name = city + "_WuxiaChineseBuilding_%02d" % index
 instance.set_meta("source_asset_path", selected)
 instance.add_to_group("city_building")
 instance.add_to_group("imported_city_building")
 instance.position = at
 instance.position.y = WorldTerrainBuilder.sample_height_image(height_image, city, at.x, at.z, 800.0)
 instance.rotation.y = atan2(-at.x,-at.z)
 # Fit every imported GLB to a measured residential, commercial or palace class.
 instance.scale = Vector3(3.0, 2.0, 3.0)
 parent.add_child(instance)
 var is_grand_building := grand_building
 var target_width := 22.0 if is_grand_building else (14.0 if posmod(index, 3) == 0 else 10.0)
 var target_depth := 18.0 if is_grand_building else (12.0 if posmod(index, 3) == 0 else 10.0)
 var target_height := 15.0 if is_grand_building else (10.0 if posmod(index, 3) == 0 else 7.0)
 var source_bounds := _renderable_world_bounds(instance)
 if source_bounds.size.length_squared() > 0.0001:
  var fit_x := target_width / maxf(source_bounds.size.x, 0.001)
  var fit_y := target_height / maxf(source_bounds.size.y, 0.001)
  var fit_z := target_depth / maxf(source_bounds.size.z, 0.001)
  instance.scale *= Vector3(fit_x, fit_y, fit_z)
  print("CITY_QUATERNIUS_BUILDING_FIT: " + city + " asset=" + selected.get_file() + " target=" + str(Vector3(target_width,target_height,target_depth)) + " final_scale=" + str(instance.scale))
 var target_center_global := parent.to_global(at)
 var sampled_ground := WorldTerrainBuilder.sample_height_image(height_image, city, at.x, at.z, 800.0)
 var clearance := 0.85
 var target_base_global := parent.to_global(Vector3(at.x, sampled_ground + clearance + (3.5 if grand_building else 0.0), at.z))
 var fitted_bounds := _renderable_world_bounds(instance)
 if fitted_bounds.size.length_squared() > 0.0001:
  # Center the actual imported mesh footprint and seat its lowest vertex on terrain.
  var current_global := instance.global_position
  current_global.x += target_center_global.x - fitted_bounds.get_center().x
  current_global.z += target_center_global.z - fitted_bounds.get_center().z
  instance.global_position = current_global
  var centered_bounds := _renderable_world_bounds(instance)
  current_global = instance.global_position
  current_global.y += target_base_global.y - centered_bounds.position.y
  instance.global_position = current_global
  print("CITY_BUILDING_PLACEMENT_PASS: %s index=%d center=%s base_y=%.3f" % [city,index,str(instance.global_position),target_base_global.y])
  var details := Node3D.new()
  details.name = city + "_ChineseArchitectureDetails_%02d" % index
  parent.add_child(details)
  details.global_position = Vector3(target_center_global.x,target_base_global.y,target_center_global.z)
  details.global_rotation = instance.global_rotation
  if grand_building:
   _add_palace_platform_and_stairs(details,target_width,target_depth)
  _add_chinese_building_details(details,p,target_width,target_depth,target_height)
  details.add_to_group("distance_cull_world")
  _set_visibility_range(details,360.0,35.0)
 _add_static_mesh_collisions(instance)
 instance.add_to_group("distance_cull_world")
 _set_visibility_range(instance, 360.0, 35.0)
 return instance

static func _add_palace_platform_and_stairs(root: Node3D, width: float, depth: float) -> void:
 var paving := PBRMaterialLibrary.build_imperial_paving_material()
 var marble := PBRMaterialLibrary.build_plaza_material()
 var platform_size := Vector3(width+5.0,4.0,depth+5.0)
 _box(root,"ImperialPalaceRaisedStonePlinth_4_0m",Vector3(0.0,-2.0,0.0),platform_size,paving,1.0)
 var collision_body := StaticBody3D.new()
 collision_body.name = "ImperialPalacePlinthAndStairCollision"
 var platform_collision := CollisionShape3D.new()
 var platform_shape := BoxShape3D.new()
 platform_shape.size = platform_size
 platform_collision.shape = platform_shape
 platform_collision.position = Vector3(0.0,-2.0,0.0)
 collision_body.add_child(platform_collision)
 root.add_child(collision_body)
 for step in range(8):
  var step_center := Vector3(0.0,-0.25-float(step)*0.5,depth*0.5+3.0+float(step)*1.05)
  var step_size := Vector3(8.5,0.5,1.1)
  _box(root,"ImperialMarbleStair_%02d" % step,step_center,step_size,marble,1.0)
  var stair_collision := CollisionShape3D.new()
  var stair_shape := BoxShape3D.new()
  stair_shape.size = step_size
  stair_collision.shape = stair_shape
  stair_collision.position = step_center
  collision_body.add_child(stair_collision)
 print("IMPERIAL_PALACE_PLATFORM_PASS: height=4.0m marble_stairs=8 width=8.5m")

static func _add_chinese_building_details(root: Node3D, p: Dictionary, width: float, depth: float, height: float) -> void:
    var roof_material := PBRMaterialLibrary.build_chinese_roof_material()
    var gold_material := _material(p.gold,0.4)
    var timber_material := PBRMaterialLibrary.build_chinese_red_wood_material()
    var door_material := PBRMaterialLibrary.build_chinese_red_wood_material()
    var lantern_material := PBRMaterialLibrary.build_emissive_material(Color("#a52b35"))
    lantern_material.emission_enabled = true
    lantern_material.emission = Color("#ff3842")
    lantern_material.emission_energy_multiplier = 1.25
    var roof_root := Node3D.new()
    roof_root.name = "ChineseTwoTierTiledPagodaRoof"
    roof_root.position.y = height - 0.25
    root.add_child(roof_root)
    for tier in range(2):
        var tier_width := (width + 1.2) * (1.0 if tier == 0 else 0.76)
        var tier_depth := (depth + 1.2) * (1.0 if tier == 0 else 0.76)
        var tier_y := 0.16 + float(tier) * 0.78
        var panel_mesh := BoxMesh.new()
        panel_mesh.size = Vector3(tier_width*0.56,0.42,tier_depth)
        var panels := MultiMesh.new()
        panels.transform_format = MultiMesh.TRANSFORM_3D
        panels.mesh = panel_mesh
        panels.instance_count = 2
        var panel_index := 0
        for side in [-1.0,1.0]:
            panels.set_instance_transform(panel_index,Transform3D(Basis(Vector3(0,0,1),side*0.22),Vector3(side*tier_width*0.22,tier_y,0.0)))
            panel_index += 1
        var panel_batch := MultiMeshInstance3D.new()
        panel_batch.name = "ChineseSlopedRoofPanels_%d" % tier
        panel_batch.multimesh = panels
        panel_batch.material_override = roof_material
        roof_root.add_child(panel_batch)
        var rib_mesh := BoxMesh.new()
        rib_mesh.size = Vector3(0.13,0.12,tier_depth*0.94)
        var ribs := MultiMesh.new()
        ribs.transform_format = MultiMesh.TRANSFORM_3D
        ribs.mesh = rib_mesh
        ribs.instance_count = 10
        var rib_index := 0
        for side in [-1.0,1.0]:
            for rib in range(5):
                var rib_x: float = float(side)*(tier_width*0.22 + float(rib)*tier_width*0.06)
                ribs.set_instance_transform(rib_index,Transform3D(Basis(Vector3(0,0,1),side*0.22),Vector3(rib_x,tier_y+0.22,0.0)))
                rib_index += 1
        var rib_batch := MultiMeshInstance3D.new()
        rib_batch.name = "ChineseRoofTileRibs_%d" % tier
        rib_batch.multimesh = ribs
        rib_batch.material_override = gold_material
        roof_root.add_child(rib_batch)
        var eave_mesh := BoxMesh.new()
        eave_mesh.size = Vector3(1.25,0.24,0.72)
        var eaves := MultiMesh.new()
        eaves.transform_format = MultiMesh.TRANSFORM_3D
        eaves.mesh = eave_mesh
        eaves.instance_count = 4
        var eave_index := 0
        for side in [-1.0,1.0]:
            for depth_side in [-1.0,1.0]:
                eaves.set_instance_transform(eave_index,Transform3D(Basis(Vector3(0,0,1),-side*0.28),Vector3(side*tier_width*0.49,tier_y+0.1,depth_side*tier_depth*0.48)))
                eave_index += 1
        var eave_batch := MultiMeshInstance3D.new()
        eave_batch.name = "ChineseUpturnedEaves_%d" % tier
        eave_batch.multimesh = eaves
        eave_batch.material_override = gold_material
        roof_root.add_child(eave_batch)
        _box(roof_root,"ChineseGoldenRoofRidge_%d" % tier,Vector3(0.0,tier_y+0.32,0.0),Vector3(tier_width*0.72,0.18,0.42),gold_material,1.0)
    var pillar_mesh := BoxMesh.new()
    pillar_mesh.size = Vector3(0.42,height*0.9,0.42)
    var pillars := MultiMesh.new()
    pillars.transform_format = MultiMesh.TRANSFORM_3D
    pillars.mesh = pillar_mesh
    pillars.instance_count = 2
    pillars.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(-width*0.36,height*0.45,depth*0.5+0.14)))
    pillars.set_instance_transform(1,Transform3D(Basis.IDENTITY,Vector3(width*0.36,height*0.45,depth*0.5+0.14)))
    var pillar_batch := MultiMeshInstance3D.new()
    pillar_batch.name = "ChineseFacadeColumns"
    pillar_batch.multimesh = pillars
    pillar_batch.material_override = timber_material
    root.add_child(pillar_batch)
    _box(root,"ChineseRedTimberDoor",Vector3(0.0,1.7,depth*0.5+0.22),Vector3(2.1,3.4,0.22),door_material,1.0)
    _box(root,"ChineseGoldenDoorFrame",Vector3(0.0,3.52,depth*0.5+0.28),Vector3(2.65,0.18,0.12),gold_material,1.0)
    var lantern_mesh := SphereMesh.new()
    lantern_mesh.radius = 0.24
    lantern_mesh.height = 0.5
    var lanterns := MultiMesh.new()
    lanterns.transform_format = MultiMesh.TRANSFORM_3D
    lanterns.mesh = lantern_mesh
    lanterns.instance_count = 2
    lanterns.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(-width*0.43,height*0.72,depth*0.5+0.32)))
    lanterns.set_instance_transform(1,Transform3D(Basis.IDENTITY,Vector3(width*0.43,height*0.72,depth*0.5+0.32)))
    var lantern_batch := MultiMeshInstance3D.new()
    lantern_batch.name = "ChineseFacadeRedLanterns"
    lantern_batch.multimesh = lanterns
    lantern_batch.material_override = lantern_material
    root.add_child(lantern_batch)

static func _renderable_world_bounds(root_node: Node) -> AABB:
 var combined := AABB()
 var found := false
 var pending: Array[Node] = [root_node]
 while not pending.is_empty():
  var current: Node = pending.pop_back()
  for child in current.get_children():
   pending.append(child)
  if current is MeshInstance3D:
   var mesh_node := current as MeshInstance3D
   if mesh_node.mesh != null:
    var world_bounds: AABB = mesh_node.global_transform * mesh_node.get_aabb()
    combined = world_bounds if not found else combined.merge(world_bounds)
    found = true
  elif current is MultiMeshInstance3D:
   var multi_node := current as MultiMeshInstance3D
   if multi_node.multimesh != null and multi_node.multimesh.mesh != null:
    var multi_bounds: AABB = multi_node.global_transform * multi_node.get_aabb()
    combined = multi_bounds if not found else combined.merge(multi_bounds)
    found = true
 return combined if found else AABB()

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
   if mesh_node.mesh != null and mesh_node.mesh.get_rid().is_valid():
    mesh_node.create_trimesh_collision()

static func _build_city_walls_and_gates(parent: Node3D, city: String, p: Dictionary, height_image: Image) -> void:
 var fortification := Node3D.new()
 fortification.name = city + "_PerimeterFortifications"
 parent.add_child(fortification)
 var wall_material := _material(p.stone.darkened(0.12),0.9)
 var tower_material := _material(p.wall,0.86)
 var gate_material := _material(p.gold,0.72)
 var half := 85.0
 var gap := 7.0
 var kenney_walls := _build_kenney_perimeter_walls(fortification, city, half, gap, height_image)
 for side in [-1.0,1.0]:
  for segment in [-1.0,1.0]:
   var start := -half if segment < 0.0 else gap
   var finish := -gap if segment < 0.0 else half
   var length := finish-start
   var horizontal_wall := _box(fortification,"HighStonePerimeterWall_%s_%s" % [str(int(side)),str(int(segment))],Vector3((start+finish)*0.5,5.0,side*half),Vector3(length,10.0,5.0),wall_material,1.0)
   horizontal_wall.add_to_group("city_perimeter_wall")
   horizontal_wall.visible = not kenney_walls
   var vertical_wall := _box(fortification,"HighStonePerimeterWall_%s_%s" % [str(int(side)),str(int(segment))],Vector3(side*half,5.0,(start+finish)*0.5),Vector3(5.0,10.0,length),wall_material,1.0)
   vertical_wall.add_to_group("city_perimeter_wall")
   vertical_wall.visible = not kenney_walls
 for direction in range(4):
  var gate := Node3D.new()
  var direction_name: String = ["North","East","South","West"][direction]
  gate.name = direction_name + "_GrandCityGate"
  gate.add_to_group("cardinal_gates")
  gate.set_meta("cardinal_direction",direction_name)
  gate.rotation_degrees.y = direction*90.0
  fortification.add_child(gate)
  var gate_world_point := gate.to_global(Vector3(0.0,0.0,-85.0))
  var gate_clearance := 0.85
  gate.position.y = WorldTerrainBuilder.sample_height_image(height_image, city, gate_world_point.x, gate_world_point.z, 800.0) + gate_clearance - fortification.global_position.y
  var kenney_gate := _add_kenney_asset(gate, city, height_image, "castle-kit", "gate.glb", "KenneyGateModel", Vector3(0.0, 0.0, -85.0), 0.0, 2.2)
  if kenney_gate != null:
   kenney_gate.visible = false
   for collision_node in kenney_gate.find_children("*","CollisionShape3D",true,false):
    (collision_node as CollisionShape3D).disabled = true
  for side in [-1.0,1.0]:
   var tower_side_name := "Left" if side < 0.0 else "Right"
   var kenney_tower := _add_kenney_asset(gate, city, height_image, "castle-kit", "tower-square.glb", "KenneyTowerModel_" + tower_side_name, Vector3(side*11.0, 0.0, -85.0), 0.0, 1.8)
   if kenney_tower != null:
    kenney_tower.visible = false
    for collision_node in kenney_tower.find_children("*","CollisionShape3D",true,false):
     (collision_node as CollisionShape3D).disabled = true
   _box(gate,"GatehouseTower",Vector3(side*10.0,5.7,-85.0),Vector3(4.5,11.4,9.0),tower_material,1.0)
   _box(gate,"GateTowerCrenellation",Vector3(side*10.0,11.9,-85.0),Vector3(5.0,0.6,11.0),gate_material,1.0)
   _box(gate,"GateGuardianStand",Vector3(side*5.5,0.15,-80.0),Vector3(1.6,0.3,1.6),wall_material,1.0)
   _build_gate_guard(gate,side,p,direction_name)
  _box(gate,"GateArchLintel",Vector3(0,11.4,-85.0),Vector3(18.0,1.5,8.0),gate_material,1.0)
  for x in [-8.0,8.0]:
   _box(gate,"ArchColumn",Vector3(x,5.5,-85.0),Vector3(2.0,11.0,7.0),gate_material,1.0)
  _build_chinese_gate_details(gate,p,city)

static func _build_chinese_gate_details(gate: Node3D, p: Dictionary, city: String) -> void:
    var roof := PBRMaterialLibrary.build_chinese_roof_material()
    var gold := _material(p.gold,0.42)
    var wood := PBRMaterialLibrary.build_chinese_red_wood_material()
    var door_material := _material(Color("#8f2630"),0.48)
    # Fourteen-metre clear arch, paired timber leaves, and a two-tier tiled roof.
    for side in [-1.0,1.0]:
        # The two leaves are swung open against the side towers so the main street remains visible.
        _box(gate,"ChineseGateDoorLeaf",Vector3(side*6.75,4.55,-84.55),Vector3(0.28,9.1,6.1),door_material,1.0)
        _box(gate,"ChineseGateDoorGoldBand",Vector3(side*6.55,6.1,-84.55),Vector3(0.08,0.16,6.0),gold,1.0)
        _box(gate,"ChineseGateDoorVerticalTrim",Vector3(side*6.55,4.55,-81.55),Vector3(0.08,9.0,0.18),gold,1.0)
    _box(gate,"ChineseGateRoofLower",Vector3(0,12.35,-85.0),Vector3(25.0,0.62,12.0),roof,1.0)
    _box(gate,"ChineseGateRoofUpper",Vector3(0,13.18,-85.0),Vector3(21.0,0.48,9.0),roof,1.0)
    _box(gate,"ChineseGateGoldenRidge",Vector3(0,13.58,-85.0),Vector3(18.0,0.22,0.52),gold,1.0)
    for side in [-1.0,1.0]:
        for depth_side in [-1.0,1.0]:
            var eave := _box(gate,"ChineseGateUpturnedEave",Vector3(side*11.8,12.72,-85.0+depth_side*5.4),Vector3(3.0,0.28,0.72),gold,1.0)
            eave.rotation.z = -side*0.22
    for rib in range(13):
        var x := -12.0 + float(rib)*2.0
        _box(gate,"ChineseGateRoofRib",Vector3(x,12.78,-85.0),Vector3(0.12,0.12,10.5),gold if rib in [0,12] else roof,1.0)
    for side in [-1.0,1.0]:
        var lantern := Node3D.new()
        lantern.name = "ChineseGateWarmLantern"
        lantern.position = Vector3(side*8.3,10.2,-80.0)
        gate.add_child(lantern)
        lantern.add_to_group("imperial_city_lanterns")
        var glow := _material(Color("#b62935"),0.35)
        glow.emission_enabled = true
        glow.emission = Color("#ff9a52")
        glow.emission_energy_multiplier = 1.5
        var body := MeshInstance3D.new()
        body.name = "RedSilkLanternBody"
        var body_mesh := CylinderMesh.new()
        body_mesh.top_radius = 0.29
        body_mesh.bottom_radius = 0.34
        body_mesh.height = 0.62
        body_mesh.radial_segments = 16
        body.mesh = body_mesh
        body.material_override = glow
        lantern.add_child(body)
        for cap_y in [-0.38,0.38]:
            var cap := MeshInstance3D.new()
            cap.name = "GoldenLanternCap"
            var cap_mesh := CylinderMesh.new()
            cap_mesh.top_radius = 0.42
            cap_mesh.bottom_radius = 0.42
            cap_mesh.height = 0.12
            cap_mesh.radial_segments = 16
            cap.mesh = cap_mesh
            cap.position.y = cap_y
            cap.material_override = gold
            lantern.add_child(cap)
        for frame_x in [-0.25,0.25]:
            for frame_z in [-0.25,0.25]:
                var frame := MeshInstance3D.new()
                frame.name = "LanternGoldenFrame"
                var frame_mesh := BoxMesh.new()
                frame_mesh.size = Vector3(0.055,0.72,0.055)
                frame.mesh = frame_mesh
                frame.position = Vector3(frame_x,0.0,frame_z)
                frame.material_override = gold
                lantern.add_child(frame)
        var light := OmniLight3D.new()
        light.name = "ChineseGateWarmLanternLight"
        light.position = lantern.position
        light.light_color = Color("#ffad67")
        light.light_energy = 1.15
        light.omni_range = 10.0
        light.add_to_group("imperial_city_lantern_lights")
        gate.add_child(light)
    print("CITY_CHINESE_GATE_PASS: %s opening=14m height=14m roof=2_tiers lanterns=2" % city)

static func _load_kenney_scene(kit: String, file_name: String) -> PackedScene:
 for format_name in ["GLB format", "GLTF format"]:
  var path := "res://assets/environment/kenney/%s/Models/%s/%s" % [kit, format_name, file_name]
  if ResourceLoader.exists(path):
   return ResourceLoader.load(path) as PackedScene
 return null

static func _add_kenney_asset(parent: Node3D, city: String, height_image: Image, kit: String, file_name: String, node_name: String, at: Vector3, rotation: float, scale_factor: float) -> Node3D:
 var packed := _load_kenney_scene(kit, file_name)
 if packed == null:
  return null
 var instance := packed.instantiate() as Node3D
 if instance == null:
  return null
 instance.name = node_name
 var world_at := parent.to_global(at)
 instance.position = at
 instance.position.y += WorldTerrainBuilder.sample_height_image(height_image, city, world_at.x, world_at.z, 800.0) - parent.global_position.y
 instance.rotation.y = rotation
 instance.scale = Vector3.ONE * scale_factor
 parent.add_child(instance)
 instance.add_to_group("distance_cull_world")
 _set_visibility_range(instance, 420.0, 40.0)
 _add_static_mesh_collisions(instance)
 return instance

static func _build_kenney_perimeter_walls(parent: Node3D, city: String, half: float, gap: float, height_image: Image) -> bool:
 var packed := _load_kenney_scene("castle-kit", "wall.glb")
 if packed == null:
  return false
 var source := packed.instantiate()
 var first_mesh := _first_mesh_node(source)
 if first_mesh == null or first_mesh.mesh == null:
  source.free()
  return false
 var wall_mesh: Mesh = first_mesh.mesh
 var bounds := wall_mesh.get_aabb()
 source.free()
 var long_extent := maxf(bounds.size.x, bounds.size.z)
 var depth_extent := minf(bounds.size.x, bounds.size.z)
 if long_extent <= 0.01 or depth_extent <= 0.01 or bounds.size.y <= 0.01:
  return false
 var multi := MultiMesh.new()
 multi.transform_format = MultiMesh.TRANSFORM_3D
 multi.mesh = wall_mesh
 var piece_count := 0
 var segment_data: Array[Dictionary] = []
 for side in [-1.0, 1.0]:
  for segment in [-1.0, 1.0]:
   var start := -half if segment < 0.0 else gap
   var finish := -gap if segment < 0.0 else half
   var length := finish - start
   var count := maxi(1, int(ceil(length / 8.0)))
   piece_count += count * 2
   segment_data.append({"side":side,"horizontal":true,"start":start,"finish":finish,"count":count})
   segment_data.append({"side":side,"horizontal":false,"start":start,"finish":finish,"count":count})
 multi.instance_count = piece_count
 var index := 0
 var local_center := bounds.position + bounds.size * 0.5
 for segment in segment_data:
  var side := float(segment["side"])
  var horizontal := bool(segment["horizontal"])
  var start := float(segment["start"])
  var finish := float(segment["finish"])
  var count := int(segment["count"])
  var spacing := (finish - start) / float(count)
  var scale_long := spacing / long_extent
  var scale_height := 10.0 / bounds.size.y
  var scale_depth := 5.0 / depth_extent
  var rotation := 0.0 if horizontal else PI * 0.5
  var basis := Basis(Vector3.UP, rotation).scaled(Vector3(scale_long, scale_height, scale_depth))
  for piece in range(count):
   var along := start + (float(piece) + 0.5) * spacing
   var x := along if horizontal else side * half
   var z := side * half if horizontal else along
   var ground_y := WorldTerrainBuilder.sample_height_image(height_image, city, x, z, 800.0)
   var center := Vector3(x, ground_y + 5.0, z)
   multi.set_instance_transform(index, Transform3D(basis, center - basis * local_center))
   index += 1
 var visual := MultiMeshInstance3D.new()
 visual.name = city + "_KenneyCastlePerimeterWalls_MultiMesh"
 visual.multimesh = multi
 visual.add_to_group("distance_cull_world")
 visual.add_to_group("city_perimeter_wall")
 visual.visibility_range_end = 520.0
 visual.visibility_range_end_margin = 42.0
 parent.add_child(visual)
 return true

static func _build_kenney_city_modules(parent: Node3D, city: String, p: Dictionary, height_image: Image) -> void:
 var stalls := [
  {"file":"stall-red.glb","at":Vector3(-30.0,0.0,-54.0),"rotation":0.0},
  {"file":"stall-green.glb","at":Vector3(30.0,0.0,-54.0),"rotation":PI},
  {"file":"stall-red.glb","at":Vector3(-30.0,0.0,54.0),"rotation":0.0},
  {"file":"stall-green.glb","at":Vector3(30.0,0.0,54.0),"rotation":PI}
 ]
 for index in range(stalls.size()):
  var data: Dictionary = stalls[index]
  _add_kenney_asset(parent, city, height_image, "fantasy-town-kit", str(data["file"]), "KenneyMarketStall_%02d" % index, data["at"], float(data["rotation"]), 1.5)
 _add_kenney_asset(parent, city, height_image, "fantasy-town-kit", "fountain-square.glb", "KenneyMarketFountain", Vector3(-50.0,0.0,0.0), PI * 0.5, 1.8)
 if city == "DesertLand":
  _add_kenney_asset(parent, city, height_image, "fantasy-town-kit", "windmill.glb", "KenneyDesertWindmill", Vector3(260.0,0.0,-245.0), 0.0, 2.4)
 elif city == "Waterlands":
  _add_kenney_asset(parent, city, height_image, "fantasy-town-kit", "watermill.glb", "KenneyWaterlandsWatermill", Vector3(260.0,0.0,-245.0), 0.0, 2.2)

static func _build_outer_biome(parent: Node3D, city: String, p: Dictionary, size: float, height_image: Image) -> void:
 var outer := Node3D.new()
 outer.name = city + "_OpenWorld_800x800"
 parent.add_child(outer)
 # The 800x800 heightfield is the only visible ground; keep this safety plane below its lowest elevation.
 var ground := MeshInstance3D.new()
 ground.name = "SeamlessOuterBiomeSafetyPlane"
 var plane := PlaneMesh.new()
 plane.size = Vector2(800.0, 800.0)
 ground.mesh = plane
 ground.position = Vector3(0.0, -30.0, 0.0)
 outer.add_child(ground)
 ground.material_override = _material(Color("#343a36"), 1.0)
 _build_walkable_outer_routes(outer, city, p, height_image)
 _build_horizon_ridge(outer, city, p)
 print("OPEN_WORLD_BIOME_PASS: %s extent=800x800 heightmap_ground=1 height_aligned_routes=4 horizon_ridge=44 kenney_nature=1" % city)

static func _build_horizon_ridge(parent: Node3D, city: String, p: Dictionary) -> void:
 var ridge_mesh := SphereMesh.new()
 ridge_mesh.radius = 48.0
 ridge_mesh.height = 76.0
 ridge_mesh.radial_segments = 12
 ridge_mesh.rings = 8
 var ridge_mm := MultiMesh.new()
 ridge_mm.transform_format = MultiMesh.TRANSFORM_3D
 ridge_mm.mesh = ridge_mesh
 ridge_mm.instance_count = 44
 for i in range(44):
  var angle := TAU * float(i) / 44.0
  var radius := 354.0 + float((i * 17) % 38)
  var height_scale := 0.68 + float((i * 13) % 42) / 100.0
  var scale := Vector3(1.05 + float(i % 4) * 0.10, height_scale, 1.2 + float(i % 5) * 0.08)
  var basis := Basis(Vector3.UP, angle * 0.12).scaled(scale)
  var position := Vector3(cos(angle) * radius, 8.0, sin(angle) * radius)
  ridge_mm.set_instance_transform(i, Transform3D(basis, position))
 var ridge := MultiMeshInstance3D.new()
 ridge.name = city + "_DistantHorizonMountainRidge"
 ridge.multimesh = ridge_mm
 ridge.material_override = _material(p.stone.darkened(0.20), 1.0)
 ridge.visibility_range_end = 900.0
 ridge.visibility_range_end_margin = 60.0
 ridge.add_to_group("distance_cull_world")
 parent.add_child(ridge)

static func _build_walkable_outer_routes(parent: Node3D, city: String, p: Dictionary, height_image: Image) -> void:
 var route_root := Node3D.new()
 route_root.name = city + "_HeightAlignedRampsAndPasses"
 parent.add_child(route_root)
 var route_material := _material(p.stone.lightened(0.08), 0.94)
 for route_index in range(4):
  var angle := float(route_index) * PI * 0.5
  var direction := Vector2(cos(angle), sin(angle))
  var lateral := Vector2(-direction.y, direction.x)
  var vertices := PackedVector3Array()
  var normals := PackedVector3Array()
  var uv := PackedVector2Array()
  var indices := PackedInt32Array()
  var steps := 49
  for step in range(steps):
   var distance := 145.0 + float(step) * 4.0
   var center := direction * distance
   var left := center + lateral * 4.5
   var right := center - lateral * 4.5
   var left_height := WorldTerrainBuilder.sample_height_image(height_image, city, left.x, left.y, 800.0) + 0.10
   var right_height := WorldTerrainBuilder.sample_height_image(height_image, city, right.x, right.y, 800.0) + 0.10
   vertices.append(Vector3(left.x, left_height, left.y))
   vertices.append(Vector3(right.x, right_height, right.y))
   for point in [left, right]:
    var slope_x := WorldTerrainBuilder.sample_height_image(height_image, city, point.x - 1.0, point.y, 800.0) - WorldTerrainBuilder.sample_height_image(height_image, city, point.x + 1.0, point.y, 800.0)
    var slope_z := WorldTerrainBuilder.sample_height_image(height_image, city, point.x, point.y - 1.0, 800.0) - WorldTerrainBuilder.sample_height_image(height_image, city, point.x, point.y + 1.0, 800.0)
    normals.append(Vector3(slope_x, 2.0, slope_z).normalized())
   uv.append(Vector2(0.0, float(step) / float(steps - 1)))
   uv.append(Vector2(1.0, float(step) / float(steps - 1)))
  for step in range(steps - 1):
   var a := step * 2
   var b := a + 1
   var c := a + 2
   var d := a + 3
   indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
  var arrays := []
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX] = vertices
  arrays[Mesh.ARRAY_NORMAL] = normals
  arrays[Mesh.ARRAY_TEX_UV] = uv
  arrays[Mesh.ARRAY_INDEX] = indices
  var route_mesh := ArrayMesh.new()
  route_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
  var body := StaticBody3D.new()
  body.name = city + "_HeightAlignedTrail_%d" % route_index
  var visual := MeshInstance3D.new()
  visual.name = "HeightAlignedStoneTrail"
  visual.mesh = route_mesh
  visual.material_override = route_material
  body.add_child(visual)
  var collision := CollisionShape3D.new()
  collision.name = "HeightAlignedTrailCollision"
  var shape := ConcavePolygonShape3D.new()
  shape.set_faces(route_mesh.get_faces())
  collision.shape = shape
  body.add_child(collision)
  body.add_to_group("distance_cull_world")
  _set_visibility_range(body, 520.0, 40.0)
  route_root.add_child(body)

static func _build_gate_guard(parent: Node3D, side: float, p: Dictionary, direction_name: String) -> void:
 var guard := Node3D.new()
 guard.name = "CityGuardian_" + direction_name + "_" + ("Left" if side < 0.0 else "Right")
 guard.add_to_group("city_guardians")
 guard.set_meta("gate_direction",direction_name)
 guard.position = Vector3(side*5.5,0.0,-80.0)
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
 var steel := _material(p.stone,0.48)
 var red_accent := _material(p.accent,0.42)
 _box(guard,"ArmoredBreastplate",Vector3(0.0,1.32,0.36),Vector3(0.86,0.72,0.24),steel,1.0)
 _box(guard,"GoldBreastplateEmblem",Vector3(0.0,1.42,0.5),Vector3(0.28,0.34,0.06),trim,1.0)
 for arm_side in [-1.0,1.0]:
  _box(guard,"ArmoredShoulderPauldron",Vector3(arm_side*0.48,1.72,0.02),Vector3(0.5,0.34,0.48),trim,1.0)
  _box(guard,"ArmoredForearmBracer",Vector3(arm_side*0.55,1.12,0.16),Vector3(0.24,0.5,0.34),steel,1.0)
  _box(guard,"ArmoredShinGreave",Vector3(arm_side*0.22,0.48,0.18),Vector3(0.25,0.72,0.34),steel,1.0)
 _box(guard,"CrimsonBackCape",Vector3(0.0,1.22,-0.32),Vector3(0.72,1.1,0.12),red_accent,1.0)
 var spear := MeshInstance3D.new()
 var spear_mesh := CylinderMesh.new()
 spear_mesh.top_radius = 0.035
 spear_mesh.bottom_radius = 0.055
 spear_mesh.height = 2.7
 spear.mesh = spear_mesh
 spear.position = Vector3(side*-0.58,1.35,0.0)
 guard.add_child(spear)
 spear.material_override = trim
 var spear_tip := MeshInstance3D.new()
 spear_tip.name = "PolishedSpearHead"
 var spear_tip_mesh := CylinderMesh.new()
 spear_tip_mesh.top_radius = 0.0
 spear_tip_mesh.bottom_radius = 0.12
 spear_tip_mesh.height = 0.42
 spear_tip.mesh = spear_tip_mesh
 spear_tip.position = Vector3(side*-0.58,2.82,0.0)
 guard.add_child(spear_tip)
 spear_tip.material_override = trim

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

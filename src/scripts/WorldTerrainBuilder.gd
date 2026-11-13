extends Node3D
## Builds scalable heightfield terrain and hard safety bounds. All collision stays static.
const PBRMaterialLibrary = preload("res://src/scripts/PBRMaterialLibrary.gd")
const CityStreetDressing = preload("res://src/scripts/CityStreetDressing.gd")
const CITY_SIZE := {"TwinCity":800.0,"DesertLand":800.0,"VolcanoLand":800.0,"IceLand":800.0,"Waterlands":800.0,"DarkForest":800.0}
const HEIGHTS := {
 "TwinCity":"", "DesertLand":"res://assets/environment/heightmaps/04_desert_dunes_heightmap_16bit.png",
 "VolcanoLand":"res://assets/environment/heightmaps/01_volcanic_caldera_heightmap_16bit.png",
 "IceLand":"res://assets/environment/heightmaps/02_glacial_mountains_heightmap_16bit.png",
 "Waterlands":"res://assets/environment/heightmaps/03_tropical_archipelago_heightmap_16bit.png",
 "DarkForest":"res://assets/environment/heightmaps/05_dark_forest_valleys_heightmap_16bit.png"}
const COLORS := {"TwinCity":Color("#6c9849"),"DesertLand":Color("#b58a4e"),"VolcanoLand":Color("#393437"),"IceLand":Color("#b9d9e8"),"Waterlands":Color("#3a9e91"),"DarkForest":Color("#294b32")}
const MATERIALS := {"TwinCity":"Ground044_2K-JPG","DesertLand":"Ground061_2K-JPG","VolcanoLand":"Rock027_2K-JPG","IceLand":"Snow008C_2K-JPG","Waterlands":"Ground044_2K-JPG","DarkForest":"Ground053_2K-JPG"}
const HEIGHT_AMPLITUDE := {"TwinCity":0.0,"DesertLand":30.0,"VolcanoLand":40.0,"IceLand":44.0,"Waterlands":22.0,"DarkForest":32.0}
static func build(parent: Node3D, city: String, slot: Node3D) -> void:
 var size: float = CITY_SIZE.get(city,450.0)
 var mesh := _height_mesh(city,size)
 var body := StaticBody3D.new()
 body.name = "TerrainCollision"
 var visual := MeshInstance3D.new()
 visual.name = "TerrainSurface"
 visual.mesh = mesh
 body.add_child(visual)
 visual.material_override = PBRMaterialLibrary.build_ground_material(city, true, "Ground053_2K-JPG" if city == "TwinCity" else "")
 var collision := CollisionShape3D.new()
 collision.name = "TerrainSurfaceCollision"
 # Match the terrain grid with a dedicated heightmap collider; this avoids
 # unstable concave face buffers on headless physics backends.
 var terrain_arrays := mesh.surface_get_arrays(0)
 var terrain_vertices: PackedVector3Array = terrain_arrays[Mesh.ARRAY_VERTEX]
 var height_shape := HeightMapShape3D.new()
 var terrain_resolution := 129
 height_shape.map_width = terrain_resolution
 height_shape.map_depth = terrain_resolution
 collision.scale = Vector3(size / float(terrain_resolution - 1), 1.0, size / float(terrain_resolution - 1))
 var height_samples := PackedFloat32Array()
 height_samples.resize(terrain_resolution * terrain_resolution)
 for sample_index in range(mini(height_samples.size(), terrain_vertices.size())):
  height_samples[sample_index] = terrain_vertices[sample_index].y
 height_shape.map_data = height_samples
 collision.shape = height_shape
 body.add_child(collision)
 parent.add_child(body)
 if city == "TwinCity":
  _build_flat_twin_city_plaza(parent)
 _build_navigation_region(parent, mesh)
 _bounds(parent,size,city)
 CityStreetDressing.build(slot, city, size)
 if city == "Waterlands":
  _build_water_surface(slot, size)
 _build_imperial_tree_multimesh(slot, city, size)
static func load_height_image(city: String) -> Image:
 var path: String = HEIGHTS.get(city, "")
 if path.is_empty():
  return null
 var texture := ResourceLoader.load(path) as Texture2D
 return texture.get_image() if texture != null else null

static func height_at(city: String, x: float, z: float) -> float:
 return sample_height_image(load_height_image(city), city, x, z, float(CITY_SIZE.get(city, 800.0)))

static func sample_height_image(image: Image, city: String, x: float, z: float, size: float) -> float:
 if image == null:
  return 0.0
 var u := clampf(x / size + 0.5, 0.0, 1.0)
 var v := clampf(z / size + 0.5, 0.0, 1.0)
 var ix := int(round(u * float(image.get_width() - 1)))
 var iz := int(round(v * float(image.get_height() - 1)))
 var height := (image.get_pixel(ix, iz).r - 0.5) * float(HEIGHT_AMPLITUDE.get(city, 28.0))
 if absf(x) < 75.0 and absf(z) < 75.0:
  height = lerpf(height, 0.0, 0.94)
 return height

static func _height_mesh(city: String,size: float) -> ArrayMesh:
 var path: String = HEIGHTS.get(city,"")
 var image: Image = null
 if path != "" and ResourceLoader.exists(path):
  var height_texture := ResourceLoader.load(path) as Texture2D
  if height_texture != null:
   image = height_texture.get_image()
  if image == null:
   push_error("Heightmap texture could not be loaded as an imported resource: " + path)
 elif path != "":
  push_error("Required terrain heightmap resource is missing: " + path)
 var resolution := 129
 var verts := PackedVector3Array()
 var uv := PackedVector2Array()
 var indices := PackedInt32Array()
 for z in range(resolution):
  for x in range(resolution):
   var h := 0.0
   if image != null:
    var ix := int(float(x)*(image.get_width()-1)/(resolution-1))
    var iz := int(float(z)*(image.get_height()-1)/(resolution-1))
    h = (image.get_pixel(ix,iz).r-0.5)*float(HEIGHT_AMPLITUDE.get(city,28.0))
   # Flatten the central 150m combat/market district.
   var px := (float(x)/(resolution-1)-0.5)*size
   var pz := (float(z)/(resolution-1)-0.5)*size
   if absf(px)<75.0 and absf(pz)<75.0: h = lerpf(h,0.0,0.94)
   verts.append(Vector3(px,h,pz)); uv.append(Vector2(float(x)/(resolution-1),float(z)/(resolution-1)))
 for z in range(resolution-1):
  for x in range(resolution-1):
   var a=z*resolution+x; var b=a+1; var c=a+resolution; var d=c+1
   indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
 var arrays=[]; arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=verts; arrays[Mesh.ARRAY_TEX_UV]=uv; arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); return mesh
static func _build_water_surface(parent: Node3D, size: float) -> void:
 var ocean := MeshInstance3D.new()
 ocean.name = "Waterlands_ArchipelagoWaterSurface"
 var plane := PlaneMesh.new()
 plane.size = Vector2(size, size)
 ocean.mesh = plane
 ocean.position.y = -3.2
 var material := StandardMaterial3D.new()
 material.albedo_color = Color("#176b82")
 material.roughness = 0.22
 material.metallic = 0.12
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 ocean.material_override = material
 ocean.add_to_group("distance_cull_world")
 ocean.visibility_range_end = 620.0
 ocean.visibility_range_end_margin = 50.0
 parent.add_child(ocean)

static func _build_navigation_region(parent: Node3D, terrain_mesh: ArrayMesh) -> void:
 var arrays := terrain_mesh.surface_get_arrays(0)
 if arrays.is_empty():
  push_error("Terrain navigation could not read the heightfield vertex arrays.")
  return
 var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
 var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
 if vertices.is_empty() or indices.is_empty():
  push_error("Terrain navigation heightfield has no vertices or triangles.")
  return
 var nav_mesh := NavigationMesh.new()
 nav_mesh.agent_height = 1.8
 nav_mesh.agent_radius = 0.45
 nav_mesh.agent_max_slope = 42.0
 nav_mesh.cell_size = 1.0
 nav_mesh.cell_height = 0.25
 nav_mesh.vertices = vertices
 for index in range(0, indices.size(), 3):
  nav_mesh.add_polygon(PackedInt32Array([indices[index], indices[index + 1], indices[index + 2]]))
 var region := NavigationRegion3D.new()
 region.name = "TerrainNavigationRegion"
 region.navigation_layers = 1
 region.navigation_mesh = nav_mesh
 parent.add_child(region)
 print("TERRAIN_NAVMESH_READY: polygons=%d vertices=%d" % [nav_mesh.get_polygon_count(), vertices.size()])

static func _bounds(parent: Node3D,size: float,city: String) -> void:
 var edge := size * 0.497
 for i in range(4):
  var wall:=StaticBody3D.new(); wall.name="WorldBoundary_%d"%i
  var cs:=CollisionShape3D.new(); var box:=BoxShape3D.new()
  box.size=Vector3(edge*2.0,40.0,2.0) if i<2 else Vector3(2.0,40.0,edge*2.0)
  cs.shape=box
  var offset:=Vector3(0,18.0,-edge) if i==0 else (Vector3(0,18.0,edge) if i==1 else (Vector3(-edge,18.0,0) if i==2 else Vector3(edge,18.0,0)))
  wall.position=offset; wall.add_child(cs); parent.add_child(wall)
static func _roads(slot: Node3D,size: float,city: String) -> void:
 if city!="TwinCity": return
 for i in range(4):
  var road:=MeshInstance3D.new()
  var plane:=PlaneMesh.new()
  plane.size=Vector2(12.0,size*0.46)
  road.mesh=plane
  road.rotation_degrees.y=i*90.0
  road.position=Vector3(0,0.035,0)
  road.material_override=_stone_material()
  slot.add_child(road)

static func _add_scene_mesh_collisions(root: Node) -> void:
 var stack: Array[Node] = [root]
 while not stack.is_empty():
  var node: Node = stack.pop_back()
  for child in node.get_children(): stack.append(child)
  if node is MeshInstance3D:
   var mesh_node := node as MeshInstance3D
   if mesh_node.mesh != null and mesh_node.mesh.get_rid().is_valid():
    mesh_node.create_trimesh_collision()

static func _build_imperial_tree_multimesh(parent: Node3D, city: String, size: float) -> void:
 var height_image: Image = load_height_image(city)
 var candidates: Array[String] = []
 _collect_kenney_nature_models("res://assets/wuxia_imperial_pack/props_nature", candidates)
 var tree_candidates: Array[String] = []
 for path in candidates:
  var label := path.get_file().to_lower()
  if (label.contains("tree") or label.contains("pine") or label.contains("willow") or label.contains("palm") or label.contains("bamboo") or label.contains("bush")) and not (label.contains("stump") or label.contains("log") or label.contains("trunk")):
   tree_candidates.append(path)
 if tree_candidates.is_empty():
  push_error("IMPERIAL_CITY_TREE_FAIL: no real tree GLB models found for " + city)
  return
 tree_candidates.sort()
 var species: Array[Dictionary] = []
 for required_species in ["willow","pine","bamboo","plum","bush"]:
  var selected_path := ""
  for candidate_path in tree_candidates:
   if candidate_path.get_file().to_lower().contains(required_species):
    selected_path = candidate_path
    break
  if selected_path.is_empty():
   push_error("IMPERIAL_CITY_TREE_SPECIES_MISSING: " + city + " requires " + required_species + " GLB")
   return
  var packed := ResourceLoader.load(selected_path) as PackedScene
  if packed == null:
   push_error("IMPERIAL_CITY_TREE_IMPORT_FAIL: " + selected_path)
   return
  var instance := packed.instantiate()
  var parts: Array[Dictionary] = []
  _collect_tree_mesh_parts(instance,Transform3D.IDENTITY,parts,true)
  instance.free()
  if parts.is_empty():
   push_error("IMPERIAL_CITY_TREE_MESH_FAIL: " + selected_path)
   return
  species.append({"path":selected_path,"parts":parts})
 const TREES_PER_CITY := 60
 var city_index := maxi(0, ["TwinCity","DesertLand","VolcanoLand","IceLand","Waterlands","DarkForest"].find(city))
 var base_count := int(TREES_PER_CITY / species.size())
 var remainder := posmod(TREES_PER_CITY, species.size())
 var global_index := 0
 for species_index in range(species.size()):
  var parts: Array = species[species_index]["parts"]
  var species_name := str(species[species_index]["path"]).get_file().to_lower()
  var species_height := 5.0
  if species_name.contains("pine"): species_height = 8.0
  elif species_name.contains("willow"): species_height = 5.0
  elif species_name.contains("bamboo"): species_height = 4.0
  elif species_name.contains("bush"): species_height = 1.8
  elif species_name.contains("plum"): species_height = 3.6
  var bounds_min := Vector3(INF,INF,INF)
  var bounds_max := Vector3(-INF,-INF,-INF)
  for part in parts:
   var part_mesh: Mesh = part["mesh"]
   var part_transform: Transform3D = part["transform"]
   for corner in part_mesh.get_aabb().get_corners():
    var point: Vector3 = part_transform * corner
    bounds_min = bounds_min.min(point)
    bounds_max = bounds_max.max(point)
  var model_height := maxf(bounds_max.y-bounds_min.y,0.01)
  var count := base_count + (1 if species_index < remainder else 0)
  var instance_transforms: Array[Transform3D] = []
  for index in range(count):
   var angle := float(global_index) * 2.399963 + float(city_index) * 0.47
   var radius := 96.0 + float((global_index * 37 + species_index * 19 + city_index * 11) % 58)
   var target_height := species_height * (0.88 + float((global_index * 13 + species_index * 7) % 25) * 0.01)
   var scale_factor := target_height / model_height
   var basis := Basis(Vector3.UP,angle).scaled(Vector3.ONE*scale_factor)
   var position := Vector3(cos(angle)*radius,0.0,sin(angle)*radius)
   position.y = sample_height_image(height_image,city,position.x,position.z,size) - bounds_min.y*scale_factor
   instance_transforms.append(Transform3D(basis,position))
   global_index += 1
  for part_index in range(parts.size()):
   var part := parts[part_index]
   var multi := MultiMesh.new()
   multi.transform_format = MultiMesh.TRANSFORM_3D
   var part_mesh: Mesh = part["mesh"]
   multi.mesh = part_mesh
   multi.instance_count = count
   var part_transform: Transform3D = part["transform"]
   for index in range(count):
    multi.set_instance_transform(index,instance_transforms[index]*part_transform)
   var node := MultiMeshInstance3D.new()
   node.name = city + "_ImperialTree_" + str(species_index) + "_Part_" + str(part_index) + "_MultiMesh"
   node.multimesh = multi
   node.set_meta("source_asset_path",str(species[species_index]["path"]))
   if part_index == 0:
    node.add_to_group("imperial_city_tree_multimesh")
   else:
    node.add_to_group("imperial_city_tree_render_mesh")
   node.add_to_group("distance_cull_world")
   node.visibility_range_end = 440.0
   node.visibility_range_end_margin = 36.0
   parent.add_child(node)
 print("IMPERIAL_CITY_TREE_MULTIMESH_PASS: %s trees=%d species=%d source=%s" % [city, TREES_PER_CITY, species.size(), str(species.map(func(item: Dictionary) -> String: return str(item["path"]).get_file()))])

static func _collect_kenney_nature_models(path: String, output: Array[String]) -> void:
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
   _collect_kenney_nature_models(child, output)
  elif entry.get_extension().to_lower() in ["glb", "gltf"]:
   output.append(child)
  entry = directory.get_next()
 directory.list_dir_end()

static func _first_renderable_mesh(root: Node) -> Mesh:
 var pending: Array[Node] = [root]
 while not pending.is_empty():
  var current: Node = pending.pop_back()
  for child in current.get_children():
   pending.append(child)
  if current is MeshInstance3D and (current as MeshInstance3D).mesh != null:
   return (current as MeshInstance3D).mesh
 return null

static func _make_procedural_texture(stone: bool) -> Texture2D:
 var image := Image.create(256,256,false,Image.FORMAT_RGBA8)
 var noise := FastNoiseLite.new()
 noise.seed = 1742 if stone else 8241
 noise.frequency = 0.035 if stone else 0.022
 noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
 for y in range(256):
  for x in range(256):
   var n := noise.get_noise_2d(float(x),float(y))
   var color := Color.WHITE
   if stone:
    var row := int(y / 32)
    var shifted_x := posmod(x + (16 if row % 2 == 1 else 0),48)
    var grout := shifted_x < 2 or posmod(y,32) < 2
    var shade := clampf(0.66 + n * 0.17 + float((x * 13 + y * 7) % 9) * 0.008,0.42,0.88)
    color = Color(0.62,0.59,0.52,1.0) * shade if not grout else Color("#514b42")
   else:
    var shade := clampf(0.76 + n * 0.34 + float((x * 5 + y * 11) % 13) * 0.006,0.35,1.0)
    color = Color("#66894a").lerp(Color("#a0a85a"),clampf(n * 0.8 + 0.35,0.0,1.0)) * shade
   image.set_pixel(x,y,color)
 return ImageTexture.create_from_image(image)

static func _stone_material() -> StandardMaterial3D:
 # Use the restored stone PBR pack directly; never replace its albedo/normal/roughness maps.
 return PBRMaterialLibrary.build_ground_material("TwinCity", true, "Ground044_2K-JPG")

static func _fallback_ground_material(city: String) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = Color.WHITE if city == "TwinCity" else COLORS.get(city, Color("#6c9849"))
 material.roughness = 1.0
 material.metallic = 0.0
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
 if city == "TwinCity":
  material.albedo_texture = _make_procedural_texture(false)
  material.uv1_scale = Vector3(38.0,38.0,1.0)
 return material

static func _build_flat_twin_city_plaza(parent: Node3D) -> void:
 var plaza := StaticBody3D.new()
 plaza.name = "TwinCityFlatPlaza_80x80"
 var floor := MeshInstance3D.new()
 floor.name = "TwinCityImperialStonePlaza"
 var plane := PlaneMesh.new()
 plane.size = Vector2(80.0,80.0)
 floor.mesh = plane
 floor.position.y = 0.018
 plaza.add_child(floor)
 floor.material_override = _stone_material()
 var collision := CollisionShape3D.new()
 collision.name = "TwinCityFlatPlazaCollision"
 var box := BoxShape3D.new()
 box.size = Vector3(800.0,2.0,800.0)
 box.size = Vector3(80.0,2.0,80.0)
 collision.shape = box
 collision.position.y = -1.0
 plaza.add_child(collision)
 parent.add_child(plaza)


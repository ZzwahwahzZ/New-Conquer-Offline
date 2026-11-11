extends Node3D
## Builds scalable heightfield terrain and hard safety bounds. All collision stays static.
const CITY_SIZE := {"TwinCity":600.0,"DesertLand":450.0,"VolcanoLand":450.0,"IceLand":450.0,"Waterlands":450.0,"DarkForest":450.0}
const HEIGHTS := {
 "TwinCity":"", "DesertLand":"res://assets/terrain/heightmaps/04_desert_dunes_heightmap_16bit.png",
 "VolcanoLand":"res://assets/terrain/heightmaps/01_volcanic_caldera_heightmap_16bit.png",
 "IceLand":"res://assets/terrain/heightmaps/02_glacial_mountains_heightmap_16bit.png",
 "Waterlands":"res://assets/terrain/heightmaps/03_tropical_archipelago_heightmap_16bit.png",
 "DarkForest":"res://assets/terrain/heightmaps/05_dark_forest_valleys_heightmap_16bit.png"}
const COLORS := {"TwinCity":Color("#6c9849"),"DesertLand":Color("#b58a4e"),"VolcanoLand":Color("#393437"),"IceLand":Color("#b9d9e8"),"Waterlands":Color("#3a9e91"),"DarkForest":Color("#294b32")}
const MATERIALS := {"TwinCity":"Ground044_2K-JPG","DesertLand":"Ground061_2K-JPG","VolcanoLand":"Rock027_2K-JPG","IceLand":"Snow008C_2K-JPG","Waterlands":"Ground044_2K-JPG","DarkForest":"Ground053_2K-JPG"}
const KARST_MODELS := ["model.glb","model (1).glb","model (3).glb"]
static func build(parent: Node3D, city: String, slot: Node3D) -> void:
 var size: float = CITY_SIZE.get(city,450.0)
 var mesh := _height_mesh(city,size)
 var body := StaticBody3D.new()
 body.name = "TerrainCollision"
 var visual := MeshInstance3D.new()
 visual.name = "TerrainSurface"
 visual.mesh = mesh
 visual.material_override = _fallback_ground_material(city)
 body.add_child(visual)
 if city == "TwinCity":
  # Preserve the terrain node for scene contracts, but only the flat plaza owns a collider.
  _build_flat_twin_city_plaza(parent)
 else:
  var collision := CollisionShape3D.new()
  var shape := ConcavePolygonShape3D.new()
  shape.set_faces(mesh.get_faces())
  collision.shape = shape
  body.add_child(collision)
 parent.add_child(body)
 _bounds(parent,size,city)
 _roads(slot,size,city)
 _place_karst_models(slot,city,size)
static func _height_mesh(city: String,size: float) -> ArrayMesh:
 var path: String = HEIGHTS.get(city,"")
 var image: Image = Image.load_from_file(path) if path != "" and FileAccess.file_exists(path) else null
 var resolution := 65
 var verts := PackedVector3Array()
 var uv := PackedVector2Array()
 var indices := PackedInt32Array()
 for z in range(resolution):
  for x in range(resolution):
   var h := 0.0
   if image != null:
    var ix := int(float(x)*(image.get_width()-1)/(resolution-1))
    var iz := int(float(z)*(image.get_height()-1)/(resolution-1))
    h = (image.get_pixel(ix,iz).r-0.5)*28.0
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
static func _bounds(parent: Node3D,size: float,city: String) -> void:
 var edge := 280.0 if city == "TwinCity" else 210.0
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
  var road:=MeshInstance3D.new(); var p:=PlaneMesh.new(); p.size=Vector2(9.0,size*0.46); road.mesh=p
  road.rotation_degrees.y=i*90.0; road.position=Vector3(0,0.025,0)
  var m:=StandardMaterial3D.new(); m.albedo_color=Color("#b8ad96"); m.roughness=1.0; road.material_override=m; slot.add_child(road)

static func _place_karst_models(parent: Node3D,city: String,size: float) -> void:
 if city=="TwinCity":
  # TwinCity receives a smaller imperial ruin landmark while keeping its central plaza open.
  pass
 var city_index := ["TwinCity","DesertLand","VolcanoLand","IceLand","Waterlands","DarkForest"].find(city)
 var model_name: String = KARST_MODELS[maxi(city_index,0)%KARST_MODELS.size()]
 var path := "res://assets/terrain/models/" + model_name
 if not ResourceLoader.exists(path): return
 var packed := load(path) as PackedScene
 if packed == null: return
 var instance := packed.instantiate() as Node3D
 if instance == null: return
 instance.name = "ImportedKarstLandmark"
 var bounds := AABB()
 var found := false
 var stack: Array[Node] = [instance]
 while not stack.is_empty():
  var node: Node = stack.pop_back()
  for child in node.get_children(): stack.append(child)
  if node is MeshInstance3D and node.mesh != null:
   var mesh_node := node as MeshInstance3D
   bounds = mesh_node.get_aabb() if not found else bounds.merge(mesh_node.get_aabb())
   found = true
   var rock := StandardMaterial3D.new()
   rock.albedo_color = Color("#b5a995") if city in ["DesertLand","IceLand"] else Color("#5b5754")
   rock.roughness = 0.94
   for surface in range(mesh_node.mesh.get_surface_count()):
    mesh_node.set_surface_override_material(surface,rock)
 if found and bounds.size.length()>0.001:
  var target := 26.0
  var factor := target/maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
  instance.scale = Vector3.ONE*factor
 instance.position = Vector3(size*0.28,0.0,size*0.24) if city!="TwinCity" else Vector3(92.0,0.0,82.0)
 parent.add_child(instance)
 if city=="Waterlands":
  var island_path := "res://assets/terrain/models/tropical-island.glb"
  if ResourceLoader.exists(island_path):
   var island_pack := load(island_path) as PackedScene
   if island_pack != null:
    var island := island_pack.instantiate() as Node3D
    if island != null:
     island.name = "TropicalIslandImported"
     island.position = Vector3(-size*0.28,0.0,-size*0.22)
     parent.add_child(island)
     _add_scene_mesh_collisions(island)

static func _add_scene_mesh_collisions(root: Node) -> void:
 var stack: Array[Node] = [root]
 while not stack.is_empty():
  var node: Node = stack.pop_back()
  for child in node.get_children(): stack.append(child)
  if node is MeshInstance3D:
   var mesh_node := node as MeshInstance3D
   if mesh_node.mesh != null and mesh_node.mesh.get_surface_count()>0:
    mesh_node.create_trimesh_collision()

static func _fallback_ground_material(city: String) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = COLORS.get(city, Color("#6c9849"))
 material.roughness = 1.0
 material.metallic = 0.0
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
 if OS.has_feature("web"):
  material.normal_enabled = false
  material.roughness_texture = null
 return material

static func _build_flat_twin_city_plaza(parent: Node3D) -> void:
 var plaza := StaticBody3D.new()
 plaza.name = "TwinCityFlatPlaza"
 var floor := MeshInstance3D.new()
 floor.name = "TwinCityGreenPlazaSurface"
 var plane := PlaneMesh.new()
 plane.size = Vector2(600.0, 600.0)
 floor.mesh = plane
 floor.position.y = 0.005
 floor.material_override = _fallback_ground_material("TwinCity")
 plaza.add_child(floor)
 var collision := CollisionShape3D.new()
 collision.name = "TwinCityFlatPlazaCollision"
 var box := BoxShape3D.new()
 box.size = Vector3(600.0, 2.0, 600.0)
 collision.shape = box
 collision.position.y = -1.0
 plaza.add_child(collision)
 parent.add_child(plaza)

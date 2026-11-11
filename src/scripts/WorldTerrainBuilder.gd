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
static func build(parent: Node3D, city: String, slot: Node3D) -> void:
 var size: float = CITY_SIZE.get(city,450.0)
 var mesh := _height_mesh(city,size)
 var body := StaticBody3D.new()
 body.name = "TerrainCollision"
 var visual := MeshInstance3D.new()
 visual.name = "TerrainSurface"
 visual.mesh = mesh
 var mat := StandardMaterial3D.new()
 mat.albedo_color = COLORS.get(city,Color.GREEN)
 mat.roughness = 0.96
 mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 visual.material_override = mat
 body.add_child(visual)
 var collision := CollisionShape3D.new()
 var shape := ConcavePolygonShape3D.new()
 shape.set_faces(mesh.get_faces())
 collision.shape = shape
 body.add_child(collision)
 parent.add_child(body)
 _bounds(parent,size)
 _roads(slot,size,city)
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
static func _bounds(parent: Node3D,size: float) -> void:
 for i in range(4):
  var wall:=StaticBody3D.new(); wall.name="WorldBoundary_%d"%i
  var cs:=CollisionShape3D.new(); var box:=BoxShape3D.new()
  box.size=Vector3(size,40.0,2.0) if i<2 else Vector3(2.0,40.0,size)
  cs.shape=box
  var offset:=Vector3(0,18.0,-size*0.5) if i==0 else (Vector3(0,18.0,size*0.5) if i==1 else (Vector3(-size*0.5,18.0,0) if i==2 else Vector3(size*0.5,18.0,0)))
  wall.position=offset; wall.add_child(cs); parent.add_child(wall)
static func _roads(slot: Node3D,size: float,city: String) -> void:
 if city!="TwinCity": return
 for i in range(4):
  var road:=MeshInstance3D.new(); var p:=PlaneMesh.new(); p.size=Vector2(9.0,size*0.46); road.mesh=p
  road.rotation_degrees.y=i*90.0; road.position=Vector3(0,0.025,0)
  var m:=StandardMaterial3D.new(); m.albedo_color=Color("#b8ad96"); m.roughness=1.0; road.material_override=m; slot.add_child(road)

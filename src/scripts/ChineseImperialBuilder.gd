extends RefCounted
## Lightweight procedural Chinese imperial architecture. Repeated props use MultiMesh.
static func build(parent: Node3D, city: String, size: float) -> void:
 var root:=Node3D.new(); root.name="ChineseImperialArchitecture"; parent.add_child(root)
 _pagoda(root,Vector3(0.0,0.0,-48.0) if city=="TwinCity" else Vector3.ZERO,city=="TwinCity")
 _gate(root,Vector3(0,0,-size*0.43))
 _gate(root,Vector3(0,0,size*0.43))
 if city=="TwinCity":
  _gate(root,Vector3(-size*0.43,0,0)); _gate(root,Vector3(size*0.43,0,0))
  # Inner ceremonial paifang gates frame the central plaza within the opening camera view.
  _gate(root,Vector3(0,0,-38.0))
  _gate(root,Vector3(-38.0,0,0))
  _gate(root,Vector3(38.0,0,0))
  _wall(root,size)
  for i in range(8):
   var a=TAU*float(i)/8.0; _pillar(root,Vector3(cos(a)*42.0,0,sin(a)*42.0))
 else:
  _wall(root,size*0.72)
 _multilight(root,city)
 _city_features(root,city,size)
 if city=="TwinCity":
  _twin_city_details(root)
 if city=="TwinCity":
  for i in range(4):
   var angle:=TAU*float(i)/4.0
   _pavilion(root,Vector3(cos(angle)*54.0,0.0,sin(angle)*54.0))
 _npc_halls(root)
 if city=="TwinCity":
  _arched_bridge(root,Vector3(-42.0,0.0,-92.0),Vector3(42.0,0.0,-92.0),7.0)
  _arched_bridge(root,Vector3(-42.0,0.0,92.0),Vector3(42.0,0.0,92.0),7.0)
 elif city=="Waterlands":
  _arched_bridge(root,Vector3(-72.0,0.0,-58.0),Vector3(72.0,0.0,-58.0),8.0)
 elif city=="VolcanoLand":
  _arched_bridge(root,Vector3(-55.0,0.0,0.0),Vector3(55.0,0.0,0.0),7.0)
static func _mat(color: Color,metal: float=0.0) -> StandardMaterial3D:
 var m:=StandardMaterial3D.new(); m.albedo_color=color; m.metallic=metal; m.roughness=0.55; return m
static func _box(parent: Node3D,pos: Vector3,scale: Vector3,color: Color) -> MeshInstance3D:
 var n:=MeshInstance3D.new(); var m:=BoxMesh.new(); m.size=scale; n.mesh=m; n.position=pos; n.material_override=_mat(color); parent.add_child(n); return n
static func _roof(parent: Node3D,pos: Vector3,w: float) -> void:
 _box(parent,pos,Vector3(w,0.45,w*0.78),Color("#9B111E"))
 for x in [-1.0,1.0]:
  for z in [-1.0,1.0]:
   var e:=MeshInstance3D.new(); var s:=SphereMesh.new(); s.radius=0.45; s.height=0.9; e.mesh=s; e.position=pos+Vector3(x*w*0.48,0.18,z*w*0.39); e.material_override=_mat(Color("#D4AF37"),0.7); parent.add_child(e)
static func _pagoda(p: Node3D,pos: Vector3,grand: bool) -> void:
 var h:=18.0 if grand else 11.0; var w:=13.0 if grand else 8.0
 for tier in range(4 if grand else 3):
  var y=float(tier)*h/3.0
  _box(p,pos+Vector3(0,y+1.0,0),Vector3(w*0.62,2.0,w*0.62),Color("#eee6d4"))
  _roof(p,pos+Vector3(0,y+2.2,0),w*(1.0-float(tier)*0.16))
 _box(p,pos+Vector3(0,h+4.0,0),Vector3(0.8,5.0,0.8),Color("#D4AF37"))
static func _gate(p: Node3D,pos: Vector3) -> void:
 for x in [-5.0,0.0,5.0]: _box(p,pos+Vector3(x,3,0),Vector3(0.9,6,0.9),Color("#9B111E"))
 _roof(p,pos+Vector3(0,7,0),14.0)
static func _pillar(p: Node3D,pos: Vector3) -> void:
 var n:=MeshInstance3D.new(); var c:=CylinderMesh.new(); c.top_radius=0.65; c.bottom_radius=0.9; c.height=7.0; n.mesh=c; n.position=pos+Vector3.UP*3.5; n.material_override=_mat(Color("#9B111E")); p.add_child(n)
static func _wall(p: Node3D,size: float) -> void:
 for side in range(4):
  var inst:=MultiMeshInstance3D.new(); var mm:=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D
  var cube:=BoxMesh.new(); cube.size=Vector3(7,5,3); cube.material=_mat(Color("#b7ad9a")); mm.mesh=cube
  var count:=int(size/14.0); mm.instance_count=count
  for i in range(count):
   var d:=float(i)*14.0-size*0.5
   var tr:=Transform3D(Basis(),Vector3(d,2.5,-size*0.5) if side==0 else (Vector3(d,2.5,size*0.5) if side==1 else (Vector3(-size*0.5,2.5,d) if side==2 else Vector3(size*0.5,2.5,d))))
   if side>=2: tr.basis=Basis(Vector3.UP,PI*0.5)
   mm.set_instance_transform(i,tr)
  inst.multimesh=mm; p.add_child(inst)
static func _multilight(p: Node3D,city: String) -> void:
 var mm:=MultiMesh.new(); mm.transform_format=MultiMesh.TRANSFORM_3D; var mesh:=SphereMesh.new(); mesh.radius=0.32; mesh.material=_mat(Color("#e9a34b"))
 mm.mesh=mesh; mm.instance_count=32
 for i in range(32):
  var a=TAU*float(i)/32.0; mm.set_instance_transform(i,Transform3D(Basis(),Vector3(cos(a)*42.0,3.0,sin(a)*42.0)))
 var node:=MultiMeshInstance3D.new(); node.multimesh=mm; node.name="LanternMultiMesh"; p.add_child(node)

static func _pavilion(parent: Node3D,pos: Vector3) -> void:
 var pod:=Node3D.new(); pod.position=pos; parent.add_child(pod)
 _box(pod,Vector3(0,0.7,0),Vector3(12,1.4,9),Color("#eee6d4"))
 for x in [-4.5,4.5]:
  for z in [-3.0,3.0]:
   _box(pod,Vector3(x,3.1,z),Vector3(0.7,5.0,0.7),Color("#9B111E"))
 _roof(pod,Vector3(0,6.0,0),14.0)
static func _city_features(parent: Node3D,city: String,size: float) -> void:
 if city=="TwinCity":
  var canal_mat:=_mat(Color("#268eae"))
  canal_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  canal_mat.albedo_color.a=0.82
  for z in [-92.0,92.0]:
   var canal:=MeshInstance3D.new()
   var canal_mesh:=PlaneMesh.new()
   canal_mesh.size=Vector2(7.0,150.0)
   canal.mesh=canal_mesh
   canal.position=Vector3(0.0,-0.28,z)
   canal.material_override=canal_mat
   canal.name="TwinCityWaterChannel"
   parent.add_child(canal)
 elif city=="VolcanoLand":
  var lava_mat:=_mat(Color("#f05a16")); lava_mat.emission_enabled=true; lava_mat.emission=Color("#ff4b08"); lava_mat.emission_energy_multiplier=2.2
  for i in range(3):
   var river:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(4.0,size*0.62); river.mesh=plane
   river.position=Vector3(-size*0.22+float(i)*size*0.22,0.08,0); river.material_override=lava_mat; parent.add_child(river)
 elif city=="Waterlands":
  var water:=MeshInstance3D.new(); var plane:=PlaneMesh.new(); plane.size=Vector2(size*0.88, size*0.88); water.mesh=plane
  water.position.y=-0.35; var wm:=_mat(Color("#20aeb5")); wm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA; wm.albedo_color.a=0.72; water.material_override=wm; water.name="TurquoiseWaterSurface"; parent.add_child(water)
 elif city=="IceLand":
  for i in range(12):
   var crystal:=MeshInstance3D.new(); var prism:=PrismMesh.new(); prism.size=Vector3(1.2,7.0,1.2); crystal.mesh=prism
   var a=TAU*float(i)/12.0; crystal.position=Vector3(cos(a)*32.0,3.5,sin(a)*32.0)
   crystal.material_override=_mat(Color("#8bd8ed"),0.35); parent.add_child(crystal)
 elif city=="DarkForest":
  var multi:=MultiMesh.new(); multi.transform_format=MultiMesh.TRANSFORM_3D
  var trunk:=CylinderMesh.new(); trunk.top_radius=0.45; trunk.bottom_radius=0.8; trunk.height=12.0; trunk.material=_mat(Color("#3d3026")); multi.mesh=trunk
  multi.instance_count=160
  for i in range(160):
   var angle:=float(i)*2.39996; var radius:=size*(0.28+0.17*float((i*37)%100)/100.0)
   var pos:=Vector3(cos(angle)*radius,6.0,sin(angle)*radius)
   multi.set_instance_transform(i,Transform3D(Basis(),pos))
  var forest:=MultiMeshInstance3D.new(); forest.multimesh=multi; forest.name="ForestTreeTrunksMultiMesh"; parent.add_child(forest)

static func _golden_roof(parent: Node3D, center: Vector3, width: float, depth: float) -> void:
 var roof := MeshInstance3D.new()
 var slab := BoxMesh.new()
 slab.size = Vector3(width,0.48,depth)
 roof.mesh = slab
 roof.position = center
 roof.material_override = _mat(Color("#b98a2d"),0.72)
 parent.add_child(roof)
 for side in [-1.0,1.0]:
  for front in [-1.0,1.0]:
   var tip := MeshInstance3D.new()
   var tip_mesh := SphereMesh.new()
   tip_mesh.radius = 0.42
   tip_mesh.height = 0.72
   tip.mesh = tip_mesh
   tip.position = center + Vector3(side*width*0.49,0.22,front*depth*0.46)
   tip.rotation.z = -side*0.45
   tip.material_override = _mat(Color("#d6ad42"),0.72)
   parent.add_child(tip)

static func _imperial_palace(parent: Node3D) -> void:
 var palace := Node3D.new()
 palace.name = "TwinCityImperialPalace"
 palace.position = Vector3(0.0,0.0,-116.0)
 parent.add_child(palace)
 _box(palace,Vector3(0.0,0.8,0.0),Vector3(32.0,1.6,22.0),Color("#d7c8a7"))
 _box(palace,Vector3(0.0,1.75,0.0),Vector3(26.0,0.5,18.0),Color("#9b7b48"))
 for x in [-10.0,-5.0,0.0,5.0,10.0]:
  for z in [-7.0,7.0]:
   _box(palace,Vector3(x,5.1,z),Vector3(0.85,7.0,0.85),Color("#9b1e24"))
 _box(palace,Vector3(0.0,5.1,0.0),Vector3(23.0,7.0,13.0),Color("#a52a2a"))
 _box(palace,Vector3(0.0,8.7,0.0),Vector3(24.0,0.45,14.0),Color("#e2c27b"))
 _golden_roof(palace,Vector3(0.0,9.3,0.0),30.0,21.0)
 _golden_roof(palace,Vector3(0.0,12.0,0.0),22.0,15.0)
 _box(palace,Vector3(0.0,13.3,0.0),Vector3(1.0,2.4,1.0),Color("#d6ad42"))

static func _lantern(parent: Node3D, position: Vector3) -> void:
 var post := MeshInstance3D.new()
 var pole := CylinderMesh.new()
 pole.top_radius = 0.10
 pole.bottom_radius = 0.15
 pole.height = 3.2
 post.mesh = pole
 post.position = position + Vector3(0.0,1.6,0.0)
 post.material_override = _mat(Color("#6b3024"))
 parent.add_child(post)
 var lamp := MeshInstance3D.new()
 var body := SphereMesh.new()
 body.radius = 0.48
 body.height = 0.78
 lamp.mesh = body
 lamp.position = position + Vector3(0.0,3.45,0.0)
 var glow := _mat(Color("#d92d25"))
 glow.emission_enabled = true
 glow.emission = Color("#ff6b32")
 glow.emission_energy_multiplier = 1.5
 lamp.material_override = glow
 parent.add_child(lamp)
 var cap := MeshInstance3D.new()
 var cap_mesh := BoxMesh.new()
 cap_mesh.size = Vector3(0.72,0.12,0.72)
 cap.mesh = cap_mesh
 cap.position = position + Vector3(0.0,3.95,0.0)
 cap.material_override = _mat(Color("#d5a63c"),0.6)
 parent.add_child(cap)

static func _tree(parent: Node3D, position: Vector3, sakura: bool) -> void:
 var trunk := MeshInstance3D.new()
 var trunk_mesh := CylinderMesh.new()
 trunk_mesh.top_radius = 0.22
 trunk_mesh.bottom_radius = 0.38
 trunk_mesh.height = 4.2
 trunk.mesh = trunk_mesh
 trunk.position = position + Vector3(0.0,2.1,0.0)
 trunk.material_override = _mat(Color("#68432d"))
 parent.add_child(trunk)
 var foliage := _mat(Color("#e99ab3") if sakura else Color("#5e8a58"))
 for offset in [Vector3(0.0,4.5,0.0),Vector3(-1.0,4.0,0.3),Vector3(0.9,4.1,-0.2),Vector3(0.0,5.1,-0.5)]:
  var crown := MeshInstance3D.new()
  var sphere := SphereMesh.new()
  sphere.radius = 1.35 if sakura else 1.55
  sphere.height = 2.2 if sakura else 2.6
  crown.mesh = sphere
  crown.position = position + offset
  crown.material_override = foliage
  parent.add_child(crown)

static func _dragon_statue(parent: Node3D, position: Vector3, direction: float) -> void:
 var dragon := Node3D.new()
 dragon.name = "BridgeDragonStatue"
 dragon.position = position
 dragon.rotation.y = direction
 parent.add_child(dragon)
 var jade := _mat(Color("#397b64"),0.28)
 var gold := _mat(Color("#c79b43"),0.62)
 var body := MeshInstance3D.new()
 var body_mesh := SphereMesh.new()
 body_mesh.radius = 0.78
 body_mesh.height = 1.25
 body.mesh = body_mesh
 body.position = Vector3(0.0,0.8,0.0)
 body.material_override = jade
 dragon.add_child(body)
 for i in range(4):
  var segment := MeshInstance3D.new()
  var sphere := SphereMesh.new()
  sphere.radius = 0.42 - float(i)*0.055
  sphere.height = 0.75 - float(i)*0.08
  segment.mesh = sphere
  segment.position = Vector3(0.0,0.95,-0.8-float(i)*0.55)
  segment.material_override = jade
  dragon.add_child(segment)
 var head := MeshInstance3D.new()
 var head_mesh := SphereMesh.new()
 head_mesh.radius = 0.42
 head_mesh.height = 0.55
 head.mesh = head_mesh
 head.position = Vector3(0.0,1.2,0.85)
 head.material_override = jade
 dragon.add_child(head)
 for side in [-1.0,1.0]:
  var horn := MeshInstance3D.new()
  var horn_mesh := PrismMesh.new()
  horn_mesh.size = Vector3(0.16,0.5,0.16)
  horn.mesh = horn_mesh
  horn.position = Vector3(side*0.25,1.62,0.9)
  horn.material_override = gold
  dragon.add_child(horn)

static func _twin_city_details(parent: Node3D) -> void:
 _imperial_palace(parent)
 var lantern_positions := [
  Vector3(-16.0,0.0,-20.0),Vector3(16.0,0.0,-20.0),
  Vector3(-16.0,0.0,20.0),Vector3(16.0,0.0,20.0),
  Vector3(-58.0,0.0,-38.0),Vector3(58.0,0.0,-38.0),
  Vector3(-58.0,0.0,38.0),Vector3(58.0,0.0,38.0),
  Vector3(-40.0,0.0,-90.0),Vector3(40.0,0.0,-90.0),
  Vector3(-40.0,0.0,90.0),Vector3(40.0,0.0,90.0)
 ]
 for pos in lantern_positions:
  _lantern(parent,pos)
 for pos in [Vector3(-82.0,0.0,-58.0),Vector3(-96.0,0.0,-18.0),Vector3(-82.0,0.0,52.0),Vector3(82.0,0.0,-58.0),Vector3(96.0,0.0,-18.0),Vector3(82.0,0.0,52.0)]:
  _tree(parent,pos,true)
 for pos in [Vector3(-112.0,0.0,-76.0),Vector3(-112.0,0.0,64.0),Vector3(112.0,0.0,-76.0),Vector3(112.0,0.0,64.0)]:
  _tree(parent,pos,false)
 for z in [-92.0,92.0]:
  _dragon_statue(parent,Vector3(-39.0,0.0,z),0.0)
  _dragon_statue(parent,Vector3(39.0,0.0,z),PI)

static func _npc_halls(parent: Node3D) -> void:
 var specs := [
  ["BlacksmithTemple",Vector3(-48,0,48),Color("#8f2c1f")],
  ["TreasuryHall",Vector3(48,0,48),Color("#b18a35")],
  ["MaterialsShop",Vector3(-48,0,-48),Color("#477d68")],
  ["ClanManagerPavilion",Vector3(48,0,-48),Color("#365b83")],
  ["EvolutionTrainerHall",Vector3(0,0,58),Color("#6e4b86")]
 ]
 for item in specs:
  var hall:=Node3D.new()
  hall.name=item[0]
  hall.position=item[1]
  parent.add_child(hall)
  _box(hall,Vector3(0,0.7,0),Vector3(10,1.4,8),Color("#ded2b7"))
  for x in [-3.8,3.8]:
   for z in [-2.8,2.8]:
    _box(hall,Vector3(x,2.7,z),Vector3(0.55,4.0,0.55),Color("#8f241c"))
  _roof(hall,Vector3(0,5.0,0),12.0)
  if item[0]=="BlacksmithTemple":
   var furnace:=MeshInstance3D.new()
   var fire:=BoxMesh.new()
   fire.size=Vector3(2.0,2.2,1.8)
   furnace.mesh=fire
   furnace.position=Vector3(0,1.8,-1.2)
   var fm:=_mat(Color("#f05a16"))
   fm.emission_enabled=true
   fm.emission=Color("#ff4b08")
   fm.emission_energy_multiplier=1.6
   furnace.material_override=fm
   hall.add_child(furnace)
   _box(hall,Vector3(2.0,1.1,0.8),Vector3(2.4,0.7,1.4),Color("#62666a"))

static func _arched_bridge(parent: Node3D, start: Vector3, finish: Vector3, width: float) -> void:
 var segments:=16
 var verts:=PackedVector3Array()
 var indices:=PackedInt32Array()
 for i in range(segments+1):
  var t:=float(i)/segments
  var center:=start.lerp(finish,t)
  center.y+=sin(PI*t)*3.2
  verts.append(center+Vector3(0,0,-width*0.5))
  verts.append(center+Vector3(0,0,width*0.5))
 for i in range(segments):
  var a=i*2
  indices.append_array(PackedInt32Array([a,a+2,a+1,a+1,a+2,a+3]))
 var arrays=[]; arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=verts
 arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var body:=StaticBody3D.new()
 body.name="ArchedBridgeCollision"
 var visual:=MeshInstance3D.new()
 visual.name="ArchedBridgeDeck"
 visual.mesh=mesh
 visual.material_override=_mat(Color("#b9a98b"))
 body.add_child(visual)
 var collision:=CollisionShape3D.new()
 var shape:=ConcavePolygonShape3D.new()
 shape.set_faces(mesh.get_faces())
 collision.shape=shape
 body.add_child(collision)
 parent.add_child(body)

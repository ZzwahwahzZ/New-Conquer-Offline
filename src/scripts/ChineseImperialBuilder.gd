extends RefCounted
## Lightweight procedural Chinese imperial architecture. Repeated props use MultiMesh.
static func build(parent: Node3D, city: String, size: float) -> void:
 var root:=Node3D.new(); root.name="ChineseImperialArchitecture"; parent.add_child(root)
 _pagoda(root,Vector3.ZERO,city=="TwinCity")
 _gate(root,Vector3(0,0,-size*0.43))
 _gate(root,Vector3(0,0,size*0.43))
 if city=="TwinCity":
  _gate(root,Vector3(-size*0.43,0,0)); _gate(root,Vector3(size*0.43,0,0))
  _wall(root,size)
  for i in range(8):
   var a=TAU*float(i)/8.0; _pillar(root,Vector3(cos(a)*17.0,0,sin(a)*17.0))
 else:
  _wall(root,size*0.72)
 _multilight(root,city)
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

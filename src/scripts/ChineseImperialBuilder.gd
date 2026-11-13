extends RefCounted
## Imports original CC0 Chinese palace courtyard, ceremonial hall, pavilion and gate towers.
const ROOT := "res://assets/environment/architecture/"
static func build(parent: Node3D, city: String, _size: float) -> void:
 if city != "TwinCity": return
 var root := Node3D.new()
 root.name = "TwinCity_ChineseImperialArchitecture"
 parent.add_child(root)
 _add_model(root,"imperial_china_palace_and_garden.glb","TwinCity_ChineseImperialBuilding_00",Vector3(-112.0,0.30,-30.0),Vector3.ONE*0.5,false)
 _add_model(root,"ceremonial_hall.glb","TwinCity_ChineseImperialBuilding_01",Vector3(-30.0,0.0,-112.0),Vector3.ONE*0.9,true)
 _add_model(root,"water_pavilion.glb","TwinCity_ChineseImperialBuilding_02",Vector3(-112.0,0.0,30.0),Vector3.ONE,true)
 _replace_city_gates(parent)
static func _add_model(parent: Node3D,filename: String,node_name: String,at: Vector3,model_scale: Vector3,collision_all: bool) -> Node3D:
 var path := ROOT+filename
 if not ResourceLoader.exists(path):
  push_error("Missing required CC0 Chinese architecture GLB: "+path)
  return null
 var packed := load(path) as PackedScene
 if packed == null:
  push_error("Chinese architecture GLB did not import as PackedScene: "+path)
  return null
 var instance := packed.instantiate() as Node3D
 if instance == null:
  push_error("Chinese architecture GLB root is not Node3D: "+path)
  return null
 instance.name=node_name
 instance.position=at
 instance.scale=model_scale
 parent.add_child(instance)
 instance.add_to_group("distance_cull_world")
 _apply_visibility_range(instance,420.0,40.0)
 _add_model_collisions(instance,collision_all)
 return instance
static func _replace_city_gates(parent: Node3D) -> void:
 var fortification := parent.get_node_or_null("TwinCity_PerimeterFortifications") as Node3D
 if fortification == null:
  push_error("TwinCity perimeter fortifications are missing before Chinese gate installation.")
  return
 for direction in ["North","East","South","West"]:
  var gate := fortification.get_node_or_null(direction+"_GrandCityGate") as Node3D
  if gate == null:
   push_error("TwinCity gate anchor missing: "+direction)
   continue
  for child in gate.get_children():
   if child.name in ["KenneyGateModel","KenneyTowerModel_Left","KenneyTowerModel_Right","GatehouseTower","GateTowerCrenellation","GateArchLintel","ArchColumn"]:
    child.visible=false
  _add_model(gate,"gate_tower.glb","TwinCity_ChineseGateTower_"+direction,Vector3(0.0,0.0,-148.0),Vector3.ONE,true)
static func _add_model_collisions(root: Node,all_meshes: bool) -> void:
 for node in _all_nodes(root):
  if not node is MeshInstance3D: continue
  var mesh_node := node as MeshInstance3D
  if mesh_node.mesh == null: continue
  if all_meshes or _is_structural_mesh(mesh_node.name):
   mesh_node.create_trimesh_collision()
static func _is_structural_mesh(node_name: String) -> bool:
 var lowered:=node_name.to_lower()
 for token in ["wall","hall","gate","tower","column","bridge","pavilion","roof","terrace"]:
  if lowered.contains(token): return true
 return false
static func _apply_visibility_range(root: Node,range_end: float,margin: float) -> void:
 for node in _all_nodes(root):
  if node is GeometryInstance3D:
   var geometry:=node as GeometryInstance3D
   geometry.visibility_range_end=range_end
   geometry.visibility_range_end_margin=margin
static func _all_nodes(root: Node) -> Array[Node]:
 var result: Array[Node]=[]
 var pending: Array[Node]=[root]
 while not pending.is_empty():
  var current: Node=pending.pop_back()
  result.append(current)
  for child in current.get_children(): pending.append(child)
 return result

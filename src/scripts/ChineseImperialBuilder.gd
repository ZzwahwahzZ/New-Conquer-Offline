extends RefCounted
## Imports original CC0 Chinese palace courtyard, ceremonial hall, pavilion and gate towers.
const ROOT := "res://assets/wuxia_imperial_pack/architecture/"
const PBRMaterialLibrary = preload("res://src/scripts/PBRMaterialLibrary.gd")
const WorldTerrainBuilder = preload("res://src/scripts/WorldTerrainBuilder.gd")
static func build(parent: Node3D, city: String, _size: float) -> void:
 if city != "TwinCity": return
 var root := Node3D.new()
 root.name = "TwinCity_ChineseImperialArchitecture"
 parent.add_child(root)
 _add_model(root,"imperial_china_palace_and_garden.glb","TwinCity_ChineseImperialBuilding_00",Vector3(-65.45,0.0,-65.45),Vector3(0.4533619,0.4958047,0.4527178),false)
 _add_model(root,"ceremonial_hall.glb","TwinCity_ChineseImperialBuilding_01",Vector3(65.45,0.0,-65.45),Vector3(0.7761765,0.5195843,1.0210167),true)
 _add_model(root,"water_pavilion.glb","TwinCity_ChineseImperialBuilding_02",Vector3(-65.45,0.0,65.45),Vector3(1.6025455,0.8441558,1.7243667),true)
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
 var platform_root := Node3D.new()
 platform_root.name = node_name + "_RaisedImperialPlinth"
 platform_root.position = Vector3(at.x, WorldTerrainBuilder.height_at("TwinCity",at.x,at.z) + 0.85, at.z)
 platform_root.rotation.y = atan2(-at.x,-at.z)
 parent.add_child(platform_root)
 var platform_width := 34.0 if filename.contains("palace") else 28.0
 var platform_depth := 32.0 if filename.contains("palace") else 25.0
 var platform_size := Vector3(platform_width,4.0,platform_depth)
 var paving := PBRMaterialLibrary.build_plaza_material()
 var plinth := MeshInstance3D.new()
 plinth.name = "ChineseImperialRaisedStonePlinth_4_0m"
 var plinth_mesh := BoxMesh.new()
 plinth_mesh.size = platform_size
 plinth.mesh = plinth_mesh
 plinth.position.y = 2.0
 plinth.material_override = paving
 platform_root.add_child(plinth)
 var collision_body := StaticBody3D.new()
 collision_body.name = "ChineseImperialPlinthAndStairCollision"
 var plinth_collision := CollisionShape3D.new()
 var plinth_shape := BoxShape3D.new()
 plinth_shape.size = platform_size
 plinth_collision.shape = plinth_shape
 plinth_collision.position.y = 2.0
 collision_body.add_child(plinth_collision)
 for step in range(8):
  var step_center := Vector3(0.0,3.75-float(step)*0.5,platform_depth*0.5+0.55+float(step)*1.05)
  var step_size := Vector3(8.5,0.5,1.1)
  var stair := MeshInstance3D.new()
  stair.name = "ChineseImperialMarbleStair_%02d" % step
  var stair_mesh := BoxMesh.new()
  stair_mesh.size = step_size
  stair.mesh = stair_mesh
  stair.position = step_center
  stair.material_override = paving
  platform_root.add_child(stair)
  var stair_collision := CollisionShape3D.new()
  var stair_shape := BoxShape3D.new()
  stair_shape.size = step_size
  stair_collision.shape = stair_shape
  stair_collision.position = step_center
  collision_body.add_child(stair_collision)
 platform_root.add_child(collision_body)
 instance.name=node_name
 if node_name.begins_with("TwinCity_ChineseImperialBuilding_"):
  instance.add_to_group("city_building")
  instance.add_to_group("imported_city_building")
 instance.position=Vector3(0.0,3.5,0.0)
 instance.scale=model_scale
 platform_root.add_child(instance)
 instance.add_to_group("distance_cull_world")
 platform_root.add_to_group("distance_cull_world")
 _apply_visibility_range(platform_root,420.0,40.0)
 _add_model_collisions(instance,collision_all)
 print("CHINESE_IMPERIAL_RAISED_PLATFORM_PASS: %s height=4.0m stairs=8" % filename)
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
   if child.name in ["KenneyGateModel","KenneyTowerModel_Left","KenneyTowerModel_Right"]:
    child.visible=false
  # Keep the shared 14m Chinese gate assembly and its armored guardians visible.
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

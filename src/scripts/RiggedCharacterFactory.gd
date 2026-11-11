extends RefCounted
## Loads pinned offline GLB actors. Imported skeletons/animations are kept intact.
const ASSET_ROOT := "res://assets/rigged_characters/"
const HUMANOIDS := ["humanoid_01","humanoid_02","humanoid_03","humanoid_04","humanoid_05","humanoid_06","humanoid_07","humanoid_08"]
const MONSTERS := ["humanoid_02","humanoid_04","humanoid_06","humanoid_08","beast_bat","beast_corgi","beast_rhino","beast_shark"]
const CLASS_VARIANTS := {
 "Archer":0,"Oriental_Assassin":1,"Warrior":2,"Trojan":3,
 "Water_Taoist":4,"Fire_Taoist":5,"Ninja":6,"Monk":7
}
static func asset_path(kind: String, variant: int = 0) -> String:
 var index := posmod(variant, HUMANOIDS.size())
 if kind == "monster":
  var monsters := MONSTERS
  var monster_index := posmod(variant, monsters.size())
  return ASSET_ROOT + monsters[monster_index] + ".glb"
 if kind == "npc":
  return ASSET_ROOT + HUMANOIDS[posmod(variant + 3, HUMANOIDS.size())] + ".glb"
 if kind == "bot":
  return ASSET_ROOT + HUMANOIDS[posmod(variant + 1, HUMANOIDS.size())] + ".glb"
 return ASSET_ROOT + HUMANOIDS[index] + ".glb"
static func class_variant(class_id: String) -> int:
 return int(CLASS_VARIANTS.get(class_id, 0))
static func instantiate_rig(kind: String, variant: int = 0) -> Node3D:
 var path := asset_path(kind, variant)
 if not ResourceLoader.exists(path):
  push_warning("RiggedCharacterFactory: asset not imported yet: " + path)
  return null
 var packed := load(path) as PackedScene
 if packed == null:
  push_error("RiggedCharacterFactory: GLB did not import as PackedScene: " + path)
  return null
 var instance := packed.instantiate() as Node3D
 if instance == null:
  push_error("RiggedCharacterFactory: GLB root is not Node3D: " + path)
  return null
 instance.name = "Rigged_" + kind.capitalize()
 instance.set_meta("rigged_asset_path", path)
 return instance
static func attach_to(parent: Node3D, kind: String, variant: int = 0, scale_factor: float = 1.0) -> Node3D:
 var instance := instantiate_rig(kind, variant)
 if instance == null:
  return null
 instance.scale *= Vector3.ONE * scale_factor
 parent.add_child(instance)
 return instance
static func find_skeleton(root: Node) -> Skeleton3D:
 if root is Skeleton3D:
  return root
 for child in root.get_children():
  var found := find_skeleton(child)
  if found != null:
   return found
 return null
static func find_animation_player(root: Node) -> AnimationPlayer:
 if root is AnimationPlayer:
  return root
 for child in root.get_children():
  var found := find_animation_player(child)
  if found != null:
   return found
 return null
static func set_tint(root: Node, tint: Color) -> void:
 for node in root.find_children("*", "MeshInstance3D", true, false):
  var mesh_node := node as MeshInstance3D
  if mesh_node == null:
   continue
  var source: Material = mesh_node.material_override
  if source == null and mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
   source = mesh_node.mesh.surface_get_material(0)
  if source is StandardMaterial3D:
   var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
   material.albedo_color = material.albedo_color * tint
   mesh_node.material_override = material
static func _ensure_baked_action_clips(player: AnimationPlayer) -> void:
 if player.has_animation_library("Step17B"):
  return
 var names := player.get_animation_list()
 if names.is_empty():
  return
 var source := player.get_animation(str(names[0]))
 if source == null:
  return
 # Gobkit first-release GLBs bake four 30-frame actions at 24 fps into one timeline.
 var segments := [
  {"name":"Idle","first":0,"last":30,"loop":true},
  {"name":"Attack","first":30,"last":60,"loop":true},
  {"name":"Die","first":60,"last":90,"loop":false},
  {"name":"Walk","first":90,"last":120,"loop":true}
 ]
 var library := AnimationLibrary.new()
 for segment in segments:
  var start_time := float(segment.first) / 24.0
  var end_time := minf(float(segment.last) / 24.0, source.length)
  if end_time - start_time < 0.04:
   continue
  var clip := Animation.new()
  clip.length = end_time - start_time
  clip.loop_mode = Animation.LOOP_LINEAR if bool(segment.loop) else Animation.LOOP_NONE
  for source_track in range(source.get_track_count()):
   var target_track := clip.add_track(source.track_get_type(source_track))
   clip.track_set_path(target_track, source.track_get_path(source_track))
   clip.track_set_interpolation_type(target_track, source.track_get_interpolation_type(source_track))
   for key_index in range(source.track_get_key_count(source_track)):
    var key_time := source.track_get_key_time(source_track, key_index)
    if key_time >= start_time - 0.0001 and key_time <= end_time + 0.0001:
     clip.track_insert_key(target_track, clampf(key_time - start_time, 0.0, clip.length), source.track_get_key_value(source_track, key_index), source.track_get_key_transition(source_track, key_index))
  if clip.get_track_count() > 0:
   library.add_animation(str(segment.name), clip)
 if not library.get_animation_list().is_empty():
  player.add_animation_library("Step17B", library)
static func play_state(root: Node, state_name: String) -> bool:
 var player := find_animation_player(root)
 if player == null:
  return false
 _ensure_baked_action_clips(player)
 var state := state_name.to_lower()
 var clip_name := "Idle"
 if state in ["attack","hit"]:
  clip_name = "Attack"
 elif state in ["death","die"]:
  clip_name = "Die"
 elif state in ["walk","run","jump","fly"]:
  clip_name = "Walk" if player.has_animation("Step17B/Walk") else "Idle"
 var target := "Step17B/" + clip_name
 if not player.has_animation(target):
  var names := player.get_animation_list()
  if names.is_empty():
   return false
  target = str(names[0])
 if player.current_animation != target:
  player.play(target)
 return true
static func attach_bone_prop(root: Node3D, bone_candidates: Array[String], prop: Node3D) -> BoneAttachment3D:
 var skeleton := find_skeleton(root)
 if skeleton == null or prop == null:
  return null
 var bone_index := -1
 for index in range(skeleton.get_bone_count()):
  var bone_name := skeleton.get_bone_name(index).to_lower()
  for candidate in bone_candidates:
   if bone_name.contains(candidate.to_lower()):
    bone_index = index
    break
  if bone_index >= 0:
   break
 if bone_index < 0 and skeleton.get_bone_count() > 0:
  bone_index = 0
 if bone_index < 0:
  return null
 var attachment := BoneAttachment3D.new()
 attachment.bone_name = skeleton.get_bone_name(bone_index)
 attachment.add_child(prop)
 skeleton.add_child(attachment)
 return attachment

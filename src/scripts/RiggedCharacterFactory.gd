extends RefCounted
## Loads pinned offline GLB actors. Imported skeletons/animations are kept intact.
const ASSET_ROOT := "res://assets/rigged_characters/"
const HUMANOIDS := ["gobkit_Archer","gobkit_ShadowKunoichi","gobkit_HeavyWarrior","gobkit_KnightCaptain","gobkit_Priestess","gobkit_GongOverlord","gobkit_IronFanFighter","gobkit_TasselSpearMaster"]
const NPCS := ["gobkit_ClanSmith","gobkit_MarketVendor","gobkit_King","gobkit_Priestess","gobkit_CourtJester","gobkit_FarmOwner","gobkit_RoyalHerald","gobkit_Scout"]
const MONSTERS := ["gobkit_WerewolfCaptain","gobkit_TombMummy","gobkit_StitchedBrute","gobkit_NightWitch","gobkit_OrcLegionary","gobkit_OrcWarShaman","gobkit_BloodironJuggernaut","gobkit_Carnotaurus","gobkit_Spinosaurus","gobkit_Trex","gobkit_Manticora","gobkit_Scorpion","gobkit_Lion","gobkit_Fox"]
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
  return ASSET_ROOT + NPCS[posmod(variant, NPCS.size())] + ".glb"
 if kind == "bot":
  return ASSET_ROOT + HUMANOIDS[posmod(variant + 1, HUMANOIDS.size())] + ".glb"
 return ASSET_ROOT + HUMANOIDS[index] + ".glb"
static func class_variant(class_id: String) -> int:
 return int(CLASS_VARIANTS.get(class_id, 0))
static func npc_variant_for_role(role: String) -> int:
 var normalized := role.to_lower().replace(" ", "_")
 var roles := {
  "blacksmith":0,"merchant":1,"vault":2,"warehouse":2,
  "guild_director":6,"guild_master":6,"trainer":3,"advancement_trainer":3
 }
 return int(roles.get(normalized, 4))
static func instantiate_rig(kind: String, variant: int = 0) -> Node3D:
 var path := asset_path(kind, variant)
 if not ResourceLoader.exists(path):
  push_warning("RiggedCharacterFactory: imported GLB unavailable; using articulated humanoid fallback: " + path)
  return _build_articulated_fallback(kind, variant)
 var packed := load(path) as PackedScene
 if packed == null:
  push_warning("RiggedCharacterFactory: GLB could not be loaded; using articulated humanoid fallback: " + path)
  return _build_articulated_fallback(kind, variant)
 var instance := packed.instantiate() as Node3D
 if instance == null:
  push_warning("RiggedCharacterFactory: GLB root is not Node3D; using articulated humanoid fallback: " + path)
  return _build_articulated_fallback(kind, variant)
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
  var source: Material = mesh_node.get_meta("rigged_original_material", null) as Material
  if source == null:
   source = mesh_node.material_override
   if source == null and mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
    source = mesh_node.mesh.surface_get_material(0)
   if source != null:
    mesh_node.set_meta("rigged_original_material", source)
  if source is StandardMaterial3D:
   var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
   material.albedo_color = (source as StandardMaterial3D).albedo_color * tint
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
  if root != null and bool(root.get_meta("articulated_fallback", false)):
   _animate_articulated_fallback(root, state_name)
   return true
  return false
 var state := state_name.to_lower()
 var aliases := ["idle"]
 if state in ["attack"]:
  aliases = ["attack"]
 elif state in ["hit"]:
  aliases = ["hit","attack"]
 elif state in ["death","die"]:
  aliases = ["death","dead","die"]
 elif state in ["walk"]:
  aliases = ["walk"]
 elif state in ["run"]:
  aliases = ["run","walk"]
 elif state in ["jump"]:
  aliases = ["jump","walk"]
 elif state in ["fly"]:
  aliases = ["fly","walk"]
 var names := player.get_animation_list()
 for animation_name in names:
  var lowered := str(animation_name).to_lower()
  for alias in aliases:
   if lowered.ends_with("/" + alias) or lowered == alias or lowered.ends_with("_" + alias):
    if player.current_animation != str(animation_name):
     player.play(animation_name)
    return true
 _ensure_baked_action_clips(player)
 var clip_name := "Idle"
 if state in ["attack","hit"]:
  clip_name = "Attack"
 elif state in ["death","die"]:
  clip_name = "Die"
 elif state in ["walk","run","jump","fly"]:
  clip_name = "Walk" if player.has_animation("Step17B/Walk") else "Idle"
 var target := "Step17B/" + clip_name
 if not player.has_animation(target):
  if names.is_empty():
   return false
  target = str(names[0])
 if player.current_animation != target:
  player.play(target)
 return true
static func _fallback_material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.metallic = metallic
 material.roughness = 0.62
 return material

static func _fallback_part(parent: Node3D, part_name: String, mesh: Mesh, material: Material, position: Vector3) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.name = part_name
 node.mesh = mesh
 node.material_override = material
 node.position = position
 parent.add_child(node)
 return node

static func _fallback_capsule(radius: float, height: float) -> CapsuleMesh:
 var mesh := CapsuleMesh.new()
 mesh.radius = radius
 mesh.height = height
 return mesh

static func _build_articulated_fallback(kind: String, variant: int) -> Node3D:
 var root := Node3D.new()
 root.name = "Rigged_" + kind.capitalize() + "_ArticulatedFallback"
 root.set_meta("articulated_fallback", true)
 var armor := _fallback_material(Color("#315b82") if variant % 2 == 0 else Color("#7d2926"), 0.18)
 var trim := _fallback_material(Color("#d6ad4b"), 0.68)
 var cloth := _fallback_material(Color("#e0d0b4"))
 var skin := _fallback_material(Color("#d5a47d"))
 var dark := _fallback_material(Color("#252b35"), 0.12)
 var torso := BoxMesh.new()
 torso.size = Vector3(0.72, 0.92, 0.42)
 _fallback_part(root, "ArmoredTorso", torso, armor, Vector3(0.0, 1.38, 0.0))
 var chest := BoxMesh.new()
 chest.size = Vector3(0.76, 0.18, 0.46)
 _fallback_part(root, "ChestplateTrim", chest, trim, Vector3(0.0, 1.58, -0.015))
 var head := SphereMesh.new()
 head.radius = 0.235
 head.height = 0.47
 _fallback_part(root, "Head", head, skin, Vector3(0.0, 2.06, 0.0))
 var helmet := SphereMesh.new()
 helmet.radius = 0.255
 helmet.height = 0.24
 _fallback_part(root, "EasternHelmet", helmet, trim, Vector3(0.0, 2.23, 0.0))
 for side in [-1.0, 1.0]:
  var shoulder := SphereMesh.new()
  shoulder.radius = 0.19
  shoulder.height = 0.25
  _fallback_part(root, "ShoulderArmor_%s" % str(side), shoulder, trim, Vector3(side * 0.48, 1.73, 0.0))
  var arm_pivot := Node3D.new()
  arm_pivot.name = "ArmPivot_%s" % ("L" if side < 0.0 else "R")
  arm_pivot.position = Vector3(side * 0.49, 1.68, 0.0)
  root.add_child(arm_pivot)
  _fallback_part(arm_pivot, "UpperArm", _fallback_capsule(0.115, 0.52), armor, Vector3(0.0, -0.28, 0.0))
  var forearm_pivot := Node3D.new()
  forearm_pivot.name = "ForearmPivot"
  forearm_pivot.position = Vector3(0.0, -0.52, 0.0)
  arm_pivot.add_child(forearm_pivot)
  _fallback_part(forearm_pivot, "Forearm", _fallback_capsule(0.095, 0.46), cloth, Vector3(0.0, -0.23, 0.0))
  var hand := SphereMesh.new()
  hand.radius = 0.105
  hand.height = 0.2
  _fallback_part(forearm_pivot, "Hand", hand, skin, Vector3(0.0, -0.48, -0.015))
  var leg_pivot := Node3D.new()
  leg_pivot.name = "LegPivot_%s" % ("L" if side < 0.0 else "R")
  leg_pivot.position = Vector3(side * 0.205, 0.93, 0.0)
  root.add_child(leg_pivot)
  _fallback_part(leg_pivot, "Thigh", _fallback_capsule(0.145, 0.58), cloth, Vector3(0.0, -0.29, 0.0))
  var shin_pivot := Node3D.new()
  shin_pivot.name = "ShinPivot"
  shin_pivot.position = Vector3(0.0, -0.57, 0.0)
  leg_pivot.add_child(shin_pivot)
  _fallback_part(shin_pivot, "Shin", _fallback_capsule(0.115, 0.52), armor, Vector3(0.0, -0.25, 0.0))
  var foot := BoxMesh.new()
  foot.size = Vector3(0.29, 0.14, 0.42)
  _fallback_part(shin_pivot, "Boot", foot, dark, Vector3(0.0, -0.52, -0.10))
 # A paired blade/bow prop and back-mounted wings are attached to the articulated rig.
 var left_weapon := BoxMesh.new()
 left_weapon.size = Vector3(0.07, 0.48, 0.08)
 var right_weapon := BoxMesh.new()
 right_weapon.size = Vector3(0.07, 0.48, 0.08)
 var left_hand := root.get_node_or_null("ArmPivot_L/ForearmPivot")
 var right_hand := root.get_node_or_null("ArmPivot_R/ForearmPivot")
 if left_hand != null:
  _fallback_part(left_hand, "LeftEasternKnife", left_weapon, trim, Vector3(0.0, -0.55, -0.10))
 if right_hand != null:
  _fallback_part(right_hand, "RightEasternKnife", right_weapon, trim, Vector3(0.0, -0.55, -0.10))
 if variant % HUMANOIDS.size() == 0:
  var bow := TorusMesh.new()
  bow.inner_radius = 0.22
  bow.outer_radius = 0.27
  var bow_node := _fallback_part(root, "ArcherBow", bow, trim, Vector3(-0.62, 1.12, -0.18))
  bow_node.rotation_degrees.x = 90.0
 for side in [-1.0, 1.0]:
  var wing := PrismMesh.new()
  wing.size = Vector3(0.46, 0.76, 0.12)
  var wing_node := _fallback_part(root, "EasternWing_%s" % str(side), wing, armor, Vector3(side * 0.42, 1.45, 0.24))
  wing_node.rotation.z = side * -0.32
 return root

static func _animate_articulated_fallback(root: Node, state_name: String) -> void:
 var moving := state_name.to_lower() in ["run", "walk"]
 var jumping := state_name.to_lower() in ["jump", "fly"]
 var phase := float(Time.get_ticks_msec()) * 0.001 * (8.5 if moving else 2.0)
 var swing := sin(phase) * (0.72 if moving else 0.035)
 for side in ["L", "R"]:
  var arm := root.get_node_or_null("ArmPivot_" + side) as Node3D
  var leg := root.get_node_or_null("LegPivot_" + side) as Node3D
  if is_instance_valid(arm):
   arm.rotation.x = (-swing if side == "L" else swing) + (-0.35 if jumping else 0.0)
  if is_instance_valid(leg):
   leg.rotation.x = (swing if side == "L" else -swing) + (0.18 if jumping else 0.0)

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

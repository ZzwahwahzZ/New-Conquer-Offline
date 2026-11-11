extends SceneTree
const FACTORY = preload("res://src/scripts/RiggedCharacterFactory.gd")
const MATERIALS = preload("res://src/scripts/EquipmentMaterialLibrary.gd")
const ANIMA = preload("res://src/scripts/AnimaSystem.gd")
const AURA = preload("res://src/scripts/PlusAuraSystem.gd")
func _initialize() -> void:
 call_deferred("_run")
func _fail(message: String) -> void:
 push_error("STEP_17B_REGRESSION_FAIL: " + message)
 quit(1)
func _run() -> void:
 var paths := [
  "res://assets/rigged_characters/humanoid_01.glb",
  "res://assets/rigged_characters/humanoid_08.glb",
  "res://assets/rigged_characters/beast_bat.glb",
  "res://assets/rigged_characters/beast_rhino.glb"
 ]
 for path in paths:
  print("STEP_17B_CHECK_ASSET: " + path)
  if not ResourceLoader.exists(path):
   _fail("Missing rigged asset: " + path)
   return
  var packed := load(path) as PackedScene
  if packed == null:
   _fail("GLB import failed: " + path)
   return
  var instance := packed.instantiate()
  var skeleton := FACTORY.find_skeleton(instance)
  var animation_player := FACTORY.find_animation_player(instance)
  if skeleton == null or skeleton.get_bone_count() <= 0:
   _fail("No real Skeleton3D bones: " + path)
   instance.free()
   return
  if animation_player == null or animation_player.get_animation_list().is_empty():
   _fail("No imported AnimationPlayer clips: " + path)
   instance.free()
   return
  instance.free()
 var metal := MATERIALS.metal()
 var leather := MATERIALS.leather()
 var silk := MATERIALS.silk()
 if not is_equal_approx(metal.metallic,0.85) or not is_equal_approx(metal.roughness,0.25):
  _fail("Metal PBR values differ from specification")
  return
 if not is_equal_approx(leather.metallic,0.05) or not is_equal_approx(leather.roughness,0.55):
  _fail("Leather PBR values differ from specification")
  return
 if not is_equal_approx(silk.metallic,0.0) or not is_equal_approx(silk.roughness,0.85):
  _fail("Silk PBR values differ from specification")
  return
 print("STEP_17B_PBR_PASS")
 var actor := Node3D.new()
 root.add_child(actor)
 var aura := AURA.new()
 actor.add_child(aura)
 print("STEP_17B_AURA_CREATE")
 aura.set_level(12)
 if aura.plus_level != 12:
  _fail("+12 aura level was not applied")
  quit(1)
  return
 print("STEP_17B_ANIMA_CREATE")
 var seal := ANIMA.attach_ground_seal(actor,18)
 if seal.get_child_count() < 11 or not seal.visible:
  _fail("P18 ground seal is incomplete or hidden")
  return
 print("STEP_17B_RIGGED_ASSET_VFX_PASS")
 quit(0)

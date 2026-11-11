extends SceneTree
const FACTORY = preload("res://src/scripts/RiggedCharacterFactory.gd")
const MATERIALS = preload("res://src/scripts/EquipmentMaterialLibrary.gd")
const ANIMA = preload("res://src/scripts/AnimaSystem.gd")
const AURA = preload("res://src/scripts/PlusAuraSystem.gd")
func _initialize() -> void:
 call_deferred("_run")
func _run() -> void:
 var paths := [
  "res://assets/rigged_characters/humanoid_01.glb",
  "res://assets/rigged_characters/humanoid_08.glb",
  "res://assets/rigged_characters/beast_bat.glb",
  "res://assets/rigged_characters/beast_rhino.glb"
 ]
 for path in paths:
  assert(ResourceLoader.exists(path), "Missing rigged asset: " + path)
  var packed := load(path) as PackedScene
  assert(packed != null, "GLB import failed: " + path)
  var instance := packed.instantiate()
  var skeleton := FACTORY.find_skeleton(instance)
  var animation_player := FACTORY.find_animation_player(instance)
  assert(skeleton != null and skeleton.get_bone_count() > 0, "No real skeleton bones: " + path)
  assert(animation_player != null and not animation_player.get_animation_list().is_empty(), "No imported animation: " + path)
  instance.free()
 var metal := MATERIALS.metal()
 var leather := MATERIALS.leather()
 var silk := MATERIALS.silk()
 assert(is_equal_approx(metal.metallic,0.85) and is_equal_approx(metal.roughness,0.25))
 assert(is_equal_approx(leather.metallic,0.05) and is_equal_approx(leather.roughness,0.55))
 assert(is_equal_approx(silk.metallic,0.0) and is_equal_approx(silk.roughness,0.85))
 var actor := Node3D.new()
 root.add_child(actor)
 var aura := AURA.new()
 actor.add_child(aura)
 aura.set_level(12)
 assert(aura.plus_level == 12)
 var seal := ANIMA.attach_ground_seal(actor,18)
 assert(seal.get_child_count() >= 11 and seal.visible)
 print("STEP_17B_RIGGED_ASSET_VFX_PASS")
 quit(0)

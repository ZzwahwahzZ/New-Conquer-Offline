extends RefCounted
## Offline gold-funded P1..P18 Anima progression and world-space ground seal.
const MAX_LEVEL := 18
static func level_for(item_id: String) -> int:
 var levels: Dictionary = GameState.profile.get("anima_levels", {})
 return clampi(int(levels.get(item_id, 0)), 0, MAX_LEVEL)
static func upgrade_cost(next_level: int) -> int:
 var level := clampi(next_level, 1, MAX_LEVEL)
 return 250 * level * level
static func upgrade_item(item_id: String) -> bool:
 if item_id.strip_edges().is_empty():
  return false
 var current := level_for(item_id)
 if current >= MAX_LEVEL:
  return false
 var next_level := current + 1
 var cost := upgrade_cost(next_level)
 if not GlobalEconomy.remove_gold(cost):
  return false
 var levels: Dictionary = GameState.profile.get("anima_levels", {})
 levels[item_id] = next_level
 GameState.profile["anima_levels"] = levels
 if not GameState.save_local():
  GlobalEconomy.add_gold(cost)
  levels[item_id] = current
  return false
 return true
static func attach_ground_seal(actor: Node3D, level: int) -> Node3D:
 var old := actor.get_node_or_null("GroundAnimaSeal")
 if is_instance_valid(old):
  old.queue_free()
 var seal := Node3D.new()
 seal.name = "GroundAnimaSeal"
 seal.position = Vector3(0,0.035,0)
 actor.add_child(seal)
 var p := clampi(level, 0, MAX_LEVEL)
 if p == 0:
  seal.visible = false
  return seal
 var hue := float(p) / float(MAX_LEVEL)
 var color := Color(0.25 + hue * 0.75, 0.55 + hue * 0.3, 1.0 - hue * 0.62)
 for index in range(3):
  var ring := MeshInstance3D.new()
  var torus := TorusMesh.new()
  torus.inner_radius = 0.55 + float(index) * 0.16
  torus.outer_radius = torus.inner_radius + 0.025 + float(p) * 0.001
  ring.mesh = torus
  ring.rotation.x = deg_to_rad(90.0)
  var material := StandardMaterial3D.new()
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  material.albedo_color = Color(color.r,color.g,color.b,0.38 + float(p) * 0.025)
  material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  material.emission_enabled = true
  material.emission = color * (0.12 + float(p) * 0.045)
  ring.material_override = material
  seal.add_child(ring)
 for index in range(8):
  var mark := MeshInstance3D.new()
  var mesh := BoxMesh.new()
  mesh.size = Vector3(0.045,0.012,0.25 + float(p) * 0.008)
  mark.mesh = mesh
  mark.position = Vector3(0,0.012,0.76)
  mark.rotation.y = TAU * float(index) / 8.0
  var material := StandardMaterial3D.new()
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  material.albedo_color = color
  material.emission_enabled = true
  material.emission = color * (0.18 + float(p) * 0.04)
  mark.material_override = material
  seal.add_child(mark)
 seal.scale = Vector3.ONE * (0.82 + float(p) * 0.018)
 return seal

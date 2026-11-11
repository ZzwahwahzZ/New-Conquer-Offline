extends Node3D
const RiggedCharacterFactory = preload("res://src/scripts/RiggedCharacterFactory.gd")
## Lightweight +1..+12 upgrade aura; one controller per visible actor.
var plus_level := 0
var _ring: MeshInstance3D
var _halo: MeshInstance3D
var _sparkles: GPUParticles3D
var _wings: Array[MeshInstance3D] = []
var _time := 0.0
func _ready() -> void:
 _build()
 set_process(false)
func set_level(value: int) -> void:
 plus_level = clampi(value, 0, 12)
 if not is_inside_tree():
  return
 _apply_level()
func _build() -> void:
 if _ring != null:
  return
 _ring = MeshInstance3D.new()
 _ring.name = "PlusAuraRing"
 var torus := TorusMesh.new()
 torus.inner_radius = 0.58
 torus.outer_radius = 0.64
 _ring.mesh = torus
 _ring.rotation.x = deg_to_rad(90.0)
 add_child(_ring)
 _halo = MeshInstance3D.new()
 _halo.name = "PlusAuraHalo"
 var halo_mesh := SphereMesh.new()
 halo_mesh.radius = 0.72
 halo_mesh.height = 1.55
 _halo.mesh = halo_mesh
 add_child(_halo)
 # GPU particles are skipped in headless CI; the same controller enables them on devices.
 if DisplayServer.get_name() != "headless":
  _sparkles = GPUParticles3D.new()
  _sparkles.name = "PlusAuraSparks"
  _sparkles.amount = 12
  _sparkles.lifetime = 1.2
  _sparkles.emitting = false
  var particle_material := ParticleProcessMaterial.new()
  particle_material.direction = Vector3(0,1,0)
  particle_material.spread = 24.0
  particle_material.initial_velocity_min = 0.35
  particle_material.initial_velocity_max = 0.9
  particle_material.gravity = Vector3(0,0,0)
  _sparkles.process_material = particle_material
  add_child(_sparkles)
 for side in [-1.0, 1.0]:
  var wing := MeshInstance3D.new()
  wing.name = "AscensionWingLeft" if side < 0.0 else "AscensionWingRight"
  var wing_mesh := PlaneMesh.new()
  wing_mesh.size = Vector2(0.72, 1.35)
  wing.mesh = wing_mesh
  wing.position = Vector3(side * 0.56, 1.05, 0.34)
  wing.rotation.z = side * -0.28
  var wing_material := StandardMaterial3D.new()
  wing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  wing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  wing_material.albedo_color = Color(1.0,0.82,0.38,0.42)
  wing_material.emission_enabled = true
  wing_material.emission = Color(1.0,0.62,0.12) * 0.8
  wing.material_override = wing_material
  wing.visible = false
  var rig_root := get_parent() as Node3D
  var attachment := RiggedCharacterFactory.attach_bone_prop(rig_root, ["spine", "chest", "back", "root"], wing) if rig_root != null else null
  if attachment == null:
   add_child(wing)
  _wings.append(wing)
 _apply_level()
func _apply_level() -> void:
 if _ring == null:
  return
 var gold := Color(1.0,0.72,0.18)
 var pale := Color(1.0,0.9,0.52)
 var tier_color := Color(0.3,0.75,1.0) if plus_level < 7 else gold
 var ring_mat := StandardMaterial3D.new()
 ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 ring_mat.albedo_color = Color(tier_color.r,tier_color.g,tier_color.b,0.72)
 ring_mat.emission_enabled = true
 ring_mat.emission = tier_color * (0.15 + float(plus_level) * 0.055)
 ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 _ring.material_override = ring_mat
 _ring.visible = plus_level >= 1
 _ring.scale = Vector3.ONE * (0.78 + float(plus_level) * 0.045)
 var halo_mat := StandardMaterial3D.new()
 halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 halo_mat.albedo_color = Color(tier_color.r,tier_color.g,tier_color.b,0.06 + float(plus_level) * 0.012)
 halo_mat.emission_enabled = true
 halo_mat.emission = tier_color * (0.04 + float(plus_level) * 0.035)
 _halo.material_override = halo_mat
 _halo.visible = plus_level >= 4
 _halo.scale = Vector3(0.95 + float(plus_level) * 0.035,1.0,0.95 + float(plus_level) * 0.035)
 if is_instance_valid(_sparkles):
  _sparkles.emitting = plus_level >= 7
  _sparkles.amount = 6 + plus_level * 2
 for wing in _wings:
  wing.visible = plus_level == 12
 set_process(plus_level >= 7)
 if plus_level == 12:
  _ring.scale = Vector3.ONE * 1.42
  _halo.visible = true
func _process(delta: float) -> void:
 _time += delta
 if _sparkles != null and plus_level >= 7:
  _sparkles.position.y = 0.7 + sin(_time * 2.2) * 0.08

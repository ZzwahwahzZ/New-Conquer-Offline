extends SceneTree
const PBR = preload("res://src/scripts/PBRMaterialLibrary.gd")
func _initialize() -> void:
 for environment_id in ["TwinCity","DesertLand","VolcanoLand","IceLand","Waterlands","DarkForest"]:
  var material: StandardMaterial3D = PBR.build_ground_material(environment_id)
  assert(material != null)
  assert(material.albedo_texture != null)
  assert(material.normal_enabled)
  assert(material.normal_texture != null)
  assert(material.roughness_texture != null)
  assert(material.uv1_triplanar)
 var lava: StandardMaterial3D = PBR.build_emissive_material(Color("#ff4b12"))
 assert(lava.emission_enabled)
 print("PBR_MATERIAL_LIBRARY_PASS: six environments, normal/roughness maps, triplanar and emission fallback")
 quit(0)
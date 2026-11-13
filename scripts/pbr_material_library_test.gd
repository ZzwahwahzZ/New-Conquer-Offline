extends SceneTree

func get_tree() -> SceneTree:
	return self
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
	var street: StandardMaterial3D = PBR.build_street_material()
	assert(street != null and street.resource_name == "PolyHaven_Pavement05_Street" and street.albedo_texture != null and street.normal_enabled and street.normal_texture != null and street.roughness_texture != null)
	var plaza: StandardMaterial3D = PBR.build_plaza_material()
	assert(plaza != null and plaza.resource_name == "PolyHaven_StonePathway_Plaza" and plaza.albedo_texture != null and plaza.normal_enabled and plaza.normal_texture != null and plaza.roughness_texture != null)
	var lava: StandardMaterial3D = PBR.build_emissive_material(Color("#ff4b12"))
	assert(lava.emission_enabled)
	print("PBR_MATERIAL_LIBRARY_PASS: six terrain environments plus Poly Haven street/plaza Albedo+Normal+Roughness maps and emission fallback")
	get_tree().quit(0)
extends RefCounted
## Shared mobile PBR material factory. Missing maps always fall back to generated textures.
const MATERIAL_ROOT := "res://assets/environment/materials/"
const MAPS := {
 "TwinCity": "Ground044_2K-JPG",
 "DesertLand": "Ground061_2K-JPG",
 "VolcanoLand": "Rock027_2K-JPG",
 "IceLand": "Snow008C_2K-JPG",
 "Waterlands": "Ground044_2K-JPG",
 "DarkForest": "Ground053_2K-JPG"
}
const BASE_COLORS := {
 "TwinCity": Color("#b9ad98"), "DesertLand": Color("#c6a064"),
 "VolcanoLand": Color("#51464a"), "IceLand": Color("#d7edf5"),
 "Waterlands": Color("#648c70"), "DarkForest": Color("#344a38")
}
const EMISSIVE := {"VolcanoLand": Color("#ff4b12")}

static func build_ground_material(environment_id: String, triplanar: bool = true) -> StandardMaterial3D:
 var key: String = str(MAPS.get(environment_id, "Ground044_2K-JPG"))
 var folder: String = MATERIAL_ROOT + key + "/"
 var material := StandardMaterial3D.new()
 material.resource_name = environment_id + "_PBR_Ground"
 material.albedo_color = Color.WHITE
 material.albedo_texture = _load_map(folder + "albedo.jpg", _fallback_texture("albedo", environment_id))
 material.normal_enabled = true
 material.normal_texture = _load_map(folder + "normal.jpg", _fallback_texture("normal", environment_id))
 material.roughness = 0.92
 material.roughness_texture = _load_map(folder + "roughness.jpg", _fallback_texture("roughness", environment_id))
 material.metallic = 0.0
 material.uv1_triplanar = triplanar
 material.uv1_triplanar_sharpness = 4.0
 material.uv1_scale = Vector3(0.12, 0.12, 0.12)
 material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 if EMISSIVE.has(environment_id):
  material.emission_enabled = true
  material.emission = EMISSIVE[environment_id]
  material.emission_energy_multiplier = 0.7
 return material

static func build_emissive_material(color: Color, energy: float = 1.5, roughness_value: float = 0.35) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.albedo_color = color
 material.roughness = roughness_value
 material.emission_enabled = true
 material.emission = color
 material.emission_energy_multiplier = energy
 return material

static func _load_map(path: String, fallback: Texture2D) -> Texture2D:
 if FileAccess.file_exists(path):
  var loaded := load(path) as Texture2D
  if loaded != null:
   return loaded
 return fallback

static func _fallback_texture(kind: String, environment_id: String) -> Texture2D:
 var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
 var base: Color = BASE_COLORS.get(environment_id, Color("#777777"))
 var noise := FastNoiseLite.new()
 noise.seed = abs(hash(environment_id + kind)) % 100000
 noise.frequency = 0.045
 for y in range(128):
  for x in range(128):
   var n := noise.get_noise_2d(float(x), float(y))
   var pixel := Color(0.5 + n * 0.035, 0.5 + n * 0.035, 1.0, 1.0)
   if kind == "albedo":
    pixel = base * clampf(0.88 + n * 0.18, 0.65, 1.08)
   elif kind == "roughness":
    var rough := clampf(0.88 + n * 0.08, 0.72, 1.0)
    pixel = Color(rough, rough, rough, 1.0)
   image.set_pixel(x, y, pixel)
 return ImageTexture.create_from_image(image)

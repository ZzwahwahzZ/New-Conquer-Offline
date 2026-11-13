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
 "TwinCity": Color("#b9ad98"), "DesertLand": Color("#D4A359"),
 "VolcanoLand": Color("#51464a"), "IceLand": Color("#A8D0E6"),
 "Waterlands": Color("#648c70"), "DarkForest": Color("#344a38")
}
const EMISSIVE := {"VolcanoLand": Color("#ff4b12")}

static func build_ground_material(environment_id: String, triplanar: bool = true, pack_override: String = "") -> StandardMaterial3D:
 var key: String = pack_override if not pack_override.is_empty() else str(MAPS.get(environment_id, "Ground044_2K-JPG"))
 var folder: String = MATERIAL_ROOT + key + "/"
 var material := StandardMaterial3D.new()
 material.resource_name = environment_id + "_PBR_Ground"
 material.albedo_color = Color.WHITE
 if environment_id in ["DesertLand", "IceLand"]:
  material.albedo_color = BASE_COLORS[environment_id]
 var albedo_map: Texture2D = _load_first_map([folder.path_join("albedo.jpg"), folder.path_join("albedo.png"), folder.path_join("albedo.webp")])
 material.albedo_texture = albedo_map if albedo_map != null else _fallback_texture()
 material.normal_enabled = true
 var normal_map: Texture2D = _load_first_map([folder.path_join("normal.jpg"), folder.path_join("normal.png"), folder.path_join("normal.webp")])
 material.normal_texture = normal_map if normal_map != null else _fallback_texture()
 if environment_id == "TwinCity":
  material.normal_scale = 1.18
  material.albedo_color = Color(1.08, 1.08, 1.08, 1.0)
 material.roughness = 0.88
 material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
 var roughness_map: Texture2D = _load_first_map([folder.path_join("roughness.jpg"), folder.path_join("roughness.png"), folder.path_join("roughness.webp")])
 material.roughness_texture = roughness_map if roughness_map != null else _fallback_texture()
 material.metallic = 0.0
 material.uv1_triplanar = triplanar
 material.uv1_triplanar_sharpness = 4.0
 material.uv1_scale = Vector3(0.085, 0.085, 0.085) if triplanar else Vector3(24.0, 24.0, 1.0)
 if environment_id == "TwinCity" and triplanar:
  material.uv1_scale = Vector3(0.095, 0.095, 0.095)
 material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 material.cull_mode = BaseMaterial3D.CULL_DISABLED
 var emission_map: Texture2D = _load_first_map([folder.path_join("emission.jpg"), folder.path_join("emission.png"), folder.path_join("emission.webp")])
 if emission_map != null:
  material.emission_enabled = true
  material.emission_texture = emission_map
 if EMISSIVE.has(environment_id):
  material.emission_enabled = true
  material.emission = EMISSIVE[environment_id]
  material.emission_energy_multiplier = 0.7
 return material

static func build_street_material() -> StandardMaterial3D:
    return _build_polyhaven_material("cobblestone_floor_04", "PolyHaven_CobblestoneFloor04_Street")

static func build_plaza_material() -> StandardMaterial3D:
    return _build_polyhaven_material("marble_01", "PolyHaven_Marble01_Plaza")

static func build_imperial_paving_material() -> StandardMaterial3D:
    return _build_polyhaven_material("stone_tiles_02", "PolyHaven_StoneTiles02_ImperialPaving")

static func _build_polyhaven_material(asset_id: String, display_name: String) -> StandardMaterial3D:
    var root := "res://assets/environment/materials/polyhaven/" + asset_id + "/"
    var albedo_path := root + "albedo.jpg"
    var normal_path := root + "normal.jpg"
    var roughness_path := root + "roughness.jpg"
    if not FileAccess.file_exists(albedo_path) or not FileAccess.file_exists(normal_path) or not FileAccess.file_exists(roughness_path):
        push_error("Missing verified Poly Haven PBR maps for " + asset_id)
        return build_ground_material("TwinCity", false, "Ground044_2K-JPG")
    var material := StandardMaterial3D.new()
    material.resource_name = display_name
    material.albedo_texture = load(albedo_path) as Texture2D
    material.normal_enabled = true
    material.normal_texture = load(normal_path) as Texture2D
    material.normal_scale = 1.0
    material.roughness_texture = load(roughness_path) as Texture2D
    material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
    material.roughness = 0.92
    material.metallic = 0.0
    material.uv1_triplanar = false
    material.uv1_scale = Vector3.ONE
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return material


static func build_emissive_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.resource_name = "Generated_Emissive_Material"
    material.albedo_color = color
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.0
    material.roughness = 0.42
    return material

static func _fallback_texture() -> ImageTexture:
    return ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))

static func _load_first_map(paths: Array) -> Texture2D:
    for path_value in paths:
        var path := str(path_value)
        if path.is_empty() or not ResourceLoader.exists(path):
            continue
        var texture := ResourceLoader.load(path) as Texture2D
        if texture != null:
            return texture
    return null

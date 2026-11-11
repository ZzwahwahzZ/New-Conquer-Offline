extends RefCounted
## PBR presets for Conquer-style equipment and rarity tiers.
const RARITY_COLORS := {
 "Normal":Color(0.78,0.78,0.78),"Refined":Color(0.25,0.9,0.35),
 "Unique":Color(0.25,0.62,1.0),"Elite":Color(0.72,0.38,1.0),
 "Super":Color(1.0,0.72,0.16)
}
static func metal(color: Color = Color(0.72,0.76,0.82)) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = color
 m.metallic = 0.85
 m.roughness = 0.25
 return m
static func leather(color: Color = Color(0.28,0.13,0.065)) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = color
 m.metallic = 0.05
 m.roughness = 0.55
 return m
static func silk(color: Color = Color(0.62,0.12,0.18)) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = color
 m.metallic = 0.0
 m.roughness = 0.85
 return m
static func rarity_material(tier: String, base: StandardMaterial3D = null) -> StandardMaterial3D:
 var result := base.duplicate() as StandardMaterial3D if base != null else metal()
 var tint: Color = RARITY_COLORS.get(tier, RARITY_COLORS.Normal)
 result.albedo_color = result.albedo_color * tint
 if tier in ["Unique","Elite","Super"]:
  result.emission_enabled = true
  result.emission = tint * (0.12 if tier == "Unique" else 0.2 if tier == "Elite" else 0.32)
 return result

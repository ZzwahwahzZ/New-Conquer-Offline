extends Node3D
const WorldTerrainBuilder = preload("res://src/scripts/WorldTerrainBuilder.gd")
const ChineseImperialBuilder = preload("res://src/scripts/ChineseImperialBuilder.gd")
## Environment shell with named anchors for later production map assets.
@export var settlement_id := "TwinCity"
@export var display_name := "Twin City"
@export var level_min := 1
@export var level_max := 15
@export var ground_color := Color(0.22,0.38,0.2)
@export var fog_color := Color(0.55,0.68,0.62)
@export var sky_color := Color(0.36,0.55,0.72)
@export_range(0.0,0.04,0.001) var fog_density := 0.006
@export var landmark_color := Color(0.55,0.48,0.32)

func _ready() -> void:
	_configure_city_atmosphere()
	_build_environment()
	_build_asset_slots()
	_build_terrain_shell()
	ChineseImperialBuilder.build(get_node("ArchitectureAssetSlot"), settlement_id, 600.0 if settlement_id == "TwinCity" else 450.0)
	_build_landmarks()
	_build_sanctuary_landmarks()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "SettlementEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#4B83B8") if settlement_id == "TwinCity" else sky_color.lightened(0.12)
	sky_material.sky_horizon_color = sky_color
	sky_material.ground_bottom_color = fog_color.darkened(0.22)
	sky_material.ground_horizon_color = fog_color
	sky.sky_material = sky_material
	environment.sky = sky
	environment.background_color = sky_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = sky_color.lightened(0.25)
	environment.ambient_light_energy = 0.85
	environment.fog_enabled = true
	environment.fog_light_color = fog_color
	environment.fog_density = fog_density
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "SettlementSun"
	sun.rotation_degrees = Vector3(-45,-32,0)
	sun.light_energy = 1.3
	sun.shadow_enabled = not OS.has_feature("web")
	sun.shadow_blur = 1.4 if not OS.has_feature("web") else 0.0
	add_child(sun)

func _build_asset_slots() -> void:
	for slot_name in ["TerrainAssetSlot","ArchitectureAssetSlot","FoliageAssetSlot","AmbientFXSlot","MonsterSpawnAnchors","SanctuaryAnchors","PortalAnchors"]:
		var slot := Node3D.new()
		slot.name = slot_name
		add_child(slot)
	var sanctuary_slot := get_node("SanctuaryAnchors")
	for anchor_data in [{"name":"RareSanctuaryNorthEast","position":Vector3(66,0,62)},{"name":"BossSanctuarySouthWest","position":Vector3(-68,0,-60)}]:
		var marker := Marker3D.new()
		marker.name = str(anchor_data.name)
		marker.position = anchor_data.position
		sanctuary_slot.add_child(marker)
	var portal_slot := get_node("PortalAnchors")
	var portal_marker := Marker3D.new()
	portal_marker.name = "NextSettlementPortal"
	portal_marker.position = Vector3(0,0,-78)
	portal_slot.add_child(portal_marker)
	var spawn_slot := get_node("MonsterSpawnAnchors")
	for index in range(6):
		var marker := Marker3D.new()
		marker.name = "FieldSpawn_%02d" % index
		marker.position = [Vector3(14,0,12),Vector3(-16,0,10),Vector3(20,0,-16),Vector3(-22,0,-18),Vector3(3,0,-28),Vector3(29,0,24)][index]
		spawn_slot.add_child(marker)

func _build_terrain_shell() -> void:
	WorldTerrainBuilder.build(self, settlement_id, get_node("TerrainAssetSlot"))


func _build_landmarks() -> void:
	var slot := get_node_or_null("ArchitectureAssetSlot") as Node3D
	if slot == null:
		return
	# Keep a clear, walkable landmark anchor in the central district.
	var marker := Marker3D.new()
	marker.name = "CentralLandmarkAnchor"
	marker.position = Vector3(0.0, 0.0, 0.0)
	slot.add_child(marker)

func _build_sanctuary_landmarks() -> void:
	var slot := get_node_or_null("SanctuaryAnchors") as Node3D
	if slot == null:
		return
	# The sanctuary markers are created with the asset slots; ensure stable names
	# and positions for quest/spawn systems.
	var rare := slot.get_node_or_null("RareSanctuaryNorthEast") as Marker3D
	if rare != null:
		rare.position = Vector3(66.0, 0.0, 62.0)
	var boss := slot.get_node_or_null("BossSanctuarySouthWest") as Marker3D
	if boss != null:
		boss.position = Vector3(-68.0, 0.0, -60.0)

func _configure_city_atmosphere() -> void:
	match settlement_id:
		"TwinCity":
			sky_color = Color("#f5c982")
			fog_color = Color("#e9c58c")
			fog_density = 0.0018
		"DesertLand":
			sky_color = Color("#d8ae70")
			fog_color = Color("#d6a65f")
			fog_density = 0.009
		"VolcanoLand":
			sky_color = Color("#6d3425")
			fog_color = Color("#d66a32")
			fog_density = 0.007
		"IceLand":
			sky_color = Color("#8fc9e7")
			fog_color = Color("#a8d9f0")
			fog_density = 0.006
		"Waterlands":
			sky_color = Color("#76c7c6")
			fog_color = Color("#83d6ce")
			fog_density = 0.004
		"DarkForest":
			sky_color = Color("#183b32")
			fog_color = Color("#36745a")
			fog_density = 0.012

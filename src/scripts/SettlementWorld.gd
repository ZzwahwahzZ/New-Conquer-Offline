extends Node3D
const WorldTerrainBuilder = preload("res://src/scripts/WorldTerrainBuilder.gd")
const ChineseImperialBuilder = preload("res://src/scripts/ChineseImperialBuilder.gd")
const CityArchitectureBuilder = preload("res://src/scripts/CityArchitectureBuilder.gd")
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
	position = Vector3.ZERO
	_configure_city_atmosphere()
	_build_environment()
	_build_asset_slots()
	_build_terrain_shell()
	var city_id := "twin_city" if settlement_id == "TwinCity" else settlement_id.to_lower()
	if city_id == "twin_city":
		CityArchitectureBuilder.build_twin_city(get_node("ArchitectureAssetSlot"))
	else:
		CityArchitectureBuilder.build(get_node("ArchitectureAssetSlot"), settlement_id, 450.0)
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
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	if settlement_id == "TwinCity":
		environment.adjustment_enabled = true
		environment.adjustment_brightness = 0.94
		environment.adjustment_contrast = 1.04
		environment.adjustment_saturation = 0.92
	environment.ssao_enabled = true
	environment.ssao_radius = 2.4
	environment.ssao_intensity = 1.35
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = sky_color.lightened(0.25)
	environment.ambient_light_energy = 0.42
	environment.fog_enabled = false
	environment.fog_light_color = fog_color
	environment.fog_density = fog_density
	environment.glow_enabled = false
	environment.glow_intensity = 0.0
	environment.glow_strength = 0.0
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 0.82
	environment.glow_hdr_scale = 1.0
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "SettlementSun"
	sun.rotation_degrees = Vector3(-45,-32,0)
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 220.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 0.8
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
	var marker := Marker3D.new()
	marker.name = "CentralLandmarkAnchor"
	marker.position = Vector3.ZERO
	slot.add_child(marker)
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3.ZERO
	slot.add_child(spawn)

func _build_twincity_reference_landmarks(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "TwinCityReferenceLandmarks"
	parent.add_child(root)
	for data in [
		{"name":"NorthWestReferencePillar","position":Vector3(-12.0,0.0,-12.0)},
		{"name":"NorthEastReferencePillar","position":Vector3(12.0,0.0,-12.0)},
		{"name":"SouthWestReferencePillar","position":Vector3(-12.0,0.0,12.0)},
		{"name":"SouthEastReferencePillar","position":Vector3(12.0,0.0,12.0)}
	]:
		_add_reference_pillar(root, str(data.name), data.position, 4.6)
	var gate := Node3D.new()
	gate.name = "TwinCitySouthGate"
	gate.position = Vector3(0.0,0.0,-28.0)
	root.add_child(gate)
	_add_reference_pillar(gate, "GateLeftPost", Vector3(-7.0,0.0,0.0), 5.2)
	_add_reference_pillar(gate, "GateRightPost", Vector3(7.0,0.0,0.0), 5.2)
	_add_reference_box(gate, "GateCrossbeam", Vector3(0.0,5.45,0.0), Vector3(15.2,0.62,0.9), Color("#8d3029"), 0.35)
	_add_reference_box(gate, "GateRoof", Vector3(0.0,5.95,0.0), Vector3(17.0,0.28,1.45), Color("#b88a42"), 0.48)
	_add_reference_box(gate, "GateRoofRidge", Vector3(0.0,6.18,0.0), Vector3(15.8,0.18,0.62), Color("#344f48"), 0.55)

func _add_reference_pillar(parent: Node3D, pillar_name: String, origin: Vector3, height: float) -> void:
	var pillar := Node3D.new()
	pillar.name = pillar_name
	pillar.position = origin
	parent.add_child(pillar)
	var base := CylinderMesh.new()
	base.top_radius = 0.72
	base.bottom_radius = 0.84
	base.height = 0.42
	base.radial_segments = 12
	_add_reference_mesh(pillar, "StoneBase", base, Vector3(0.0,0.21,0.0), Color("#8b806b"), 0.78)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.39
	shaft.bottom_radius = 0.43
	shaft.height = height
	shaft.radial_segments = 12
	_add_reference_mesh(pillar, "RedPillarShaft", shaft, Vector3(0.0,0.42 + height * 0.5,0.0), Color("#963d31"), 0.62)
	var capital := CylinderMesh.new()
	capital.top_radius = 0.76
	capital.bottom_radius = 0.68
	capital.height = 0.34
	capital.radial_segments = 12
	_add_reference_mesh(pillar, "GoldPillarCapital", capital, Vector3(0.0,0.42 + height + 0.17,0.0), Color("#c49a4c"), 0.42)

func _add_reference_mesh(parent: Node3D, node_name: String, mesh: Mesh, local_position: Vector3, color: Color, roughness_value: float) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.position = local_position
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	parent.add_child(visual)
	visual.material_override = material

func _add_reference_box(parent: Node3D, node_name: String, local_position: Vector3, dimensions: Vector3, color: Color, roughness_value: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_add_reference_mesh(parent, node_name, mesh, local_position, color, roughness_value)

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

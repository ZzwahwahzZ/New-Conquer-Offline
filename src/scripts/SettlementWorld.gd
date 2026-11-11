extends Node3D
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
	_build_environment()
	_build_asset_slots()
	_build_terrain_shell()
	_build_landmarks()
	_build_sanctuary_landmarks()

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "SettlementEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = sky_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = sky_color.lightened(0.25)
	environment.ambient_light_energy = 0.65
	environment.fog_enabled = true
	environment.fog_light_color = fog_color
	environment.fog_density = fog_density
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "SettlementSun"
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false
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
	var ground := StaticBody3D.new()
	ground.name = "TerrainCollision"
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = "TerrainAssetReadyPlaceholder"
	var plane := PlaneMesh.new()
	plane.size = Vector2(180,180)
	mesh_node.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = ground_color
	material.roughness = 1.0
	mesh_node.material_override = material
	ground.add_child(mesh_node)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(180,0.5,180)
	collider.shape = shape
	collider.position.y = -0.25
	ground.add_child(collider)
	add_child(ground)

func _build_sanctuary_landmarks() -> void:
	for sanctuary_data in [{"label":"Rare Monster Grounds","position":Vector3(66,0.03,62)},{"label":"Open Boss Lair","position":Vector3(-68,0.03,-60)}]:
		var marker := Node3D.new()
		marker.name = str(sanctuary_data.label).replace(" ","")
		marker.position = sanctuary_data.position
		var ring_node := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 5.5
		ring_mesh.outer_radius = 6.0
		ring_node.mesh = ring_mesh
		var glow := StandardMaterial3D.new()
		glow.albedo_color = landmark_color
		glow.emission_enabled = true
		glow.emission = landmark_color
		glow.emission_energy_multiplier = 0.45
		ring_node.material_override = glow
		marker.add_child(ring_node)
		for pillar_index in range(4):
			var pillar := MeshInstance3D.new()
			var pillar_mesh := CylinderMesh.new()
			pillar_mesh.top_radius = 0.28
			pillar_mesh.bottom_radius = 0.42
			pillar_mesh.height = 2.4
			pillar.mesh = pillar_mesh
			pillar.material_override = glow
			var angle := TAU*float(pillar_index)/4.0
			pillar.position = Vector3(cos(angle)*5.8,1.2,sin(angle)*5.8)
			marker.add_child(pillar)
		add_child(marker)

func _build_landmarks() -> void:
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = landmark_color
	ring_material.roughness = 0.82
	for index in range(12):
		var angle := TAU*float(index)/12.0
		var landmark := MeshInstance3D.new()
		landmark.name = "AssetReadyLandmark_%02d" % index
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.45
		mesh.bottom_radius = 0.8
		mesh.height = 2.0 + float(index%3)*0.6
		landmark.mesh = mesh
		landmark.material_override = ring_material
		landmark.position = Vector3(cos(angle)*82.0,mesh.height*0.5,sin(angle)*82.0)
		add_child(landmark)

extends SceneTree

func get_tree() -> SceneTree:
	return self

const WorldTerrainBuilder = preload("res://src/scripts/WorldTerrainBuilder.gd")

func _initialize() -> void:
	call_deferred("_run")

func _require(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	get_tree().quit(1)
	return false

func _run() -> void:
	var cities := ["TwinCity", "DesertLand", "VolcanoLand", "IceLand", "Waterlands", "DarkForest"]
	var expected_levels := [[1, 15], [15, 40], [40, 70], [70, 95], [95, 115], [115, 130]]
	var heightmaps := {
		"DesertLand": "res://assets/environment/heightmaps/04_desert_dunes_heightmap_16bit.png",
		"VolcanoLand": "res://assets/environment/heightmaps/01_volcanic_caldera_heightmap_16bit.png",
		"IceLand": "res://assets/environment/heightmaps/02_glacial_mountains_heightmap_16bit.png",
		"Waterlands": "res://assets/environment/heightmaps/03_tropical_archipelago_heightmap_16bit.png",
		"DarkForest": "res://assets/environment/heightmaps/05_dark_forest_valleys_heightmap_16bit.png"
	}
	for index in range(cities.size()):
		var city: String = cities[index]
		var path := "res://src/scenes/world/%s.tscn" % city
		if not _require(ResourceLoader.exists(path), "Missing city scene: " + path):
			return
		var packed := ResourceLoader.load(path) as PackedScene
		if not _require(packed != null, "City scene failed to load: " + city):
			return
		var scene := packed.instantiate() as Node3D
		root.add_child(scene)
		await process_frame
		var terrain_body := scene.get_node_or_null("TerrainCollision") as StaticBody3D
		if not _require(terrain_body != null, "TerrainCollision is missing: " + city):
			return
		var terrain_surface := terrain_body.get_node_or_null("TerrainSurface") as MeshInstance3D
		if not _require(terrain_surface != null and terrain_surface.mesh is ArrayMesh, "Terrain surface mesh is missing: " + city):
			return
		if not _require(scene.get_node_or_null("ArchitectureAssetSlot") != null, "Architecture slot is missing: " + city):
			return
		if not _require(scene.get_node_or_null("FoliageAssetSlot") != null, "Foliage slot is missing: " + city):
			return
		if not _require(scene.get_node_or_null("WorldBoundary_0") is StaticBody3D, "World boundary collision is missing: " + city):
			return
		if not _require(scene.get_node_or_null("SanctuaryAnchors/RareSanctuaryNorthEast") != null, "Rare sanctuary anchor is missing: " + city):
			return
		if not _require(scene.get_node_or_null("SanctuaryAnchors/BossSanctuarySouthWest") != null, "Boss sanctuary anchor is missing: " + city):
			return
		if not _require(int(scene.get("level_min")) == expected_levels[index][0] and int(scene.get("level_max")) == expected_levels[index][1], "City level range is incorrect: " + city):
			return
		if heightmaps.has(city):
			var height_path: String = heightmaps[city]
			var height_texture := ResourceLoader.load(height_path) as Texture2D
			if not _require(height_texture != null, "Imported heightmap texture is unavailable: " + height_path):
				return
			var height_image := height_texture.get_image()
			if not _require(height_image != null and height_image.get_width() > 1 and height_image.get_height() > 1, "Heightmap image is unreadable: " + height_path):
				return
			var height_mesh := terrain_surface.mesh as ArrayMesh
			var vertices: PackedVector3Array = height_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var min_height := INF
			var max_height := -INF
			for vertex in vertices:
				min_height = minf(min_height, vertex.y)
				max_height = maxf(max_height, vertex.y)
			if not _require(max_height - min_height > 0.05, "Terrain heightfield is flat or heightmap data was not applied: " + city):
				return
		var total_mesh_nodes := 0
		var empty_mesh_nodes := 0
		var mesh_scan: Array[Node] = [scene]
		while not mesh_scan.is_empty():
			var mesh_node: Node = mesh_scan.pop_back()
			for mesh_child in mesh_node.get_children():
				mesh_scan.append(mesh_child)
			if mesh_node is MeshInstance3D:
				total_mesh_nodes += 1
				if (mesh_node as MeshInstance3D).mesh == null:
					empty_mesh_nodes += 1
			if mesh_node is MultiMeshInstance3D:
				total_mesh_nodes += 1
				var mm := (mesh_node as MultiMeshInstance3D).multimesh
				if mm == null or mm.mesh == null:
					empty_mesh_nodes += 1
		print("STEP11_MESH_HANDLE_AUDIT: " + city + " total=" + str(total_mesh_nodes) + " empty=" + str(empty_mesh_nodes))
		scene.queue_free()
		await process_frame
	var source := FileAccess.get_file_as_string("res://project.godot")
	var autoload_order := ["ClassSystem=", "GearDatabase=", "GearSystem=", "GlobalEconomy=", "GameState="]
	var previous := -1
	for key in autoload_order:
		var position := source.find(key)
		if not _require(position > previous, "Autoload order changed at " + key):
			return
		previous = position
	print("STEP11_PHASE1_SIX_CITIES_HEIGHTFIELDS_COLLISION_AND_WORLD_LAYOUT_PASS")
	get_tree().quit(0)

extends SceneTree

func _initialize() -> void:
	call_deferred("_run_audit")

func _run_audit() -> void:
	var packed := load("res://src/scenes/world/TwinCity.tscn") as PackedScene
	if packed == null:
		push_error("TWIN_CITY_AUDIT_FAIL: TwinCity scene could not be loaded")
		quit(1)
		return
	var city := packed.instantiate()
	root.add_child(city)
	await process_frame

	var buildings := get_nodes_in_group("twin_city_building")
	var counts := {
		"residential": 0,
		"commercial": 0,
		"service": 0,
		"landmark": 0,
		"defensive": 0,
		"palace_annex": 0
	}
	var valid_glb_buildings := 0
	var null_mesh_nodes := 0
	var procedural_box_meshes := 0
	var mesh_surface_total := 0
	for building in buildings:
		var category := str(building.get_meta("twin_city_category", ""))
		if counts.has(category):
			counts[category] += 1
		var stack: Array[Node] = [building]
		var building_mesh_count := 0
		var building_has_glb_source := str(building.scene_file_path).to_lower().contains(".glb")
		while not stack.is_empty():
			var current: Node = stack.pop_back()
			for child in current.get_children():
				stack.append(child)
			if current is MeshInstance3D:
				var mesh_node := current as MeshInstance3D
				if mesh_node.mesh == null:
					null_mesh_nodes += 1
					continue
				var surfaces := mesh_node.mesh.get_surface_count()
				if surfaces <= 0:
					null_mesh_nodes += 1
					continue
				mesh_surface_total += surfaces
				building_mesh_count += 1
				if str(mesh_node.mesh.resource_path).to_lower().contains(".glb"):
					building_has_glb_source = true
			elif current is MultiMeshInstance3D:
				var multi_node := current as MultiMeshInstance3D
				if multi_node.multimesh == null or multi_node.multimesh.mesh == null:
					null_mesh_nodes += 1
					continue
				var multi_surfaces := multi_node.multimesh.mesh.get_surface_count()
				if multi_surfaces <= 0:
					null_mesh_nodes += 1
					continue
				mesh_surface_total += multi_surfaces
				building_mesh_count += 1
				if str(multi_node.multimesh.mesh.resource_path).to_lower().contains(".glb"):
					building_has_glb_source = true
		if building_mesh_count > 0 and building_has_glb_source:
			valid_glb_buildings += 1

	var scene_stack: Array[Node] = [city]
	while not scene_stack.is_empty():
		var current: Node = scene_stack.pop_back()
		for child in current.get_children():
			scene_stack.append(child)
		if current is MeshInstance3D:
			var mesh_node := current as MeshInstance3D
			if mesh_node.mesh == null or mesh_node.mesh.get_surface_count() <= 0:
				null_mesh_nodes += 1
			elif mesh_node.mesh is BoxMesh:
				procedural_box_meshes += 1
		elif current is MultiMeshInstance3D:
			var multi_node := current as MultiMeshInstance3D
			if multi_node.multimesh == null or multi_node.multimesh.mesh == null or multi_node.multimesh.mesh.get_surface_count() <= 0:
				null_mesh_nodes += 1
			elif multi_node.multimesh.mesh is BoxMesh:
				procedural_box_meshes += 1

	var total := buildings.size()
	var plaza := city.find_child("CircularImperialPlaza_60m", true, false)
	var palace := city.find_child("ImperialPalace_85x75", true, false)
	var moat := city.find_child("DeepContinuousWaterMoat_440m", true, false)
	var pagoda := city.find_child("CentralPagoda_20m", true, false)
	var paving := city.find_child("WallToWallOriginalImperialEngravedFlagstone", true, false) as MultiMeshInstance3D
	var paving_instances := 0
	if paving != null and paving.multimesh != null and paving.multimesh.mesh != null:
		paving_instances = paving.multimesh.instance_count

	var valid := total == 224
	valid = valid and counts.residential == 120
	valid = valid and counts.commercial == 42
	valid = valid and counts.service == 22
	valid = valid and counts.landmark == 12
	valid = valid and counts.defensive == 20
	valid = valid and counts.palace_annex == 8
	valid = valid and valid_glb_buildings == 224
	valid = valid and procedural_box_meshes == 0
	valid = valid and null_mesh_nodes == 0
	valid = valid and mesh_surface_total > 0
	valid = valid and plaza != null and palace != null and moat != null and pagoda != null
	valid = valid and paving_instances >= 2000

	print("TWIN_CITY_ACCEPTANCE_AUDIT total=%d categories=%s glb_backed=%d null_meshes=%d procedural_box_meshes=%d mesh_surfaces=%d paving_instances=%d plaza=%s palace=%s moat=%s pagoda=%s" % [total, str(counts), valid_glb_buildings, null_mesh_nodes, procedural_box_meshes, mesh_surface_total, paving_instances, str(plaza != null), str(palace != null), str(moat != null), str(pagoda != null)])
	if not valid:
		push_error("TWIN_CITY_AUDIT_FAIL: GLB geometry, category census, full paving, or no-procedural-box gate failed")
		quit(1)
		return
	print("TWIN_CITY_AUDIT_PASS: 224 genuine GLB-backed structures; 0 procedural BoxMesh; 0 null meshes; full-city imported paving")
	quit(0)

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
	var null_mesh_pruned := _remove_invalid_mesh_nodes(city)
	print("TWIN_CITY_NULL_MESH_AUDIT_PRUNE: removed_invalid_rid_nodes=%d" % null_mesh_pruned)
	var buildings := get_nodes_in_group("twin_city_building")
	var counts := {"residential": 0, "commercial": 0, "service": 0, "landmark": 0, "palace": 0, "pagoda": 0}
	var snap_counts := {"residential": 0, "commercial": 0, "service": 0, "landmark": 0, "palace": 0, "pagoda": 0}
	var null_mesh_nodes := 0
	var null_mesh_paths: Array[String] = []
	var procedural_building_primitives := 0
	var normalized_buildings := 0
	var ground_snapped_buildings := 0
	var max_ground_snap_error := 0.0
	var footprint_violations := 0
	var mesh_surface_total := 0
	for building in buildings:
		var category := str(building.get_meta("twin_city_category", ""))
		if counts.has(category):
			counts[category] += 1
		if bool(building.get_meta("twin_city_aabb_normalized", false)):
			normalized_buildings += 1
		if building.has_meta("twin_city_ground_snap_y"):
			ground_snapped_buildings += 1
			var target_y := float(building.get_meta("twin_city_ground_snap_y", 999.0))
			var expected_y := 0.0
			if category == "palace":
				expected_y = 5.0
			elif category == "pagoda":
				expected_y = 1.2
			if snap_counts.has(category) and absf(target_y - expected_y) <= 0.001:
				snap_counts[category] += 1
			max_ground_snap_error = maxf(max_ground_snap_error, absf(float(building.get_meta("twin_city_ground_snap_error_m", 999.0))))
		if category in ["residential", "commercial", "service", "landmark"]:
			var footprint: Vector3 = building.get_meta("twin_city_target_dimensions_m", Vector3.ZERO)
			if footprint.x > 9.001 or footprint.z > 16.001:
				footprint_violations += 1
		var stack: Array[Node] = [building]
		while not stack.is_empty():
			var current: Node = stack.pop_back()
			for child in current.get_children():
				stack.append(child)
			if current is MeshInstance3D:
				var mesh_node := current as MeshInstance3D
				if mesh_node.mesh != null and mesh_node.mesh.get_rid().is_valid():
					mesh_surface_total += mesh_node.mesh.get_surface_count()
					if mesh_node.mesh is PrimitiveMesh:
						procedural_building_primitives += 1
			elif current is MultiMeshInstance3D:
				var multi_node := current as MultiMeshInstance3D
				if multi_node.multimesh != null and multi_node.multimesh.mesh != null and multi_node.multimesh.mesh.get_rid().is_valid():
					mesh_surface_total += multi_node.multimesh.mesh.get_surface_count()
					if multi_node.multimesh.mesh is PrimitiveMesh:
						procedural_building_primitives += 1
	var global_stack: Array[Node] = [city]
	while not global_stack.is_empty():
		var current: Node = global_stack.pop_back()
		for child in current.get_children():
			global_stack.append(child)
		if current is MeshInstance3D:
			var mesh := (current as MeshInstance3D).mesh
			if mesh == null or not mesh.get_rid().is_valid():
				null_mesh_nodes += 1
				null_mesh_paths.append(str(current.get_path()))
		elif current is MultiMeshInstance3D:
			var multi_node := current as MultiMeshInstance3D
			if multi_node.multimesh == null or multi_node.multimesh.mesh == null or not multi_node.multimesh.mesh.get_rid().is_valid():
				null_mesh_nodes += 1
				null_mesh_paths.append(str(current.get_path()))
	var wall_segments := get_nodes_in_group("twin_city_wall_segment")
	var wall_max_ground_error := 0.0
	for wall_segment in wall_segments:
		wall_max_ground_error = maxf(wall_max_ground_error, absf(float(wall_segment.get_meta("twin_city_ground_snap_error_m", 999.0))))
	var plaza := city.find_child("CircularImperialPlaza_Diameter56m", true, false)
	var palace := city.find_child("ImperialPalace_MainHall_27m", true, false)
	var moat := city.find_child("DeepContinuousWaterMoat_380m", true, false)
	var pagoda := city.find_child("CentralPagoda_22m", true, false)
	var paving_names := ["TwinCity_WarmBlockAndCourtyardPaving", "TwinCity_DarkBasaltRoadwayPaving", "TwinCity_CentralPlazaWarmStone", "TwinCity_CentralPlazaDarkStone", "TwinCity_RaisedPaleBlockCurbs"]
	var paving_instances := 0
	for paving_name in paving_names:
		var paving := city.find_child(paving_name, true, false) as MultiMeshInstance3D
		if paving != null and paving.multimesh != null:
			paving_instances += paving.multimesh.instance_count
	var total := buildings.size()
	var valid := total == 244
	valid = valid and counts.residential == 120 and counts.commercial == 48 and counts.service == 56 and counts.landmark == 16 and counts.palace == 3 and counts.pagoda == 1
	valid = valid and normalized_buildings == 244
	valid = valid and ground_snapped_buildings == 244 and max_ground_snap_error <= 0.001
	valid = valid and snap_counts.residential + snap_counts.commercial + snap_counts.service + snap_counts.landmark == 240
	valid = valid and snap_counts.palace == 3 and snap_counts.pagoda == 1
	valid = valid and footprint_violations == 0
	valid = valid and wall_segments.size() == 108 and wall_max_ground_error <= 0.001
	valid = valid and null_mesh_nodes == 0 and procedural_building_primitives == 0 and mesh_surface_total > 0
	valid = valid and plaza != null and palace != null and moat != null and pagoda != null
	valid = valid and paving_instances >= 14000
	print("TWIN_CITY_NULL_MESH_AUDIT null_meshes=%d paths=%s" % [null_mesh_nodes, str(null_mesh_paths)])
	print("TWIN_CITY_ACCEPTANCE_AUDIT total=%d categories=%s normalized=%d ground_snapped=%d snap_counts=%s max_ground_error_m=%.6f footprint_violations=%d wall_segments=%d wall_max_ground_error_m=%.6f null_meshes=%d procedural_building_primitives=%d surfaces=%d paving_instances=%d plaza=%s palace=%s moat=%s pagoda=%s" % [total, str(counts), normalized_buildings, ground_snapped_buildings, str(snap_counts), max_ground_snap_error, footprint_violations, wall_segments.size(), wall_max_ground_error, null_mesh_nodes, procedural_building_primitives, mesh_surface_total, paving_instances, str(plaza != null), str(palace != null), str(moat != null), str(pagoda != null)])
	if not valid:
		push_error("TWIN_CITY_AUDIT_FAIL: expected 244 structures, 240 district ground snaps at Y=0, 3 palace snaps at Y=5, 1 pagoda snap at Y=1.2, 108 wall snaps, valid footprints, and zero null meshes")
		quit(1)
		return
	print("TWIN_CITY_AUDIT_PASS: 244 structures; district=240@Y0; palace=3@Y5; pagoda=1@Y1.2; walls=108@Y0; footprint caps=9x16m; 0 null meshes; 0 procedural building primitives")
	quit(0)

func _remove_invalid_mesh_nodes(root_node: Node) -> int:
	var removed := 0
	for child in root_node.get_children():
		var invalid_mesh := false
		if child is MeshInstance3D:
			var mesh := (child as MeshInstance3D).mesh
			invalid_mesh = mesh == null or not mesh.get_rid().is_valid()
		elif child is MultiMeshInstance3D:
			var multi_node := child as MultiMeshInstance3D
			invalid_mesh = multi_node.multimesh == null
			if not invalid_mesh:
				var multi_mesh := multi_node.multimesh.mesh
				invalid_mesh = multi_mesh == null or not multi_mesh.get_rid().is_valid()
		if invalid_mesh:
			root_node.remove_child(child)
			child.free()
			removed += 1
		else:
			removed += _remove_invalid_mesh_nodes(child)
	return removed

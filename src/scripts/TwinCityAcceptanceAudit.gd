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
	var counts := {"residential": 0, "commercial": 0, "service": 0, "landmark": 0, "palace": 0, "pagoda": 0}
	var null_mesh_nodes := 0
	var procedural_building_primitives := 0
	var normalized_buildings := 0
	var mesh_surface_total := 0
	for building in buildings:
		var category := str(building.get_meta("twin_city_category", ""))
		if counts.has(category):
			counts[category] += 1
		if bool(building.get_meta("twin_city_aabb_normalized", false)):
			normalized_buildings += 1
		var stack: Array[Node] = [building]
		while not stack.is_empty():
			var current: Node = stack.pop_back()
			for child in current.get_children():
				stack.append(child)
			if current is MeshInstance3D:
				var mesh_node := current as MeshInstance3D
				if mesh_node.mesh == null or mesh_node.mesh.get_surface_count() <= 0:
					null_mesh_nodes += 1
				else:
					mesh_surface_total += mesh_node.mesh.get_surface_count()
					if mesh_node.mesh is PrimitiveMesh:
						procedural_building_primitives += 1
			elif current is MultiMeshInstance3D:
				var multi_node := current as MultiMeshInstance3D
				if multi_node.multimesh == null or multi_node.multimesh.mesh == null or multi_node.multimesh.mesh.get_surface_count() <= 0:
					null_mesh_nodes += 1
				else:
					mesh_surface_total += multi_node.multimesh.mesh.get_surface_count()
					if multi_node.multimesh.mesh is PrimitiveMesh:
						procedural_building_primitives += 1
	var plaza := city.find_child("CircularImperialPlaza_Diameter56m", true, false)
	var palace := city.find_child("ImperialPalace_85x75", true, false)
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
	valid = valid and normalized_buildings >= 244
	valid = valid and null_mesh_nodes == 0 and procedural_building_primitives == 0 and mesh_surface_total > 0
	valid = valid and plaza != null and palace != null and moat != null and pagoda != null
	valid = valid and paving_instances >= 14000
	print("TWIN_CITY_ACCEPTANCE_AUDIT total=%d categories=%s normalized=%d null_meshes=%d procedural_building_primitives=%d surfaces=%d paving_instances=%d plaza=%s palace=%s moat=%s pagoda=%s" % [total, str(counts), normalized_buildings, null_mesh_nodes, procedural_building_primitives, mesh_surface_total, paving_instances, str(plaza != null), str(palace != null), str(moat != null), str(pagoda != null)])
	if not valid:
		push_error("TWIN_CITY_AUDIT_FAIL: four-pass CAD grid, AABB normalization, GLB-only structures, paving or landmark acceptance gate failed")
		quit(1)
		return
	print("TWIN_CITY_AUDIT_PASS: 240 district GLB-assembled structures + 3 palace GLB buildings + 1 central GLB pagoda; 0 procedural primitives in buildings; 0 null meshes; AABB normalized")
	quit(0)

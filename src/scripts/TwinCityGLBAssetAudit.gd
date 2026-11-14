extends SceneTree

const ACTIVE_ROOT := "res://assets/twin_city_selected"
const MANIFEST_PATH := ACTIVE_ROOT + "/selection_manifest.json"
const REPORT_PATH := "res://prototypes/twin_city/reports/all_restored_glb_mesh_audit.json"

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var manifest_file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if manifest_file == null:
		push_error("TWIN_CITY_GLB_AUDIT_FAIL: active selection manifest unavailable")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(manifest_file.get_as_text())
	manifest_file.close()
	if not parsed is Dictionary or not parsed.has("assets") or not parsed.assets is Array:
		push_error("TWIN_CITY_GLB_AUDIT_FAIL: active selection manifest is invalid")
		quit(1)
		return
	var records: Array = parsed.assets
	var report := {"expected_glb_count": records.size(), "discovered_glb_count": records.size(), "valid_glb_count": 0, "null_mesh_nodes": 0, "zero_surface_meshes": 0, "assets": []}
	if records.size() < 99:
		push_error("TWIN_CITY_GLB_AUDIT_FAIL: expected at least 99 restored GLBs, found %d" % records.size())
		quit(1)
		return
	for record in records:
		var relative := str(record.get("file", ""))
		if relative.is_empty() or relative.begins_with("/") or relative.contains(".."):
			push_error("TWIN_CITY_GLB_AUDIT_FAIL: unsafe GLB path in manifest: " + relative)
			quit(1)
			return
		var path := ACTIVE_ROOT.path_join(relative)
		var packed := load(path) as PackedScene
		if packed == null:
			push_error("TWIN_CITY_GLB_AUDIT_FAIL: load failed: " + path)
			quit(1)
			return
		var instance := packed.instantiate()
		if instance == null:
			push_error("TWIN_CITY_GLB_AUDIT_FAIL: instantiate failed: " + path)
			quit(1)
			return
		var stack: Array[Node] = [instance]
		var mesh_count := 0
		var surface_count := 0
		var null_count := 0
		while not stack.is_empty():
			var current: Node = stack.pop_back()
			for child in current.get_children():
				stack.append(child)
			if current is MeshInstance3D:
				var mesh_node := current as MeshInstance3D
				if mesh_node.mesh == null:
					null_count += 1
				else:
					mesh_count += 1
					surface_count += mesh_node.mesh.get_surface_count()
		instance.free()
		report.null_mesh_nodes += null_count
		if mesh_count == 0 or surface_count == 0:
			report.zero_surface_meshes += 1
			push_error("TWIN_CITY_GLB_AUDIT_FAIL: GLB contains no readable mesh surfaces: " + path)
			quit(1)
			return
		if null_count > 0:
			push_error("TWIN_CITY_GLB_AUDIT_FAIL: null mesh in " + path)
			quit(1)
			return
		report.valid_glb_count += 1
		report.assets.append({"file": relative, "mesh_nodes": mesh_count, "surfaces": surface_count})
		if report.valid_glb_count % 20 == 0 or report.valid_glb_count == records.size():
			print("TWIN_CITY_GLB_MESH_PROGRESS %d/%d" % [report.valid_glb_count, records.size()])
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("TWIN_CITY_GLB_AUDIT_FAIL: report output unavailable")
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("TWIN_CITY_GLB_AUDIT_PASS: all %d restored GLBs loaded and instantiated; null_mesh_nodes=0; zero_surface_meshes=0" % report.valid_glb_count)
	quit(0)

extends SceneTree

const MODEL_DIRECTORY := "res://assets/twin_city_selected/models"
const REPORT_PATH := "res://prototypes/twin_city/reports/all_99_glb_mesh_audit.json"

func _initialize() -> void:
	call_deferred("_audit")

func _audit() -> void:
	var directory := DirAccess.open(MODEL_DIRECTORY)
	if directory == null:
		push_error("TWIN_CITY_GLB_AUDIT_FAIL: active 99-GLB directory unavailable")
		quit(1)
		return
	var files := directory.get_files()
	files.sort()
	var glb_files: Array[String] = []
	for file_name in files:
		if file_name.to_lower().ends_with(".glb"):
			glb_files.append(file_name)
	var report := {"expected_glb_count": 99, "discovered_glb_count": glb_files.size(), "valid_glb_count": 0, "null_mesh_nodes": 0, "zero_surface_meshes": 0, "assets": []}
	if glb_files.size() != 99:
		push_error("TWIN_CITY_GLB_AUDIT_FAIL: expected 99 active GLBs, found %d" % glb_files.size())
		quit(1)
		return
	for file_name in glb_files:
		var path := MODEL_DIRECTORY.path_join(file_name)
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
		report.assets.append({"file": file_name, "mesh_nodes": mesh_count, "surfaces": surface_count})
		print("TWIN_CITY_GLB_MESH_OK %d/99 %s mesh_nodes=%d surfaces=%d" % [report.valid_glb_count, file_name, mesh_count, surface_count])
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output == null:
		push_error("TWIN_CITY_GLB_AUDIT_FAIL: report output unavailable")
		quit(1)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("TWIN_CITY_GLB_AUDIT_PASS: all 99 source GLBs loaded and instantiated; null_mesh_nodes=0; zero_surface_meshes=0")
	quit(0)

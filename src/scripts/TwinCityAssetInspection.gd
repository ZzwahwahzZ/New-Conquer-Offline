extends SceneTree

func _initialize() -> void:
	call_deferred("_inspect_kit")

func _inspect_kit() -> void:
	var asset_path := "res://assets/environment/architecture/imperial_china_palace_and_garden.glb"
	if not ResourceLoader.exists(asset_path):
		push_error("IMPERIAL_KIT_AUDIT_FAIL: missing " + asset_path)
		quit(1)
		return
	var packed := load(asset_path) as PackedScene
	if packed == null:
		push_error("IMPERIAL_KIT_AUDIT_FAIL: GLB did not import as PackedScene")
		quit(1)
		return
	var kit := packed.instantiate()
	root.add_child(kit)
	var stack: Array[Node] = [kit]
	var mesh_count := 0
	var model_nodes := 0
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is Node3D and node != kit:
			model_nodes += 1
		if node is MeshInstance3D:
			var mesh_node := node as MeshInstance3D
			if mesh_node.mesh != null:
				mesh_count += 1
				var bounds := mesh_node.mesh.get_aabb()
				print("IMPERIAL_KIT_MESH name=%s path=%s size=%s surfaces=%d" % [mesh_node.name, str(mesh_node.get_path()), str(bounds.size), mesh_node.mesh.get_surface_count()])
	print("IMPERIAL_KIT_INVENTORY_PASS: nodes=%d mesh_instances=%d root=%s" % [model_nodes, mesh_count, kit.name])
	if mesh_count < 20:
		push_error("IMPERIAL_KIT_AUDIT_FAIL: expected a multi-model kit, found too few meshes")
		quit(1)
		return
	quit(0)

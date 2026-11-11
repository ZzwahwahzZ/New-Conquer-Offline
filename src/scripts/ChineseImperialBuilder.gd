extends RefCounted
## Imports the licensed, production GLB palace-and-garden kit. No procedural geometry fallback.
const IMPERIAL_CHINA_GLB := "res://assets/environment/architecture/imperial_china_palace_and_garden.glb"

static func build(parent: Node3D, city: String, _size: float) -> void:
	if city != "TwinCity":
		return
	if not ResourceLoader.exists(IMPERIAL_CHINA_GLB):
		push_error("Missing licensed TwinCity architecture GLB: " + IMPERIAL_CHINA_GLB)
		return
	var packed := load(IMPERIAL_CHINA_GLB) as PackedScene
	if packed == null:
		push_error("TwinCity architecture GLB did not import as PackedScene.")
		return
	var architecture := packed.instantiate() as Node3D
	if architecture == null:
		push_error("TwinCity architecture GLB root is not Node3D.")
		return
	architecture.name = "TwinCity_ImperialChina_GLBAsset"
	parent.add_child(architecture)
	_apply_distance_culling(architecture, 320.0)

static func _apply_distance_culling(root: Node, range_end: float) -> void:
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		for child in current.get_children():
			pending.append(child)
		if current is GeometryInstance3D:
			var geometry := current as GeometryInstance3D
			geometry.visibility_range_end = range_end
			geometry.visibility_range_end_margin = 18.0

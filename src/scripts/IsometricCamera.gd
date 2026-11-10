extends Node3D
## Smoothly follows the player while keeping the isometric camera offset intact.

@export var target_path: NodePath = NodePath("../Player")
@export_range(0.1, 30.0, 0.1) var follow_speed: float = 10.0

var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	if _target == null:
		push_warning("IsometricCamera: target not found. Set target_path to the player's Node3D path.")
		return

	global_position = _target.global_position


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return

	var weight := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_target.global_position, weight)

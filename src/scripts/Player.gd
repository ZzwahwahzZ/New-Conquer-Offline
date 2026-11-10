extends CharacterBody3D
## Click/tap-to-move controller for a CharacterBody3D player.
## The clicked surface must have a CollisionObject3D on the configured ground mask.

@export var move_speed: float = 5.5
@export var turn_speed: float = 10.0
@export var stop_distance: float = 0.15
@export_flags_3d_physics var ground_collision_mask: int = 1
@export var ray_length: float = 1000.0

var _move_target: Vector3
var _has_move_target: bool = false


func _ready() -> void:
	_move_target = global_position


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_set_move_target_from_screen(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_set_move_target_from_screen(event.position)


func _set_move_target_from_screen(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		push_warning("Player: no active Camera3D is available for click-to-move.")
		return

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * ray_length
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collision_mask = ground_collision_mask
	query.exclude = [get_rid()]

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	_move_target = hit.position
	_has_move_target = true


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	else:
		velocity.y = 0.0

	if _has_move_target:
		var direction := _move_target - global_position
		direction.y = 0.0

		if direction.length() <= stop_distance:
			_has_move_target = false
			velocity.x = 0.0
			velocity.z = 0.0
		else:
			direction = direction.normalized()
			var desired_yaw := atan2(-direction.x, -direction.z)
			rotation.y = lerp_angle(rotation.y, desired_yaw, turn_speed * delta)
			velocity.x = direction.x * move_speed
			velocity.z = direction.z * move_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, move_speed * delta)

	move_and_slide()

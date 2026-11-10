extends CharacterBody3D
## Click/tap-to-move plus virtual joystick movement.
## The joystick takes priority while it is being touched or dragged.

@export var move_speed: float = 5.5
@export var turn_speed: float = 10.0
@export var stop_distance: float = 0.15
@export_flags_3d_physics var ground_collision_mask: int = 1
@export var ray_length: float = 1000.0
@export_range(0.0, 1.0, 0.01) var joystick_deadzone: float = 0.12

var _move_target: Vector3
var _has_move_target: bool = false
var _joystick_active: bool = false
var _joystick_vector: Vector2 = Vector2.ZERO


func _ready() -> void:
	_move_target = global_position
	add_to_group("player")


## Called by the HUD. active remains true even when the stick is centered,
## preventing a simultaneous click-to-move command from stealing control.
func set_virtual_joystick_input(direction: Vector2, active: bool) -> void:
	_joystick_active = active
	_joystick_vector = direction.limit_length(1.0) if active else Vector2.ZERO
	if active:
		_has_move_target = false


func _unhandled_input(event: InputEvent) -> void:
	if _joystick_active:
		return

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

	if _joystick_active:
		_has_move_target = false
		if _joystick_vector.length() > joystick_deadzone:
			var camera := get_viewport().get_camera_3d()
			var right := Vector3.RIGHT
			var forward := Vector3.FORWARD
			if camera != null:
				right = camera.global_basis.x
				forward = -camera.global_basis.z
			right.y = 0.0
			forward.y = 0.0
			right = right.normalized()
			forward = forward.normalized()
			var direction := (right * _joystick_vector.x + forward * -_joystick_vector.y).normalized()
			_rotate_and_move(direction, delta)
		else:
			_stop_horizontal(delta)
	elif _has_move_target:
		var direction := _move_target - global_position
		direction.y = 0.0
		if direction.length() <= stop_distance:
			_has_move_target = false
			_stop_horizontal(delta)
		else:
			_rotate_and_move(direction.normalized(), delta)
	else:
		_stop_horizontal(delta)

	move_and_slide()


func _rotate_and_move(direction: Vector3, delta: float) -> void:
	var desired_yaw := atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, turn_speed * delta)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed


func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * delta)

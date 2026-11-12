extends Node3D
## Smooth player-following isometric orbit camera with mouse, touch drag and pinch zoom.
@export var target_path: NodePath = NodePath("../Player")
@export_range(0.1,30.0,0.1) var follow_speed := 10.0
@export_range(15.0,75.0,0.1) var pitch_degrees := 38.0
@export_range(8.0,50.0,0.5) var orbit_distance := 21.0
@export_range(0.05,1.0,0.01) var drag_sensitivity := 0.66
@export var zoom_step := 2.0
var _target: Node3D
var _camera: Camera3D
var _yaw := 0.0
var _drag_mouse := false
var _drag_touch := -1
var _last_pointer := Vector2.ZERO
var _touch_points: Dictionary = {}
var _pinch_distance := 0.0
var _target_distance := 21.0
var _current_distance := 21.0

func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D
	_camera = get_node_or_null("Camera3D") as Camera3D
	_target_distance = orbit_distance
	_current_distance = orbit_distance
	if _target == null or _camera == null:
		push_warning("IsometricCamera: target or Camera3D missing.")
		return
	global_position = _target.global_position
	_camera.make_current()
	_apply_orbit()

func _process(delta: float) -> void:
	if not is_instance_valid(_target) or not is_instance_valid(_camera):
		return
	global_position = global_position.lerp(_target.global_position, 1.0 - exp(-follow_speed * delta))
	_current_distance = lerpf(_current_distance, _target_distance, 1.0 - exp(-12.0 * delta))
	if Input.is_key_pressed(KEY_Q):
		_yaw += 1.8 * delta
	if Input.is_key_pressed(KEY_E):
		_yaw -= 1.8 * delta
	_apply_orbit()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				_drag_mouse = true
				_last_pointer = event.position
			else:
				_drag_mouse = false
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = maxf(8.0, _target_distance - zoom_step)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = minf(50.0, _target_distance + zoom_step)
	elif event is InputEventMouseMotion and _drag_mouse:
		var mouse_motion := event as InputEventMouseMotion
		var pointer_delta: Vector2 = mouse_motion.position - _last_pointer
		_last_pointer = mouse_motion.position
		_orbit_drag(pointer_delta)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_points[event.index] = event.position
			if _touch_points.size() >= 2:
				var points: Array = _touch_points.values()
				var first_point: Vector2 = points[0]
				var second_point: Vector2 = points[1]
				_pinch_distance = first_point.distance_to(second_point)
				_drag_touch = -1
			elif event.position.x >= get_viewport().get_visible_rect().size.x * 0.5:
				_drag_touch = event.index
				_last_pointer = event.position
				_pinch_distance = 0.0
		else:
			_touch_points.erase(event.index)
			if event.index == _drag_touch:
				_drag_touch = -1
			if _touch_points.size() < 2:
				_pinch_distance = 0.0
	elif event is InputEventScreenDrag:
		if _touch_points.has(event.index):
			_touch_points[event.index] = event.position
		if _touch_points.size() >= 2:
			var points: Array = _touch_points.values()
			var first_point: Vector2 = points[0]
			var second_point: Vector2 = points[1]
			var next_distance: float = first_point.distance_to(second_point)
			if _pinch_distance > 0.0:
				_target_distance = clampf(_target_distance - (next_distance - _pinch_distance) * 0.035, 8.0, 50.0)
			_pinch_distance = next_distance
			get_viewport().set_input_as_handled()
		elif event.index == _drag_touch:
			var screen_drag := event as InputEventScreenDrag
			var pointer_delta: Vector2 = screen_drag.position - _last_pointer
			_last_pointer = screen_drag.position
			_orbit_drag(pointer_delta)
			get_viewport().set_input_as_handled()

func _orbit_drag(pointer_delta: Vector2) -> void:
	_yaw -= pointer_delta.x * drag_sensitivity * 0.01
	pitch_degrees = clampf(pitch_degrees + pointer_delta.y * drag_sensitivity, 15.0, 75.0)
	_apply_orbit()

func _apply_orbit() -> void:
	if not is_instance_valid(_camera):
		return
	rotation.y = _yaw
	# Elevate the camera as well as offsetting it: pitching a camera at player height
	# points its optical axis below the ground and hides the player from the frame.
	var pitch_radians := deg_to_rad(pitch_degrees)
	_camera.position = Vector3(0.0, sin(pitch_radians) * _current_distance, cos(pitch_radians) * _current_distance)
	_camera.rotation = Vector3(-pitch_radians, 0.0, 0.0)

func zoom_in() -> void:
	_target_distance = maxf(8.0, _target_distance - zoom_step)

func zoom_out() -> void:
	_target_distance = minf(50.0, _target_distance + zoom_step)

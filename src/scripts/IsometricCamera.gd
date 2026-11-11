extends Node3D
## Player-following orbit camera with mouse, touch, keyboard and zoom controls.
@export var target_path: NodePath = NodePath("../Player")
@export_range(0.1,30.0,0.1) var follow_speed := 10.0
@export_range(15.0,75.0,1.0) var pitch_degrees := 45.0
@export_range(8.0,50.0,0.5) var orbit_distance := 24.0
@export_range(0.05,1.0,0.01) var drag_sensitivity := 0.22
@export var zoom_step := 2.0
var _target: Node3D
var _camera: Camera3D
var _yaw := 0.0
var _drag_mouse := false
var _drag_touch := -1
var _last_pointer := Vector2.ZERO
var _touch_dragging := false
func _ready() -> void:
 _target = get_node_or_null(target_path) as Node3D
 _camera = get_node_or_null("Camera3D") as Camera3D
 if _target == null or _camera == null:
  push_warning("IsometricCamera: target or Camera3D missing.")
  return
 global_position = _target.global_position
 _apply_orbit()
func _process(delta: float) -> void:
 if not is_instance_valid(_target) or not is_instance_valid(_camera): return
 global_position = global_position.lerp(_target.global_position,1.0-exp(-follow_speed*delta))
 if Input.is_key_pressed(KEY_Q): _yaw += 1.8*delta
 if Input.is_key_pressed(KEY_E): _yaw -= 1.8*delta
 _apply_orbit()
func _input(event: InputEvent) -> void:
 if event is InputEventMouseButton:
  if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_MIDDLE]:
   if event.pressed:
    _drag_mouse = true
    _last_pointer = event.position
   else: _drag_mouse = false
  elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
   orbit_distance=maxf(8.0,orbit_distance-zoom_step); _apply_orbit()
  elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
   orbit_distance=minf(50.0,orbit_distance+zoom_step); _apply_orbit()
 elif event is InputEventMouseMotion and _drag_mouse:
  var delta := event.position-_last_pointer
  _last_pointer=event.position
  _orbit_drag(delta)
 elif event is InputEventScreenTouch:
  if event.pressed and event.position.x>=get_viewport().get_visible_rect().size.x*0.5:
   _drag_touch=event.index; _last_pointer=event.position; _touch_dragging=false
  elif not event.pressed and event.index==_drag_touch:
   _drag_touch=-1; _touch_dragging=false
 elif event is InputEventScreenDrag and event.index==_drag_touch:
  if not _touch_dragging and event.position.distance_to(_last_pointer)<5.0: return
  _touch_dragging=true
  var delta := event.position-_last_pointer
  _last_pointer=event.position
  _orbit_drag(delta)
func _orbit_drag(pointer_delta: Vector2) -> void:
 _yaw-=pointer_delta.x*drag_sensitivity*0.01
 pitch_degrees=clampf(pitch_degrees+pointer_delta.y*drag_sensitivity,15.0,75.0)
 _apply_orbit()
func _apply_orbit() -> void:
 if not is_instance_valid(_camera): return
 rotation.y=_yaw
 _camera.position=Vector3(0.0,0.0,orbit_distance)
 _camera.rotation=Vector3(deg_to_rad(-pitch_degrees),0.0,0.0)
func zoom_in() -> void:
 orbit_distance=maxf(8.0,orbit_distance-zoom_step); _apply_orbit()
func zoom_out() -> void:
 orbit_distance=minf(50.0,orbit_distance+zoom_step); _apply_orbit()

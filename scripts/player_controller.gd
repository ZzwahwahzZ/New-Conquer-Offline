extends CharacterBody3D
@export var move_speed := 5.0
@export var gravity := 18.0
@export var safety_y := -3.0
var _safe_spawn := Vector3.ZERO
func _ready() -> void:
	_safe_spawn = global_position
func set_safe_spawn(point: Vector3) -> void:
	_safe_spawn = point
func _physics_process(delta: float) -> void:
	var world := get_tree().get_first_node_in_group("world_manager")
	var bounds := 300.0
	if is_instance_valid(world):
		var current := str(world.get("current_settlement"))
		bounds = 300.0 if current == "TwinCity" else 225.0
	if global_position.y < safety_y or absf(global_position.x) > bounds or absf(global_position.z) > bounds:
		global_position = _safe_spawn + Vector3.UP * 1.5
		velocity = Vector3.ZERO
	var v := Input.get_vector("move_left","move_right","move_forward","move_back")
	var d := Vector3(v.x,0.0,v.y)
	if d.length() > 1.0: d = d.normalized()
	velocity.x = d.x * move_speed
	velocity.z = d.z * move_speed
	if not is_on_floor(): velocity.y -= gravity * delta
	else: velocity.y = -0.1
	move_and_slide()
	if d.length_squared() > 0.001: rotation.y = lerp_angle(rotation.y,atan2(-d.x,-d.z),delta*12.0)

extends CharacterBody3D
@export var move_speed := 5.0
@export var gravity := 18.0
func _physics_process(delta: float) -> void:
  var v := Input.get_vector("move_left","move_right","move_forward","move_back")
  var d := Vector3(v.x,0.0,v.y)
  if d.length() > 1.0: d = d.normalized()
  velocity.x = d.x * move_speed
  velocity.z = d.z * move_speed
  if not is_on_floor(): velocity.y -= gravity * delta
  else: velocity.y = -0.1
  move_and_slide()
  if d.length_squared() > 0.001: rotation.y = lerp_angle(rotation.y,atan2(-d.x,-d.z),delta*12.0)

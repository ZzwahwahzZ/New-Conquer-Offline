extends SceneTree
## Regression: the local player must settle once and remain grounded without input.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "StabilityTestFloor"
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20.0, 2.0, 20.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -1.0
	root.add_child(floor_body)

	var player := CharacterBody3D.new()
	player.name = "IdleStabilityPlayer"
	player.set_script(load("res://src/scripts/Player.gd"))
	player.position = Vector3(0.0, 0.775, 0.0)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.55
	collider.shape = capsule
	player.add_child(collider)
	root.add_child(player)

	# Allow the full requested three seconds of physics with no input.
	for frame in range(180):
		await physics_frame
	var settled_y := player.global_position.y
	for frame in range(30):
		await physics_frame
		print("PLAYER_IDLE_DEBUG frame=%d y=%.6f velocity_y=%.6f on_floor=%s" % [frame, player.global_position.y, player.velocity.y, str(player.is_on_floor())])
		assert(player.is_on_floor(), "Player left the floor while idle")
		assert(is_zero_approx(player.velocity.y), "Player vertical velocity is not zero while idle")
		assert(absf(player.global_position.y - settled_y) <= 0.001, "Player Y position changed while idle")
	print("PLAYER_IDLE_STABILITY_PASS y=%.6f velocity_y=%.6f on_floor=%s" % [player.global_position.y, player.velocity.y, str(player.is_on_floor())])
	quit(0)

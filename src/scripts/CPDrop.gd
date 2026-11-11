extends Area3D
## Magnetic gold/CP pickup. Attach a classic pickup sound in the Inspector.

@export_range(1, 100000, 1) var gold_value: int = 5
@export var magnet_radius: float = 4.0
@export var fly_speed: float = 8.0
@export var pickup_distance: float = 0.65
@export var pickup_sound: AudioStream

var _player: Node3D
var _attracted: bool = false
var _collected: bool = false
var _pool_generation: int = 0
var _audio: AudioStreamPlayer3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = true
	var shape_node := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = magnet_radius
	shape_node.shape = sphere
	add_child(shape_node)

	var pile := MeshInstance3D.new()
	pile.name = "CPPlaceholder"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.42
	mesh.height = 0.12
	pile.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.88, 0.68, 0.22)
	material.metallic = 0.75
	material.roughness = 0.28
	pile.material_override = material
	add_child(pile)

	_audio = AudioStreamPlayer3D.new()
	_audio.name = "GoldPickupSound"
	_audio.stream = pickup_sound
	_audio.max_distance = 12.0
	add_child(_audio)

	body_entered.connect(_on_body_entered)

func reset_for_pool(spawn_position: Vector3, amount: int) -> void:
	_pool_generation += 1
	global_position = spawn_position
	gold_value = maxi(1,amount)
	_player = null
	_attracted = false
	_collected = false
	visible = true
	monitorable = true
	monitoring = true
	set_physics_process(true)
	if is_instance_valid(_audio): _audio.stop()

func deactivate_for_pool() -> void:
	_pool_generation += 1
	visible = false
	monitorable = false
	monitoring = false
	_player = null
	_attracted = false
	_collected = true
	set_physics_process(false)
	if is_instance_valid(_audio): _audio.stop()

func _physics_process(delta: float) -> void:
	if _collected: return
	if not _attracted:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var candidate := players[0] as Node3D
			if is_instance_valid(candidate) and global_position.distance_to(candidate.global_position) <= magnet_radius:
				_player = candidate
				_attracted = true
	if not _attracted or not is_instance_valid(_player):
		return

	var destination := _player.global_position + Vector3(0, 0.8, 0)
	global_position = global_position.move_toward(destination, fly_speed * delta)
	rotate_y(delta * 5.0)
	if global_position.distance_to(destination) <= pickup_distance:
		_collect()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player = body
		_attracted = true

func _collect() -> void:
	if _collected or not is_instance_valid(_player):
		return
	_collected = true
	var collection_generation := _pool_generation
	if not is_instance_valid(_player):
		return
	if GlobalEconomy.add_gold(gold_value):
		if _audio.stream != null:
			_audio.play()
			await _audio.finished
		if collection_generation != _pool_generation: return
		var manager := get_tree().get_first_node_in_group("world_manager")
		if is_instance_valid(manager) and manager.has_method("recycle_gold"):
			manager.call("recycle_gold",self)
		else:
			queue_free()
	else:
		_collected = false

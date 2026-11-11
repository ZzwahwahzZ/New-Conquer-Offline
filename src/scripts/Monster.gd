extends "res://src/scripts/Enemy.gd"
## Reusable classic monster with a rig slot and five animation states.
@export var monster_id := "Pheasant"
@export var is_sanctuary_monster := false
var _rig_slot: MeshInstance3D
var _animation_player: AnimationPlayer
var _sleeping := false
var _active_animation := ""

func _ready() -> void:
	super._ready()
	_ensure_rig_and_animations()

func configure_monster(data: Dictionary, target_node: Node3D, sanctuary: bool) -> void:
	monster_id = str(data.get("id","Pheasant"))
	name = monster_id
	max_hp = int(data.get("hp",40))
	hp = max_hp
	attack_damage = int(data.get("damage",5))
	gold_drop = int(data.get("gold",5)) * (2 if sanctuary else 1)
	experience_drop = int(data.get("xp",20))
	is_sanctuary_monster = sanctuary
	add_to_group("enemies")
	target = target_node
	behavior = 0
	attack_range = 1.8
	detection_range = 12.0 if sanctuary else 8.0
	move_speed = 2.2 if sanctuary else 1.7
	_attack_timer = 0.0
	_provoked = false
	_sleeping = false
	_active_animation = ""
	visible = true
	collision_layer = 1
	collision_mask = 1
	set_physics_process(true)
	set_process(true)
	if is_instance_valid(_health_bar):
		_health_bar.max_value = max_hp
		_health_bar.value = hp
	if is_instance_valid(_rig_slot):
		var material := StandardMaterial3D.new()
		material.albedo_color = data.get("color",Color(0.7,0.25,0.2))
		material.roughness = 0.78
		_rig_slot.material_override = material
	play_state("Idle")

func deactivate_for_pool() -> void:
	remove_from_group("enemies")
	visible = false
	collision_layer = 0
	collision_mask = 0
	target = null
	_sleeping = true
	set_physics_process(false)
	set_process(false)
	if is_instance_valid(_animation_player): _animation_player.stop()

func set_sleeping(value: bool) -> void:
	if _sleeping == value: return
	_sleeping = value
	set_physics_process(not value)
	if is_instance_valid(_animation_player):
		if value:
			_active_animation = ""
			_animation_player.stop()
		else: play_state("Idle")

func _die() -> void:
	var manager := get_tree().get_first_node_in_group("world_manager")
	if not is_instance_valid(manager) or not manager.has_method("recycle_monster"):
		super._die()
		return
	velocity = Vector3.ZERO
	play_state("Death")
	defeated.emit(gold_drop,experience_drop)
	set_physics_process(false)
	await get_tree().create_timer(0.55).timeout
	if is_instance_valid(self):
		manager.call("recycle_monster",self)

func play_state(state_name: String) -> void:
	if _active_animation == state_name or not is_instance_valid(_animation_player): return
	if _animation_player.has_animation(state_name):
		_active_animation = state_name
		_animation_player.play(state_name)

func _ensure_rig_and_animations() -> void:
	var skeleton := get_node_or_null("Skeleton3D") as Skeleton3D
	if skeleton == null:
		skeleton = Skeleton3D.new()
		skeleton.name = "Skeleton3D"
		add_child(skeleton)
	if skeleton.get_bone_count() == 0:
		skeleton.add_bone("Root")
		skeleton.set_bone_parent(0,-1)
		skeleton.set_bone_rest(0,Transform3D.IDENTITY)
	_rig_slot = skeleton.get_node_or_null("HighDetailRigSlot") as MeshInstance3D
	if _rig_slot == null:
		_rig_slot = MeshInstance3D.new()
		_rig_slot.name = "HighDetailRigSlot"
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.55
		capsule.height = 1.7
		_rig_slot.mesh = capsule
		skeleton.add_child(_rig_slot)
	_animation_player = get_node_or_null("AnimationPlayer") as AnimationPlayer
	if _animation_player == null:
		_animation_player = AnimationPlayer.new()
		_animation_player.name = "AnimationPlayer"
		add_child(_animation_player)
	var library := AnimationLibrary.new()
	for animation_name in ["Idle","Run","Attack","Hit","Death"]:
		var animation := Animation.new()
		animation.length = 1.0
		if animation_name in ["Idle","Run","Attack"]: animation.loop_mode = Animation.LOOP_LINEAR
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track,NodePath("Skeleton3D/HighDetailRigSlot:scale"))
		var middle := Vector3.ONE
		var finish := Vector3.ONE
		match animation_name:
			"Idle": middle = Vector3(1.0,1.04,1.0)
			"Run": middle = Vector3(1.0,1.12,1.0)
			"Attack": middle = Vector3(1.18,0.92,0.88)
			"Hit": middle = Vector3(0.82,0.88,0.82)
			"Death": 
				middle = Vector3(1.12,0.82,1.12)
				finish = Vector3(1.1,0.08,1.1)
		animation.track_insert_key(track,0.0,Vector3.ONE)
		animation.track_insert_key(track,0.35,middle)
		animation.track_insert_key(track,1.0,finish)
		library.add_animation(animation_name,animation)
	if _animation_player.has_animation_library(""):
		_animation_player.remove_animation_library("")
	_animation_player.add_animation_library("",library)
	play_state("Idle")

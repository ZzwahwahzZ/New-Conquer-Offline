extends "res://src/scripts/Enemy.gd"
const RiggedCharacterFactory = preload("res://src/scripts/RiggedCharacterFactory.gd")
## Reusable classic monster with a rig slot and five animation states.
@export var monster_id := "Pheasant"
@export var is_sanctuary_monster := false
var _rig_slot: Node3D
var _animation_player: AnimationPlayer
var _sleeping := false
var _active_animation := ""
var _death_generation := 0

func _ready() -> void:
	super._ready()
	_ensure_rig_and_animations()

func configure_monster(data: Dictionary, target_node: Node3D, sanctuary: bool) -> void:
	_death_generation += 1
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
		RiggedCharacterFactory.set_tint(_rig_slot, data.get("color", Color(0.7,0.25,0.2)))
	play_state("Idle")

func deactivate_for_pool() -> void:
	_death_generation += 1
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
	_death_generation += 1
	var death_token := _death_generation
	velocity = Vector3.ZERO
	play_state("Death")
	defeated.emit(gold_drop,experience_drop)
	set_physics_process(false)
	await get_tree().create_timer(0.55).timeout
	if is_instance_valid(self) and death_token == _death_generation and hp <= 0:
		manager.call("recycle_monster",self)

func play_state(state_name: String) -> void:
	if _active_animation == state_name or not is_instance_valid(_rig_slot):
		return
	_active_animation = state_name
	RiggedCharacterFactory.play_state(_rig_slot, state_name)

func _ensure_rig_and_animations() -> void:
	# The old empty Skeleton3D + capsule was a visual placeholder, not a skinned character.
	var old_skeleton := get_node_or_null("Skeleton3D")
	if is_instance_valid(old_skeleton):
		old_skeleton.queue_free()
	var old_player := get_node_or_null("AnimationPlayer")
	if is_instance_valid(old_player):
		old_player.queue_free()
	var variant: int = abs(monster_id.hash()) % 8
	_rig_slot = RiggedCharacterFactory.attach_to(self, "monster", variant, 1.0)
	if _rig_slot == null:
		push_error("Monster: rigged CC0 asset unavailable for " + monster_id)
		return
	_animation_player = RiggedCharacterFactory.find_animation_player(_rig_slot)
	play_state("Idle")

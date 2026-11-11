extends CharacterBody3D
## Two-mode 3D enemy AI with a world-space health bar and CP drop on death.

signal defeated(gold: int, xp: int)
signal health_changed(current_hp: int, maximum_hp: int)

enum Behavior { AGGRESSIVE, PASSIVE }

@export var behavior: Behavior = Behavior.AGGRESSIVE
@export var max_hp: int = 40
@export var attack_damage: int = 5
@export var attack_range: float = 1.7
@export var detection_range: float = 7.0
@export var move_speed: float = 2.0
@export var attack_cooldown: float = 1.5
@export var gold_drop: int = 5
@export var experience_drop: int = 20
@export var cp_drop_scene: PackedScene

var hp: int
var target: Node3D
var _attack_timer: float = 0.0
var _provoked: bool = false
var _health_bar: ProgressBar
var _health_viewport: SubViewport

func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	if not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target = players[0] as Node3D
	_create_world_health_bar()

func take_damage(amount: int) -> void:
	if hp <= 0 or amount <= 0:
		return
	var manager := get_tree().get_first_node_in_group("world_manager")
	if is_instance_valid(manager) and manager.has_method("spawn_impact_effect"):
		manager.call("spawn_impact_effect",global_position+Vector3(0,0.8,0))
	if has_method("play_state"): call("play_state","Hit")
	_provoked = true
	hp = maxi(0, hp - amount)
	health_changed.emit(hp, max_hp)
	if is_instance_valid(_health_bar):
		_health_bar.value = hp
	if hp == 0:
		if has_method("play_state"): call("play_state","Hit")
		_die()

func _physics_process(delta: float) -> void:
	if hp <= 0:
		return
	_attack_timer = maxf(0.0, _attack_timer - delta)
	if not is_instance_valid(target):
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			target = players[0] as Node3D
		if not is_instance_valid(target):
			return

	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	var should_chase := _provoked or (behavior == Behavior.AGGRESSIVE and distance <= detection_range)
	if has_method("play_state"):
		call("play_state","Run" if should_chase and distance > attack_range else "Attack" if should_chase else "Idle")
	if not should_chase:
		_stop_horizontal(delta)
		move_and_slide()
		return

	if distance > attack_range:
		var direction := offset.normalized()
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 8.0 * delta)
	else:
		_stop_horizontal(delta)
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			var player_is_airborne := target.has_method("is_airborne") and bool(target.call("is_airborne"))
			if not player_is_airborne:
				ClassSystem.take_damage(attack_damage)
	move_and_slide()

func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * delta)

func _create_world_health_bar() -> void:
	_health_viewport = SubViewport.new()
	_health_viewport.name = "HealthBarViewport"
	_health_viewport.size = Vector2i(180, 28)
	_health_viewport.transparent_bg = true
	_health_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_health_viewport)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_health_viewport.add_child(panel)
	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0
	_health_bar.max_value = max_hp
	_health_bar.value = hp
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(176, 20)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.78, 0.12, 0.12)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	_health_bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.12, 0.035, 0.035, 0.95)
	_health_bar.add_theme_stylebox_override("background", background)
	panel.add_child(_health_bar)

	var sprite := Sprite3D.new()
	sprite.name = "HealthBarSprite"
	sprite.texture = _health_viewport.get_texture()
	sprite.pixel_size = 0.005
	sprite.position = Vector3(0, 1.65, 0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sprite)

func _die() -> void:
	velocity = Vector3.ZERO
	if has_method("play_state"): call("play_state","Death")
	defeated.emit(gold_drop, experience_drop)
	var manager := get_tree().get_first_node_in_group("world_manager")
	if is_instance_valid(manager) and manager.has_method("recycle_monster"):
		manager.call_deferred("recycle_monster",self)
	else:
		var drop := Area3D.new()
		drop.name = "CPDrop"
		drop.set_script(load("res://src/scripts/CPDrop.gd"))
		drop.set("gold_value", gold_drop)
		drop.global_position = global_position
		get_tree().current_scene.add_child(drop)
		queue_free()

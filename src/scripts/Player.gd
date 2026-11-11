extends CharacterBody3D
## 3D Conquer-style movement, jump, stamina and Archer / Oriental Assassin combat.

signal stamina_changed(value: float, maximum: float)
signal xp_skill_changed(value: float, maximum: float)
signal skill_cooldown_changed(skill_id: String, remaining: float)
signal skill_used(skill_id: String)
signal combat_hit(target: Node, damage: int)
signal auto_attributes_applied(new_level: int, allocation: Dictionary)

@export var move_speed := 5.5
@export var turn_speed := 10.0
@export var stop_distance := 0.15
@export_flags_3d_physics var ground_collision_mask := 1
@export var ray_length := 1000.0
@export_range(0.0,1.0,0.01) var joystick_deadzone := 0.12
@export var jump_speed := 12.0
@export var jump_stamina_cost := 7.0
@export var stamina_regen_per_second := 12.0
@export var fly_height := 3.2
@export var fly_duration := 12.0

const SKILL_DATA := {
	"Jump":{"cooldown":1.0,"mana":0,"stamina":7.0},
	"Fly":{"cooldown":30.0,"mana":20,"stamina":0.0},
	"Scatter":{"cooldown":8.0,"mana":15,"stamina":5.0},
	"Rapid_Fire":{"cooldown":5.0,"mana":10,"stamina":4.0},
	"Kinetic_Spark":{"cooldown":5.0,"mana":10,"stamina":4.0},
	"Path_of_Shadow":{"cooldown":0.0,"mana":0,"stamina":0.0},
	"Double_Slash":{"cooldown":4.0,"mana":0,"stamina":4.0},
	"XP_Mode":{"cooldown":60.0,"mana":0,"stamina":0.0}
}
var _move_target: Vector3
var _has_move_target := false
var _joystick_active := false
var _joystick_vector := Vector2.ZERO
var _cooldowns: Dictionary = {}
var _jumping := false
var _jump_time := 0.0
var _jump_duration := 0.38
var _jump_start := Vector3.ZERO
var _jump_end := Vector3.ZERO
var _jump_apex := 1.25
var _flying := false
var _fly_timer := 0.0
var _ground_y := 0.0
var _attack_timer := 0.0
var _xp_mode_timer := 0.0
var _xp_damage_multiplier := 1.0
var _visual: Node3D
var _safe_spawn := Vector3.ZERO
const WORLD_FALL_LIMIT := -5.0

func _ready() -> void:
	_safe_spawn = global_position
	_move_target = global_position
	add_to_group("player")
	_ground_y = global_position.y
	_visual = get_node_or_null("VisualRoot")
	if _visual == null:
		_visual = Node3D.new()
		_visual.name = "VisualRoot"
		add_child(_visual)
		for child in get_children():
			if child is MeshInstance3D:
				child.reparent(_visual)
		_visual.position = Vector3.ZERO
	var fly_ring := MeshInstance3D.new()
	fly_ring.name = "FlyAuraRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.48
	ring_mesh.outer_radius = 0.58
	fly_ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.2, 0.85, 1.0, 0.78)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.1, 0.65, 1.0)
	fly_ring.material_override = ring_material
	fly_ring.position.y = 0.12
	fly_ring.visible = false
	_visual.add_child(fly_ring)
	_visual.set_meta("fly_ring", fly_ring)
	if not ClassSystem.stats_changed.is_connected(_sync_class_stats):
		ClassSystem.stats_changed.connect(_sync_class_stats)
	if not ClassSystem.level_up.is_connected(_on_class_level_up):
		ClassSystem.level_up.connect(_on_class_level_up)
	_sync_class_stats()

func set_safe_spawn(point: Vector3) -> void:
	_safe_spawn = point
	_ground_y = 0.9

func move_to_world_position(destination: Vector3) -> void:
	_joystick_active = false
	_joystick_vector = Vector2.ZERO
	_move_target = destination
	_has_move_target = true

func set_virtual_joystick_input(direction: Vector2, active: bool) -> void:
	_joystick_active = active
	_joystick_vector = direction.limit_length(1.0) if active else Vector2.ZERO
	if active: _has_move_target = false

func _unhandled_input(event: InputEvent) -> void:
	if _joystick_active: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_move_target_from_screen(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		cast_skill("Jump")
	elif event is InputEventScreenTouch and event.pressed:
		_set_move_target_from_screen(event.position)

func _set_move_target_from_screen(screen_position: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * ray_length
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = ground_collision_mask
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	_move_target = hit.position
	_has_move_target = true

func _physics_process(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	for skill_id in _cooldowns.keys():
		_cooldowns[skill_id] = maxf(0.0, float(_cooldowns[skill_id]) - delta)
		if float(_cooldowns[skill_id]) <= 0.0: _cooldowns.erase(skill_id)
	if _xp_mode_timer > 0.0:
		_xp_mode_timer -= delta
		if _xp_mode_timer <= 0.0: _xp_damage_multiplier = 1.0
	if _flying:
		_fly_timer -= delta
		velocity.y = 0.0
		if _fly_timer <= 0.0: _set_flying(false)
	if _jumping:
		_update_jump(delta)
	else:
		if not is_on_floor() and not _flying:
			velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
		elif is_on_floor() and not _flying:
			velocity.y = 0.0
		_update_horizontal_movement(delta)
		if not _flying and is_on_floor() and velocity.length() < 0.25:
			ClassSystem.restore_stamina(stamina_regen_per_second * delta * 1.35)
		elif not _flying:
			ClassSystem.restore_stamina(stamina_regen_per_second * delta)
	var world := get_tree().get_first_node_in_group("world_manager")
	var limit := 300.0
	if is_instance_valid(world):
		limit = 300.0 if str(world.get("current_settlement")) == "TwinCity" else 225.0
	if global_position.y < WORLD_FALL_LIMIT or absf(global_position.x) > limit or absf(global_position.z) > limit:
		global_position = _safe_spawn + Vector3.UP * 1.5
		velocity = Vector3.ZERO
		_jumping = false
		_flying = false
	if not _jumping:
		move_and_slide()
	stamina_changed.emit(ClassSystem.stamina, ClassSystem.max_stamina)

func _update_horizontal_movement(delta: float) -> void:
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if keyboard.length() > 0.08:
		_joystick_active = false
		_has_move_target = false
		var camera := get_viewport().get_camera_3d()
		var right := Vector3.RIGHT
		var forward := Vector3.FORWARD
		if camera != null:
			right = camera.global_basis.x
			forward = -camera.global_basis.z
		right.y = 0.0
		forward.y = 0.0
		_rotate_and_move((right.normalized() * keyboard.x + forward.normalized() * -keyboard.y).normalized(), delta)
	elif _joystick_active:
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
			_rotate_and_move((right.normalized() * _joystick_vector.x + forward.normalized() * -_joystick_vector.y).normalized(), delta)
		else: _stop_horizontal(delta)
	elif _has_move_target:
		var direction := _move_target - global_position
		direction.y = 0.0
		if direction.length() <= stop_distance:
			_has_move_target = false
			_stop_horizontal(delta)
		else: _rotate_and_move(direction.normalized(), delta)
	else: _stop_horizontal(delta)

func _rotate_and_move(direction: Vector3, delta: float) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), turn_speed * delta)
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed

func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, move_speed * delta)
	velocity.z = move_toward(velocity.z, 0.0, move_speed * delta)

func _update_jump(delta: float) -> void:
	_jump_time += delta
	var t := clampf(_jump_time / _jump_duration, 0.0, 1.0)
	var horizontal := _jump_start.lerp(_jump_end, t)
	var arc := 4.0 * _jump_apex * t * (1.0 - t)
	global_position = Vector3(horizontal.x, _ground_y + arc, horizontal.z)
	if t >= 1.0:
		global_position = Vector3(_jump_end.x, _ground_y, _jump_end.z)
		_jumping = false
		velocity = Vector3.ZERO

func can_use_skill(skill_id: String) -> bool:
	if not SKILL_DATA.has(skill_id) or float(_cooldowns.get(skill_id, 0.0)) > 0.0: return false
	if skill_id in ["Fly", "Scatter"] and ClassSystem.current_class != "Archer": return false
	if skill_id == "Jump" and (_jumping or _flying): return false
	if skill_id == "Fly" and (_flying or _jumping): return false
	if skill_id in ["Rapid_Fire", "Kinetic_Spark"] and (ClassSystem.current_class != "Oriental_Assassin" or not _has_dual_knives()): return false
	if skill_id == "Double_Slash" and ClassSystem.current_class not in ["Trojan","Warrior","Ninja","Oriental_Assassin"]: return false
	if skill_id == "Path_of_Shadow" and not ClassSystem.is_path_shadow_unlocked(): return false
	if skill_id == "XP_Mode" and ClassSystem.xp_skill < ClassSystem.xp_skill_max: return false
	var data: Dictionary = SKILL_DATA[skill_id]
	return ClassSystem.mp >= int(data.mana) and ClassSystem.stamina >= float(data.stamina)

func cast_skill(skill_id: String) -> bool:
	if not can_use_skill(skill_id): return false
	var data: Dictionary = SKILL_DATA[skill_id]
	if not ClassSystem.consume_mana(int(data.mana)):
		return false
	if not ClassSystem.consume_stamina(float(data.stamina)):
		ClassSystem.restore_mana(int(data.mana))
		return false
	_cooldowns[skill_id] = float(data.cooldown)
	match skill_id:
		"Jump": _start_classic_jump()
		"Fly":
			_set_flying(true)
			_fly_timer = fly_duration
		"Scatter":
			_cast_scatter()
		"Rapid_Fire", "Kinetic_Spark", "Double_Slash":
			_start_rapid_fire(skill_id)
		"Path_of_Shadow":
			if not ClassSystem.toggle_path_of_shadow():
				ClassSystem.restore_mana(int(data.mana))
				ClassSystem.restore_stamina(float(data.stamina))
				_cooldowns.erase(skill_id)
				return false
		"XP_Mode":
			if not ClassSystem.consume_xp_skill():
				ClassSystem.restore_mana(int(data.mana))
				ClassSystem.restore_stamina(float(data.stamina))
				return false
			_xp_mode_timer = 10.0
			_xp_damage_multiplier = 1.5
	_gain_skill_proficiency(skill_id, 1)
	skill_used.emit(skill_id)
	return true

func _start_classic_jump() -> void:
	if _jumping or _flying: return
	var destination := _move_target if _has_move_target else global_position + -global_basis.z * 3.5
	destination.y = _ground_y
	var delta := destination - global_position
	delta.y = 0.0
	if delta.length() > 6.0: destination = global_position + delta.normalized() * 6.0
	_jump_start = global_position
	_jump_end = destination
	_jump_time = 0.0
	_jumping = true
	_has_move_target = false
	_gain_xp_skill(5.0)

func _set_flying(enabled: bool) -> void:
	_flying = enabled
	if enabled:
		_ground_y = global_position.y
		velocity.y = 0.0
		global_position.y = _ground_y + fly_height
		if is_instance_valid(_visual):
			_visual.position.y = 0.0
			var ring = _visual.get_meta("fly_ring", null)
			if is_instance_valid(ring): ring.visible = true
	else:
		if is_instance_valid(_visual):
			_visual.position.y = 0.0
			var ring = _visual.get_meta("fly_ring", null)
			if is_instance_valid(ring): ring.visible = false
		global_position.y = _ground_y
		velocity.y = 0.0
	_gain_xp_skill(8.0 if enabled else 0.0)

func is_airborne() -> bool:
	return _flying or _jumping or global_position.y > _ground_y + 0.5

func _guild_attack_multiplier() -> float:
	var guild := get_tree().get_first_node_in_group("guild_system")
	return float(guild.call("get_attack_multiplier")) if is_instance_valid(guild) else 1.0

func _cast_scatter() -> void:
	var scatter_proficiency := ClassSystem.get_skill_proficiency("Scatter")
	var scatter_level := int(scatter_proficiency.get("level", 1))
	var radius := 7.0 + float(scatter_level) * 0.25
	var damage := int((18 + int(ClassSystem.get_physical_attack_bonus() * 0.1) + scatter_level * 3) * _xp_damage_multiplier * _guild_attack_multiplier())
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage") and Vector2(global_position.x, global_position.z).distance_to(Vector2(enemy.global_position.x, enemy.global_position.z)) <= radius:
			enemy.take_damage(damage)
			combat_hit.emit(enemy, damage)
	_gain_xp_skill(12.0)

func _start_rapid_fire(skill_id: String = "Rapid_Fire") -> void:
	var target := _nearest_enemy(8.0)
	if target == null: return
	var rapid_proficiency := ClassSystem.get_skill_proficiency(skill_id)
	var level_bonus := int(rapid_proficiency.get("level", 1))
	for hit_index in range(2):
		if is_instance_valid(target) and target.has_method("take_damage"):
			var damage := int((14 + level_bonus * 3) * _xp_damage_multiplier * _guild_attack_multiplier())
			target.call("take_damage", damage)
			combat_hit.emit(target, damage)
	_gain_xp_skill(10.0)

func basic_attack() -> bool:
	if _attack_timer > 0.0: return false
	var assassin := ClassSystem.current_class == "Oriental_Assassin" and _has_dual_knives()
	_attack_timer = 0.24 if assassin else 0.72
	var target := _nearest_enemy(4.5 if assassin else 3.0)
	if target == null: return false
	var damage := int(round((20 + ClassSystem.get_physical_attack_bonus() * 0.1) * _xp_damage_multiplier * _guild_attack_multiplier()))
	if assassin:
		for i in range(2):
			if is_instance_valid(target): target.call("take_damage", damage)
	else: target.call("take_damage", damage)
	combat_hit.emit(target, damage * (2 if assassin else 1))
	return true

func _nearest_enemy(max_range: float) -> Node:
	var best: Node = null
	var best_distance := max_range
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy): continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = enemy
	return best

func _has_dual_knives() -> bool:
	var gear := get_node_or_null("/root/GearSystem")
	if gear == null: return false
	var equipment: Dictionary = gear.get("equipment")
	return str(equipment.get("RightHand", {}).get("weapon_family", "")) == "ThrowingKnife" and str(equipment.get("LeftHand", {}).get("weapon_family", "")) == "ThrowingKnife"

func _is_archer_family() -> bool:
	return ClassSystem.current_class == "Archer"

func _gain_skill_proficiency(skill_id: String, amount: int) -> void:
	ClassSystem.gain_skill_proficiency(skill_id, amount)

func get_skill_proficiency(skill_id: String) -> Dictionary:
	return ClassSystem.get_skill_proficiency(skill_id)

func _gain_xp_skill(amount: float) -> void:
	ClassSystem.add_xp_skill(amount)

func on_monster_killed() -> void:
	_gain_xp_skill(20.0)

func get_skill_cooldown(skill_id: String) -> float:
	return float(_cooldowns.get(skill_id, 0.0))

func get_xp_skill() -> float:
	return ClassSystem.xp_skill

func _on_class_level_up(new_level: int) -> void:
	var allocation: Dictionary = ClassSystem.get_meta("last_auto_allocation", {})
	auto_attributes_applied.emit(new_level, allocation.duplicate(true))

func _sync_class_stats() -> void:
	stamina_changed.emit(ClassSystem.stamina, ClassSystem.max_stamina)

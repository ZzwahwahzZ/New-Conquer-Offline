extends CharacterBody3D
## Pooled, lightweight visual actor. Roster data remains outside this node.
const WALK_SPEED := 2.2
var bot_data: Dictionary = {}
var _destination := Vector3.ZERO
var _has_destination := false
var _idle := true
var _flying := false
var _fly_phase := 0.0
var _home_position := Vector3.ZERO
var _lod_sleeping := false
var _name_label: Label3D
var _guild_label: Label3D
var _visual: MeshInstance3D
var _wings: Array[MeshInstance3D] = []
var _jump_time := 0.0
var _jump_from := Vector3.ZERO
var _jump_to := Vector3.ZERO
var _combat_target: Node3D
var _attack_timer := 0.0
var _actor_generation := 0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_build_visuals()
	set_physics_process(false)

func _build_visuals() -> void:
	if _visual == null:
		_visual = MeshInstance3D.new()
		_visual.name = "BotBody"
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.34
		capsule.height = 1.55
		_visual.mesh = capsule
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.38,0.62,0.86)
		material.roughness = 0.72
		_visual.material_override = material
		add_child(_visual)
	if _wings.is_empty():
		for side in [-1.0,1.0]:
			var wing := MeshInstance3D.new()
			wing.name = "WingLeft" if side < 0.0 else "WingRight"
			var wing_mesh := BoxMesh.new()
			wing_mesh.size = Vector3(0.12,0.62,0.9)
			wing.mesh = wing_mesh
			wing.position = Vector3(side * 0.43,0.92,0.02)
			wing.rotation.z = side * -0.22
			var wing_material := StandardMaterial3D.new()
			wing_material.albedo_color = Color(0.36,0.82,1.0,0.88)
			wing_material.metallic = 0.25
			wing_material.roughness = 0.35
			wing.material_override = wing_material
			add_child(wing)
			_wings.append(wing)
	if _name_label == null:
		_name_label = Label3D.new()
		_name_label.name = "PlayerName"
		_name_label.position.y = 2.05
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.font_size = 30
		_name_label.outline_size = 5
		add_child(_name_label)
	if _guild_label == null:
		_guild_label = Label3D.new()
		_guild_label.name = "GuildRank"
		_guild_label.position.y = 1.72
		_guild_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_guild_label.font_size = 20
		_guild_label.outline_size = 4
		add_child(_guild_label)

func configure(data: Dictionary, spawn_position: Vector3, diplomacy_color: Color = Color(0.92,0.92,0.92)) -> void:
	_actor_generation += 1
	bot_data = data.duplicate(true)
	global_position = spawn_position
	_home_position = spawn_position
	_name_label.text = str(bot_data.get("name","Warrior")) + "  Lv." + str(bot_data.get("level",1))
	_guild_label.text = "[%s - %s]" % [str(bot_data.get("guild_name","")),str(bot_data.get("guild_rank","Member"))]
	_name_label.modulate = diplomacy_color
	_guild_label.modulate = diplomacy_color
	var material := _visual.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = Color(0.75,0.62,0.36) if str(bot_data.get("class_type","")) == "Oriental_Assassin" else Color(0.32,0.55,0.82)
	visible = true
	_idle = true
	_lod_sleeping = false
	_flying = bool(bot_data.get("has_wings",false))
	for wing in _wings:
		wing.visible = _flying
	_fly_phase = 0.0
	_has_destination = false
	_jump_time = 0.0
	_combat_target = null
	_attack_timer = _rng.randf_range(0.2,1.2)
	collision_layer = 0
	collision_mask = 0
	set_physics_process(true)
	set_process(true)

func deactivate_for_pool() -> void:
	_actor_generation += 1
	visible = false
	_idle = true
	_has_destination = false
	_lod_sleeping = true
	_flying = false
	_combat_target = null
	velocity = Vector3.ZERO
	set_physics_process(false)
	set_process(false)

func set_diplomacy_color(color: Color) -> void:
	if is_instance_valid(_name_label):
		_name_label.modulate = color
		_guild_label.modulate = color

func set_idle_lod(sleeping: bool) -> void:
	_lod_sleeping = sleeping
	var should_run := not sleeping and (not _idle or _flying or is_instance_valid(_combat_target))
	set_physics_process(should_run)
	set_process(should_run)

func move_to(destination: Vector3) -> void:
	_destination = destination
	_has_destination = true
	_idle = false
	set_physics_process(true)
	set_process(true)

func set_combat_target(target: Node3D) -> void:
	_combat_target = target
	_idle = false
	set_physics_process(true)
	set_process(true)

func perform_attack(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	look_at(Vector3(target.global_position.x,global_position.y,target.global_position.z),Vector3.UP)
	var generation := _actor_generation
	_visual.scale = Vector3(1.18,0.88,0.88)
	await get_tree().create_timer(0.16).timeout
	if generation == _actor_generation and is_instance_valid(_visual):
		_visual.scale = Vector3.ONE

func _physics_process(delta: float) -> void:
	if _lod_sleeping:
		return
	_attack_timer = maxf(0.0,_attack_timer-delta)
	if is_instance_valid(_combat_target) and global_position.distance_to(_combat_target.global_position) <= 5.0 and _attack_timer <= 0.0:
		_attack_timer = _rng.randf_range(2.0,3.0)
		perform_attack(_combat_target)
	if _flying:
		_fly_phase += delta
		position.y = _home_position.y + 2.2 + sin(_fly_phase * 2.0) * 0.25
	if _jump_time > 0.0:
		_jump_time = maxf(0.0,_jump_time-delta)
		var t := 1.0 - _jump_time / 0.42
		global_position = _jump_from.lerp(_jump_to,t)
		global_position.y += sin(t * PI) * 1.35
		if _jump_time <= 0.0:
			global_position = _jump_to
			_home_position = global_position
			_idle = true
			if not _flying and not is_instance_valid(_combat_target):
				set_physics_process(false)
				set_process(false)
		return
	if _has_destination:
		var flat_target := Vector3(_destination.x,global_position.y,_destination.z)
		var offset := flat_target-global_position
		if offset.length() < 0.35:
			_has_destination = false
			_idle = true
			_home_position = global_position
			velocity = Vector3.ZERO
			if not _flying and not is_instance_valid(_combat_target):
				set_physics_process(false)
				set_process(false)
		else:
			var direction := offset.normalized()
			velocity = direction * WALK_SPEED
			look_at(global_position + direction,Vector3.UP)
			global_position += velocity * delta
	elif not _idle and not _flying:
		velocity = Vector3.ZERO

func arc_jump_to(destination: Vector3) -> void:
	_jump_from = global_position
	_jump_to = destination
	_jump_time = 0.42
	_has_destination = false
	_idle = false
	set_physics_process(true)
	set_process(true)

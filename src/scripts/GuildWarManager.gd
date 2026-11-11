extends Node3D
## Bounded, offline guild-war instance. Two gates protect the central guild pole.
const Target = preload("res://src/scripts/GuildWarTarget.gd")
const ActorScene = preload("res://src/scenes/AIPlayer.tscn")
const MAX_WAR_BOTS := 8
var gates_destroyed := false
var left_gate: Node3D
var right_gate: Node3D
var guild_pole: Node3D
var player_guild := ""
var defending_guild := ""
var damage_by_guild: Dictionary = {}
var last_hit_guild := ""
var _allied_bots: Array[Node3D] = []
var _defender_bots: Array[Node3D] = []
var _war_bots: Array[Node3D] = []
var _simulation_timer := 0.0
var _resolved := false
var _hud: Node

func _ready() -> void:
	add_to_group("guild_war_arena")
	var system := get_tree().get_first_node_in_group("guild_system")
	if not is_instance_valid(system):
		return
	player_guild = str(system.get("player_guild_name"))
	if player_guild.is_empty():
		player_guild = "Pharaohs"
	defending_guild = str(system.call("get_war_winner"))
	var player_guild_data: Dictionary = system.call("get_guild",player_guild)
	var allied_guilds: Array = player_guild_data.get("allies",[])
	if defending_guild.is_empty() or defending_guild == player_guild or allied_guilds.has(defending_guild):
		var enemy_guilds: Array = player_guild_data.get("enemies",[])
		if not enemy_guilds.is_empty():
			defending_guild = str(enemy_guilds[0])
		else:
			defending_guild = "Dragons" if player_guild != "Dragons" else "Pharaohs"
	_build_arena()
	_spawn_war_bots(system)
	_hud = get_tree().get_first_node_in_group("game_hud")
	if is_instance_valid(_hud):
		_hud.call("push_simulated_chat","بدأت حرب العشائر بين %s و%s!" % [player_guild,defending_guild],"عام")

func _build_arena() -> void:
	var hp_layer := CanvasLayer.new()
	hp_layer.name = "GuildWarHUD"
	add_child(hp_layer)
	var hp_panel := PanelContainer.new()
	hp_panel.name = "PanelContainer"
	hp_panel.position = Vector2(300,18)
	hp_panel.size = Vector2(680,70)
	hp_panel.add_theme_stylebox_override("panel",_hud_style())
	hp_layer.add_child(hp_panel)
	var hp_box := VBoxContainer.new()
	hp_box.name = "VBoxContainer"
	hp_panel.add_child(hp_box)
	var hp_title := Label.new()
	hp_title.name = "PoleTitle"
	hp_title.text = "GUILD POLE — %s" % defending_guild
	hp_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_box.add_child(hp_title)
	var hp_bar := ProgressBar.new()
	hp_bar.name = "PoleHP"
	hp_bar.max_value = 60000
	hp_bar.value = 60000
	hp_bar.show_percentage = true
	hp_box.add_child(hp_bar)
	var floor_mesh := MeshInstance3D.new()
	var floor := PlaneMesh.new()
	floor.size = Vector2(72,72)
	floor_mesh.mesh = floor
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.22,0.2,0.17)
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	var ground_body := StaticBody3D.new()
	ground_body.name = "ArenaGroundCollision"
	ground_body.position.y = -0.5
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(72,1,72)
	ground_collision.shape = ground_shape
	ground_body.add_child(ground_collision)
	add_child(ground_body)
	left_gate = _make_target("left_gate","Left Gate",18000,Vector3(-12,0,-12))
	right_gate = _make_target("right_gate","Right Gate",18000,Vector3(12,0,-12))
	guild_pole = _make_target("guild_pole","Guild Pole — %s" % defending_guild,60000,Vector3(0,0,0))
	var camera_marker := Marker3D.new()
	camera_marker.name = "ArenaPlayerSpawn"
	camera_marker.position = Vector3(0,0,25)
	add_child(camera_marker)
	var pole_label := Label3D.new()
	pole_label.text = "GUILD WAR — %s DEFENDING" % defending_guild
	pole_label.position = Vector3(0,8,0)
	pole_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pole_label.font_size = 42
	add_child(pole_label)

func _hud_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05,0.06,0.08,0.94)
	style.border_color = Color(0.8,0.58,0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style

func _make_target(id: String, label: String, health: int, position: Vector3) -> Node3D:
	var node := StaticBody3D.new()
	node.set_script(Target)
	node.position = position
	add_child(node)
	node.call("configure",id,label,health,self)
	return node

func _spawn_war_bots(system: Node) -> void:
	var allied: Array = system.call("get_members",player_guild)
	var defenders: Array = system.call("get_members",defending_guild)
	var index := 0
	for record in allied:
		if int(record.get("id",-1)) == 0: continue
		_spawn_bot(record,Vector3(-18 + index*2,0,12),true)
		index += 1
		if index >= 4: break
	index = 0
	for record in defenders:
		_spawn_bot(record,Vector3(18 - index*2,0,-22),false)
		index += 1
		if index >= 4: break

func _spawn_bot(record: Dictionary, position: Vector3, allied: bool) -> void:
	if _war_bots.size() >= MAX_WAR_BOTS: return
	var bot := ActorScene.instantiate() as Node3D
	if bot == null: return
	add_child(bot)
	bot.call("configure",record,position,Color(0.25,0.78,1.0) if allied else Color(1.0,0.28,0.25))
	bot.call("move_to",Vector3(0,0,0) if allied else Vector3(0,0,-5))
	_war_bots.append(bot)
	if allied: _allied_bots.append(bot)
	else: _defender_bots.append(bot)

func _process(delta: float) -> void:
	if _resolved: return
	_simulation_timer += delta
	if _simulation_timer < 1.0: return
	_simulation_timer = 0.0
	if not gates_destroyed:
		if not _allied_bots.is_empty() and is_instance_valid(left_gate):
			left_gate.call("apply_simulated_damage",_allied_bots.size()*180,player_guild)
		if not _defender_bots.is_empty() and is_instance_valid(right_gate):
			right_gate.call("apply_simulated_damage",_defender_bots.size()*180,defending_guild)
	else:
		if not _allied_bots.is_empty() and is_instance_valid(guild_pole):
			guild_pole.call("apply_simulated_damage",_allied_bots.size()*420,player_guild)
		if not _defender_bots.is_empty() and is_instance_valid(guild_pole):
			guild_pole.call("apply_simulated_damage",_defender_bots.size()*420,defending_guild)

func register_target_damage(target_id: String, amount: int, attacking_guild: String = "") -> void:
	if amount <= 0 or target_id != "guild_pole": return
	var team := attacking_guild if not attacking_guild.is_empty() else player_guild
	last_hit_guild = team
	damage_by_guild[team] = int(damage_by_guild.get(team,0)) + amount

func update_target_health(target_id: String, hp: int, max_hp: int) -> void:
	if target_id == "left_gate" and hp <= 0: left_gate.set_meta("destroyed",true)
	if target_id == "right_gate" and hp <= 0: right_gate.set_meta("destroyed",true)
	if target_id == "guild_pole":
		var bar := get_node_or_null("GuildWarHUD/PanelContainer/VBoxContainer/PoleHP")
		if is_instance_valid(bar): bar.set("value",hp)

func target_destroyed(target_id: String) -> void:
	if target_id in ["left_gate","right_gate"]:
		gates_destroyed = bool(left_gate.get("hp") <= 0 and right_gate.get("hp") <= 0)
		if gates_destroyed:
			if is_instance_valid(_hud): _hud.call("push_simulated_chat","تم فتح الطريق إلى Guild Pole!","حرب العشائر")
		return
	if target_id == "guild_pole":
		_resolve_war()

func _resolve_war() -> void:
	if _resolved: return
	_resolved = true
	var winner := player_guild
	var highest := -1
	for guild_name in damage_by_guild:
		var damage := int(damage_by_guild[guild_name])
		if damage > highest or (damage == highest and str(guild_name) == last_hit_guild):
			highest = damage
			winner = str(guild_name)
	var system := get_tree().get_first_node_in_group("guild_system")
	if is_instance_valid(system):
		system.call("set_war_winner",winner)
		if winner == player_guild:
			GameState.profile["guild_war_title"] = "Guild War Winner"
		else:
			GameState.profile["guild_war_title"] = ""
		GameState.save_local()
		system.call("set_war_active",false)
	if is_instance_valid(_hud):
		_hud.call("push_simulated_chat","🏆 Guild War Winner: %s!" % winner,"عام")
		_hud.call("push_simulated_chat","تم منح لقب Guild War Winner وبف النصر لعشيرة اللاعب عند الفوز.","عام")

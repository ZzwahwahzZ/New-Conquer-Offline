extends Node3D
## World-local director: at most 40 safe-zone actors or 3 hunting actors.
const Roster = preload("res://src/scripts/VirtualPlayerRoster.gd")
const BOT_SCENE := preload("res://src/scenes/AIPlayer.tscn")
const CITY_CAP := 40
const HUNT_CAP := 3
const SPAWN_BATCH := 2
const SPAWN_INTERVAL := 0.1
const CULL_INTERVAL := 0.8
const ACTIVE_DISTANCE := 58.0
const GUILD_DONATION_INTERVAL := 24.0
const CHAT_INTERVAL := 12.0
var roster = Roster.new()
var world_manager: Node
var player: Node3D
var settlement_id := "TwinCity"
var safe_zone := true
var active_cap := CITY_CAP
var _active_bots: Array[Node3D] = []
var _pool: Array[Node3D] = []
var _spawn_queue: Array[Dictionary] = []
var _spawn_timer := 0.0
var _cull_timer := 0.0
var _donation_timer := 0.0
var _chat_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _next_roster_index := 0

func _ready() -> void:
	add_to_group("ai_players_manager")
	_rng.randomize()
	roster.build_roster()

func setup(manager: Node, target_player: Node3D, settlement: String) -> void:
	if not _active_bots.is_empty():
		recycle_all()
	world_manager = manager
	player = target_player
	settlement_id = settlement
	safe_zone = settlement == "TwinCity"
	active_cap = CITY_CAP if safe_zone else HUNT_CAP
	roster.build_roster()
	_queue_zone_roster()
	set_process(true)

func _queue_zone_roster() -> void:
	_spawn_queue.clear()
	_active_bots.clear()
	var all_players: Array[Dictionary] = roster.get_all_players()
	if safe_zone:
		var beginners: Array[Dictionary] = []
		var veterans: Array[Dictionary] = []
		var kings: Array[Dictionary] = []
		for bot in all_players:
			if int(bot.level) <= 39:
				beginners.append(bot)
			elif int(bot.gear_plus) >= 12 and bool(bot.has_wings):
				kings.append(bot)
			elif int(bot.gear_plus) >= 5 and int(bot.gear_plus) <= 8:
				veterans.append(bot)
		_shuffle(beginners); _shuffle(veterans); _shuffle(kings)
		var selected: Array[Dictionary] = []
		selected.append_array(beginners.slice(0,20))
		selected.append_array(veterans.slice(0,14))
		selected.append_array(kings.slice(0,6))
		while selected.size() < CITY_CAP:
			selected.append(all_players[selected.size()])
		_shuffle(selected)
		for bot in selected:
			_spawn_queue.append(bot)
	else:
		var candidates: Array[Dictionary] = []
		for bot in all_players:
			if int(bot.level) >= 15 and int(bot.level) <= 130:
				candidates.append(bot)
		_shuffle(candidates)
		for index in range(mini(HUNT_CAP,candidates.size())):
			_spawn_queue.append(candidates[index])

func _shuffle(items: Array) -> void:
	for index in range(items.size()-1,0,-1):
		var swap_index := _rng.randi_range(0,index)
		var temporary = items[index]
		items[index] = items[swap_index]
		items[swap_index] = temporary

func _process(delta: float) -> void:
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL and not _spawn_queue.is_empty():
		_spawn_timer = 0.0
		for index in range(mini(SPAWN_BATCH,_spawn_queue.size())):
			_spawn_one(_spawn_queue.pop_front())
	_cull_timer += delta
	if _cull_timer >= CULL_INTERVAL:
		_cull_timer = 0.0
		_update_lod()
	_donation_timer += delta
	if _donation_timer >= GUILD_DONATION_INTERVAL:
		_donation_timer = 0.0
		_simulate_donation()
	_chat_timer += delta
	if _chat_timer >= CHAT_INTERVAL:
		_chat_timer = 0.0
		_emit_random_chat()

func _spawn_one(data: Dictionary) -> void:
	if _active_bots.size() >= active_cap or not is_instance_valid(player):
		return
	var bot: Node3D
	if not _pool.is_empty():
		bot = _pool.pop_back()
	else:
		bot = BOT_SCENE.instantiate() as Node3D
	if bot == null:
		return
	if bot.get_parent() != null:
		bot.get_parent().remove_child(bot)
	add_child(bot)
	var spawn_position := _choose_spawn_position()
	bot.call("configure",data,spawn_position,_get_diplomacy_color(str(data.guild_name)))
	_active_bots.append(bot)
	if safe_zone:
		_assign_city_behavior(bot)
	else:
		_assign_hunting_behavior(bot)

func _choose_spawn_position() -> Vector3:
	if safe_zone:
		var angle := _rng.randf_range(0.0,TAU)
		var radius := _rng.randf_range(7.0,27.0)
		return player.global_position + Vector3(cos(angle)*radius,0.0,sin(angle)*radius)
	var angle := _rng.randf_range(0.0,TAU)
	var radius := _rng.randf_range(9.0,20.0)
	return player.global_position + Vector3(cos(angle)*radius,0.0,sin(angle)*radius)

func _assign_city_behavior(bot: Node3D) -> void:
	var markers: Array[Node3D] = []
	var world: Node = world_manager.get("current_world") if is_instance_valid(world_manager) else null
	if not is_instance_valid(world):
		return
	for child in world.get_children():
		if child is Marker3D and str(child.name).begins_with("BotInteractionSpot_"):
			markers.append(child)
	if markers.is_empty():
		return
	var marker := markers[_rng.randi_range(0,markers.size()-1)]
	var offset := Vector3(_rng.randf_range(-2.0,2.0),0.0,_rng.randf_range(-1.5,1.5))
	bot.call("move_to",marker.global_position + offset)

func _assign_hunting_behavior(bot: Node3D) -> void:
	var monsters := get_tree().get_nodes_in_group("enemies")
	var target: Node3D
	var nearest_distance := 999999.0
	for candidate in monsters:
		if not is_instance_valid(candidate):
			continue
		var distance := bot.global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			target = candidate
	if is_instance_valid(target):
		var attack_position := target.global_position + Vector3(_rng.randf_range(-2.0,2.0),0.0,_rng.randf_range(-2.0,2.0))
		bot.call("move_to",attack_position)
		bot.call("set_combat_target",target)

func _update_lod() -> void:
	if not is_instance_valid(player):
		return
	var focus := player.global_position
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		focus = camera.global_position
	for bot in _active_bots:
		if not is_instance_valid(bot):
			continue
		var sleeping := bot.global_position.distance_squared_to(focus) > ACTIVE_DISTANCE * ACTIVE_DISTANCE
		bot.call("set_idle_lod",sleeping)

func _get_diplomacy_color(guild_name: String) -> Color:
	var player_guild := str(GameState.profile.get("guild_name",""))
	if not player_guild.is_empty() and guild_name == player_guild:
		return Color(0.25,0.78,1.0)
	var diplomacy := roster.get_guild_diplomacy(player_guild) if not player_guild.is_empty() else {}
	if Array(diplomacy.get("allies",[])).has(guild_name):
		return Color(0.25,0.95,0.42)
	if Array(diplomacy.get("enemies",[])).has(guild_name):
		return Color(1.0,0.28,0.25)
	return Color(0.94,0.94,0.9)

func _simulate_donation() -> void:
	if _active_bots.is_empty():
		return
	var bot: Dictionary = _active_bots[_rng.randi_range(0,_active_bots.size()-1)].get("bot_data")
	var amount := _rng.randi_range(50000,500000)
	var player_id := int(bot.get("id",0))
	if not roster.donate_to_guild(player_id,amount):
		return
	_emit_chat("[Guild] %s تبرع بمبلغ %s ذهب لصندوق %s!" % [str(bot.get("name","")),_format_gold(amount),str(bot.get("guild_name",""))],"نقابة")
	var updated := roster.get_player(player_id)
	for active_bot in _active_bots:
		if is_instance_valid(active_bot) and int(active_bot.get("bot_data").get("id",-1)) == player_id:
			active_bot.call("configure",updated,active_bot.global_position,_get_diplomacy_color(str(updated.guild_name)))
			break

func _emit_random_chat() -> void:
	if _active_bots.is_empty():
		return
	var bot: Dictionary = _active_bots[_rng.randi_range(0,_active_bots.size()-1)].get("bot_data")
	var messages := ["حد محتاج Party؟","WTS gear +%d — PM me!" % _rng.randi_range(5,8),"مين جاي يصطاد؟","LFG Twin City!","أهلاً يا أبطال المدينة"]
	var channel := "عام" if safe_zone else "عام"
	_emit_chat("[%s] %s: %s" % [channel,str(bot.get("name","Player")),messages[_rng.randi_range(0,messages.size()-1)]],channel)

func _emit_chat(message: String, channel: String = "عام") -> void:
	get_tree().call_group("game_hud","push_simulated_chat",message,channel)

func _format_gold(amount: int) -> String:
	var raw := str(maxi(0,amount))
	var formatted := ""
	for index in range(raw.length()):
		if index > 0 and (raw.length()-index) % 3 == 0:
			formatted += ","
		formatted += raw[index]
	return formatted

func recycle_all() -> void:
	for bot in _active_bots.duplicate():
		_recycle_bot(bot)
	_spawn_queue.clear()

func _recycle_bot(bot: Node3D) -> void:
	if not is_instance_valid(bot):
		return
	_active_bots.erase(bot)
	bot.call("deactivate_for_pool")
	if bot.get_parent() != null:
		bot.get_parent().remove_child(bot)
	if _pool.size() < CITY_CAP:
		add_child(bot)
		_pool.append(bot)
	else:
		bot.queue_free()

func get_queued_count() -> int:
	return _spawn_queue.size()

func get_active_count() -> int:
	return _active_bots.size()

func get_pool_count() -> int:
	return _pool.size()

func get_active_cap() -> int:
	return active_cap

func is_safe_zone() -> bool:
	return safe_zone

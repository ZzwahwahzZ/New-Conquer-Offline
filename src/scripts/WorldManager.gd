extends Node3D
## Offline open-world director, local streaming and bounded mobile pools.
const MonsterDB = preload("res://src/scripts/MonsterDatabase.gd")
const SETTLEMENTS := {
	"TwinCity":{"name":"Twin City","scene":"res://src/scenes/world/TwinCity.tscn","min":1,"max":15,"next":"DesertLand"},
	"DesertLand":{"name":"Desert Land","scene":"res://src/scenes/world/DesertLand.tscn","min":15,"max":40,"next":"VolcanoLand"},
	"VolcanoLand":{"name":"Volcano Land","scene":"res://src/scenes/world/VolcanoLand.tscn","min":40,"max":70,"next":"IceLand"},
	"IceLand":{"name":"Ice Land","scene":"res://src/scenes/world/IceLand.tscn","min":70,"max":95,"next":"Waterlands"},
	"Waterlands":{"name":"Waterlands","scene":"res://src/scenes/world/Waterlands.tscn","min":95,"max":115,"next":"DarkForest"},
	"DarkForest":{"name":"Dark Forest","scene":"res://src/scenes/world/DarkForest.tscn","min":115,"max":130,"next":"TwinCity"},
	"GuildWarArena":{"name":"Guild War Arena","scene":"res://src/scenes/world/GuildWarArena.tscn","min":1,"max":130,"next":"TwinCity"}
}
const MAX_MONSTER_POOL := 24
const MAX_GOLD_POOL := 32
const MAX_IMPACT_POOL := 12
const SLEEP_DISTANCE := 58.0
const CULL_INTERVAL := 0.8
var player: Node3D
var current_settlement := "TwinCity"
var current_world: Node3D
var teleporter: Node
var _monster_pool: Array[Node3D] = []
var _gold_pool: Array[Area3D] = []
var _active_monsters: Array[Node3D] = []
var _active_gold: Array[Area3D] = []
var _impact_pool: Array[MeshInstance3D] = []
var _active_impacts: Array[Dictionary] = []
var _cull_timer := 0.0
var _transitioning := false
var quest_system: Node
var _ai_players_manager: Node3D
var guild_system: Node
var guild_war_manager: Node

func _ready() -> void:
	add_to_group("world_manager")
	teleporter = Node.new()
	teleporter.name = "WorldTeleporter"
	teleporter.set_script(load("res://src/scripts/WorldTeleporter.gd"))
	add_child(teleporter)
	teleporter.call("configure", self)
	quest_system=Node.new(); quest_system.name="QuestSystem"; quest_system.set_script(load("res://src/scripts/QuestSystem.gd")); add_child(quest_system)
	_ai_players_manager = Node3D.new()
	_ai_players_manager.name = "AIPlayersManager"
	_ai_players_manager.set_script(load("res://src/scripts/AIPlayersManager.gd"))
	add_child(_ai_players_manager)
	guild_system = Node.new()
	guild_system.name = "GuildSystem"
	guild_system.set_script(load("res://src/scripts/GuildSystem.gd"))
	add_child(guild_system)

func setup(target_player: Node3D) -> void:
	player = target_player
	var saved_id := str(GameState.profile.get("settlement_id","TwinCity"))
	if not SETTLEMENTS.has(saved_id) or saved_id == "GuildWarArena": saved_id = "TwinCity"
	var saved_position = GameState.profile.get("world_position", [])
	if saved_position is Array and saved_position.size() >= 3:
		player.position = Vector3(float(saved_position[0]),maxf(0.9,float(saved_position[1])),float(saved_position[2]))
		if saved_id == "TwinCity" and Vector2(player.position.x,player.position.z).length() < 35.0:
			player.position = Vector3(0.0,2.5,22.0)
	else:
		player.position = Vector3(0.0,2.5,22.0) if saved_id == "TwinCity" else Vector3(0.0,1.0,0.0)
	call_deferred("change_settlement", saved_id, true)

func change_settlement(settlement_id: String, restore_position: bool = false) -> void:
	if _transitioning or not SETTLEMENTS.has(settlement_id): return
	if current_settlement == "GuildWarArena" and settlement_id != "GuildWarArena" and is_instance_valid(guild_system):
		guild_system.call("set_war_active",false)
	_transitioning = true
	for monster in _active_monsters.duplicate(): recycle_monster(monster)
	for drop in _active_gold.duplicate(): recycle_gold(drop)
	for impact in _active_impacts.duplicate(): recycle_impact(impact.node)
	if is_instance_valid(current_world):
		if is_instance_valid(_ai_players_manager):
			_ai_players_manager.call("recycle_all")
		current_world.queue_free()
		current_world = null
		await get_tree().process_frame
		
	current_settlement = settlement_id
	var scene_path := str(SETTLEMENTS[settlement_id].scene)
	var packed := ResourceLoader.load(scene_path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if packed == null:
		push_error("WorldManager: settlement scene missing: " + scene_path)
		_transitioning = false
		return
	current_world = packed.instantiate() as Node3D
	current_world.name = settlement_id
	add_child(current_world)
	if settlement_id != "GuildWarArena":
		var npc_system = Node3D.new()
		npc_system.name = "NPCSystem"
		npc_system.set_script(load("res://src/scripts/NPCSystem.gd"))
		current_world.add_child(npc_system)
		npc_system.call("setup",current_world,settlement_id)
	if is_instance_valid(player) and not restore_position:
		player.global_position = Vector3(0,2.5,22) if settlement_id == "TwinCity" else (Vector3(0,1,0) if settlement_id != "GuildWarArena" else Vector3(0,1,27))
	if is_instance_valid(player) and player.has_method("set_safe_spawn"):
		player.call("set_safe_spawn", player.global_position)
	if settlement_id != "GuildWarArena":
		_spawn_settlement_content()
	if is_instance_valid(_ai_players_manager):
		if settlement_id == "GuildWarArena": _ai_players_manager.call("recycle_all")
		else: _ai_players_manager.call("setup",self,player,current_settlement)
	if settlement_id == "GuildWarArena":
		guild_war_manager = current_world
		if is_instance_valid(guild_system): guild_system.call("set_war_active",true)
	else:
		guild_war_manager = null
	_create_portals()
	GameState.profile["settlement_id"] = settlement_id
	GameState.profile["world_position"] = [player.position.x,player.position.y,player.position.z]
	GameState.save_local()
	_transitioning = false

func _spawn_settlement_content() -> void:
	if current_settlement == "GuildWarArena": return
	var definitions: Array = MonsterDB.get_settlement_monsters(current_settlement)
	var spawn_points: Array[Vector3] = [Vector3(48,0,42),Vector3(-50,0,40),Vector3(52,0,-46),Vector3(-54,0,-42),Vector3(0,0,-58),Vector3(58,0,0)]
	for index in range(spawn_points.size()):
		_spawn_monster(definitions[index % definitions.size()],spawn_points[index],false)
	var sanctuary_data: Array = MonsterDB.get_sanctuary_monsters(current_settlement)
	var sanctuary_points: Array[Vector3] = [Vector3(66,0,62),Vector3(-68,0,-60)]
	for index in range(sanctuary_data.size()):
		_spawn_monster(sanctuary_data[index],sanctuary_points[index % sanctuary_points.size()],true)

func _spawn_monster(data: Dictionary, spawn_position: Vector3, sanctuary: bool) -> void:
	var monster := _acquire_monster()
	if monster == null: return
	current_world.add_child(monster)
	monster.global_position = spawn_position
	monster.call("configure_monster",data,player,sanctuary)
	var defeated_callable := Callable(self,"_on_monster_defeated").bind(monster)
	if not monster.is_connected("defeated",defeated_callable):
		monster.connect("defeated",defeated_callable)
	_active_monsters.append(monster)

func _acquire_monster() -> Node3D:
	var monster: Node3D
	if not _monster_pool.is_empty():
		monster = _monster_pool.pop_back()
		if monster.get_parent() != null: monster.get_parent().remove_child(monster)
	else:
		var packed := load("res://src/scenes/Monster.tscn") as PackedScene
		if packed == null: return null
		monster = packed.instantiate() as Node3D
	return monster

func recycle_monster(monster: Node3D) -> void:
	if not is_instance_valid(monster): return
	_active_monsters.erase(monster)
	if _monster_pool.has(monster): return
	if _monster_pool.size() >= MAX_MONSTER_POOL:
		monster.queue_free()
		return
	monster.call("deactivate_for_pool")
	if monster.get_parent() != null: monster.get_parent().remove_child(monster)
	add_child(monster)
	_monster_pool.append(monster)

func acquire_gold(position: Vector3, amount: int) -> void:
	if not is_instance_valid(current_world): return
	var drop: Area3D
	if not _gold_pool.is_empty():
		drop = _gold_pool.pop_back()
		if drop.get_parent() != null: drop.get_parent().remove_child(drop)
	else:
		var packed := load("res://src/scenes/CPDrop.tscn") as PackedScene
		if packed == null: return
		drop = packed.instantiate() as Area3D
	current_world.add_child(drop)
	drop.call("reset_for_pool",position,amount)
	_active_gold.append(drop)

func recycle_gold(drop: Area3D) -> void:
	if not is_instance_valid(drop) or _gold_pool.has(drop): return
	_active_gold.erase(drop)
	if _gold_pool.size() >= MAX_GOLD_POOL:
		drop.queue_free()
		return
	drop.call("deactivate_for_pool")
	if drop.get_parent() != null: drop.get_parent().remove_child(drop)
	add_child(drop)
	_gold_pool.append(drop)

func _on_monster_defeated(gold: int, xp: int, monster: Node3D) -> void:
	if not is_instance_valid(monster): return
	var position := monster.global_position
	acquire_gold(position,gold)
	ClassSystem.add_experience(xp)
	if is_instance_valid(player) and player.has_method("on_monster_killed"): player.call("on_monster_killed")
	GameState.profile["level"] = ClassSystem.level
	GameState.profile["experience"] = ClassSystem.experience
	var sanctuary_loot := bool(monster.get("is_sanctuary_monster"))
	if sanctuary_loot:
		var gear_drop_by_class := {"Archer":"archer_bow","Oriental_Assassin":"assassin_throwing_knife","Trojan":"trojan_blade_15","Warrior":"warrior_sword_15","Water_Taoist":"taoist_backsword_15","Fire_Taoist":"taoist_backsword_15","Ninja":"ninja_katana_15"}
		var gear_drop_id := str(gear_drop_by_class.get(ClassSystem.current_class,""))
		if not gear_drop_id.is_empty():
			GearSystem.add_item(gear_drop_id,2)
	GameState.add_item("monster_material",2 if sanctuary_loot else 1)
	GameState.update_quest("first_hunt","completed")
	if is_instance_valid(quest_system): quest_system.call("monster_killed",str(monster.get("monster_id")))
	if is_instance_valid(player):
		GameState.profile["world_position"] = [player.position.x,player.position.y,player.position.z]
	GameState.profile["settlement_id"] = current_settlement
	GameState.save_local()

func _create_portals() -> void:
	var destination := str(SETTLEMENTS[current_settlement].next)
	var portal := Node3D.new()
	portal.name = "PortalTo_" + destination
	portal.position = Vector3(0,0,32) if current_settlement == "GuildWarArena" else Vector3(0,0,-78)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.3
	ring.mesh = torus
	ring.rotation_degrees.x = 90
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.15,0.72,1.0,0.85)
	glow.emission_enabled = true
	glow.emission = Color(0.08,0.55,1.0)
	glow.emission_energy_multiplier = 2.0
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = glow
	portal.add_child(ring)
	var area := Area3D.new()
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.8
	shape.height = 2.8
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(_on_portal_entered.bind(destination))
	portal.add_child(area)
	current_world.add_child(portal)

func _on_portal_entered(body: Node3D, destination: String) -> void:
	if body == player: teleporter.call("travel_to",destination)

func get_settlement_ids() -> Array:
	var ids: Array = SETTLEMENTS.keys()
	ids.erase("GuildWarArena")
	return ids

func get_settlement_name(settlement_id: String) -> String:
	return str(SETTLEMENTS.get(settlement_id,{}).get("name",settlement_id))

func get_settlement_level_range(settlement_id: String) -> String:
	var data: Dictionary = SETTLEMENTS.get(settlement_id,{})
	return "%d-%s" % [int(data.get("min",1)),str(data.get("max",130))+"+" if settlement_id == "DarkForest" else str(data.get("max",130))]

func get_minimap_snapshot() -> Dictionary:
	var monsters: Array[Vector3] = []
	for monster in _active_monsters:
		if is_instance_valid(monster) and monster.visible: monsters.append(monster.global_position)
	return {"player":player.global_position if is_instance_valid(player) else Vector3.ZERO,"monsters":monsters,"portal":Vector3(0,0,-78),"settlement":current_settlement}

func spawn_impact_effect(world_position: Vector3) -> void:
	if not is_instance_valid(current_world) or _active_impacts.size() >= MAX_IMPACT_POOL: return
	var effect: MeshInstance3D
	if not _impact_pool.is_empty():
		effect = _impact_pool.pop_back()
		if effect.get_parent() != null: effect.get_parent().remove_child(effect)
	else:
		effect = MeshInstance3D.new()
		effect.name = "PooledImpactEffect"
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		effect.mesh = sphere
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(1.0,0.55,0.16,0.9)
		material.emission_enabled = true
		material.emission = Color(1.0,0.24,0.04)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		effect.material_override = material
	current_world.add_child(effect)
	effect.global_position = world_position
	effect.scale = Vector3.ONE
	effect.visible = true
	_active_impacts.append({"node":effect,"ttl":0.18})

func recycle_impact(effect: MeshInstance3D) -> void:
	if not is_instance_valid(effect) or _impact_pool.has(effect): return
	for index in range(_active_impacts.size()-1,-1,-1):
		if _active_impacts[index].node == effect: _active_impacts.remove_at(index)
	effect.visible = false
	if effect.get_parent() != null: effect.get_parent().remove_child(effect)
	if _impact_pool.size() < MAX_IMPACT_POOL:
		add_child(effect)
		_impact_pool.append(effect)
	else: effect.queue_free()

func _process(delta: float) -> void:
	for index in range(_active_impacts.size()-1,-1,-1):
		var impact: Dictionary = _active_impacts[index]
		var effect: MeshInstance3D = impact.node
		impact.ttl = float(impact.ttl)-delta
		if is_instance_valid(effect):
			effect.scale = Vector3.ONE*(1.0+maxf(0.0,0.18-float(impact.ttl))*2.0)
		if float(impact.ttl) <= 0.0:
			_active_impacts.remove_at(index)
			if is_instance_valid(effect):
				effect.visible = false
				if effect.get_parent() != null: effect.get_parent().remove_child(effect)
				if _impact_pool.size() < MAX_IMPACT_POOL:
					add_child(effect)
					_impact_pool.append(effect)
				else: effect.queue_free()
	_cull_timer += delta
	if _cull_timer < CULL_INTERVAL: return
	_cull_timer = 0.0
	if not is_instance_valid(player): return
	var focus_position := player.global_position
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera): focus_position = camera.global_position
	for monster in _active_monsters:
		if is_instance_valid(monster):
			var sleeping := monster.global_position.distance_squared_to(focus_position) > SLEEP_DISTANCE*SLEEP_DISTANCE
			monster.call("set_sleeping",sleeping)

func save_world_state() -> void:
	if is_instance_valid(player):
		GameState.profile["world_position"] = [player.position.x,player.position.y,player.position.z]
		GameState.profile["settlement_id"] = current_settlement

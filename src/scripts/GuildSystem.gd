extends Node
## Offline guild membership, diplomacy, treasury, ranks and buffs. WorldManager-owned; not an Autoload.
signal guild_changed
signal guild_chat(message: String)
signal guild_war_started
signal guild_war_result(guild_name: String)
const Roster = preload("res://src/scripts/VirtualPlayerRoster.gd")
const CREATE_GUILD_COST := 1000000
const MAX_GUILD_MEMBERS := 26
const RANK_THRESHOLDS := {"Supervisor":350000,"Honorary Deputy Leader":900000,"Deputy Leader":2500000}
var roster = Roster.new()
var guilds: Dictionary = {}
var player_guild_name := ""
var player_guild_rank := ""
var player_guild_donation := 0
var war_winner_guild := ""
var _bot_join_timer := 0.0
var _bot_join_cursor := 0
var _guild_war_active := false

func _ready() -> void:
	add_to_group("guild_system")
	roster.build_roster()
	var saved: Dictionary = GlobalEconomy.load_guild_data()
	if not saved.is_empty():
		_restore_data(saved)
	else:
		guilds = roster.guilds.duplicate(true)
	_sync_player_profile()
	_save()

func _process(delta: float) -> void:
	if player_guild_name.is_empty() or not guilds.has(player_guild_name) or _guild_war_active:
		return
	if _guild_member_count(player_guild_name) >= MAX_GUILD_MEMBERS:
		return
	_bot_join_timer += delta
	if _bot_join_timer < 18.0:
		return
	_bot_join_timer = 0.0
	_recruit_available_bot()

func _restore_data(data: Dictionary) -> void:
	var stored_guilds = data.get("guilds",{})
	guilds = stored_guilds.duplicate(true) if stored_guilds is Dictionary else roster.guilds.duplicate(true)
	var stored_players = data.get("roster_players",[])
	if stored_players is Array and stored_players.size() == Roster.TARGET_PLAYERS:
		roster.players.clear()
		for entry in stored_players:
			if entry is Dictionary: roster.players.append(entry.duplicate(true))
	var stored_roster_guilds = data.get("roster_guilds",{})
	if stored_roster_guilds is Dictionary:
		roster.guilds = stored_roster_guilds.duplicate(true)
	player_guild_name = str(data.get("player_guild_name",""))
	player_guild_rank = str(data.get("player_guild_rank",""))
	player_guild_donation = maxi(0,int(data.get("player_guild_donation",0)))
	war_winner_guild = str(data.get("war_winner_guild",""))
	if not player_guild_name.is_empty() and not guilds.has(player_guild_name):
		player_guild_name = ""
		player_guild_rank = ""
		player_guild_donation = 0

func serialize_data() -> Dictionary:
	return {"guilds":guilds.duplicate(true),"roster_players":roster.players.duplicate(true),"roster_guilds":roster.guilds.duplicate(true),"player_guild_name":player_guild_name,"player_guild_rank":player_guild_rank,"player_guild_donation":player_guild_donation,"war_winner_guild":war_winner_guild}

func _save() -> void:
	roster.guilds = guilds.duplicate(true)
	_sync_player_profile()
	GlobalEconomy.save_guild_data(serialize_data())

func _sync_player_profile() -> void:
	GameState.profile["player_guild_name"] = player_guild_name
	GameState.profile["player_guild_rank"] = player_guild_rank
	GameState.profile["player_guild_donation"] = player_guild_donation
	GameState.profile["guild_name"] = player_guild_name
	GameState.profile["guild_rank"] = player_guild_rank
	GameState.profile["guild_donation"] = player_guild_donation
	GameState.save_local()

func _guild_member_count(guild_name: String) -> int:
	var count := 1 if player_guild_name == guild_name else 0
	for bot in roster.players:
		if str(bot.get("guild_name","")) == guild_name: count += 1
	return count

func get_guild_names() -> Array[String]:
	var result: Array[String] = []
	for name in guilds.keys(): result.append(str(name))
	result.sort()
	return result

func get_guild(guild_name: String) -> Dictionary:
	return guilds.get(guild_name,{}).duplicate(true)

func get_player_guild() -> Dictionary:
	return get_guild(player_guild_name)

func get_members(guild_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if player_guild_name == guild_name:
		result.append({"id":0,"name":str(GameState.profile.get("character_name","Player")),"class_type":ClassSystem.current_class,"level":ClassSystem.level,"guild_rank":player_guild_rank,"guild_donation":player_guild_donation,"online":true})
	var bot_members: Array[Dictionary] = roster.get_guild_members(guild_name)
	var ai_manager := get_tree().get_first_node_in_group("ai_players_manager")
	for bot in bot_members:
		bot["online"] = bool(ai_manager.call("is_bot_active",int(bot.get("id",-1)))) if is_instance_valid(ai_manager) else false
		result.append(bot)
	return result

func join_guild(guild_name: String) -> bool:
	if not player_guild_name.is_empty() or not guilds.has(guild_name) or _guild_member_count(guild_name) >= MAX_GUILD_MEMBERS:
		return false
	player_guild_name = guild_name
	player_guild_rank = "Member"
	player_guild_donation = 0
	var bulletin := str(guilds[guild_name].get("bulletin",""))
	_save()
	guild_chat.emit("مرحباً بك في %s! %s" % [guild_name,bulletin])
	guild_changed.emit()
	return true

func create_guild(guild_name: String) -> bool:
	var clean := guild_name.strip_edges()
	if ClassSystem.level < 40 or not player_guild_name.is_empty() or clean.length() < 3 or clean.length() > 20 or guilds.has(clean) or not GlobalEconomy.remove_gold(CREATE_GUILD_COST):
		return false
	guilds[clean] = {"guild_name":clean,"guild_fund":0,"bulletin":"Welcome to %s. Fight with honor!" % clean,"allies":[],"enemies":[],"player_created":true}
	roster.guilds[clean] = guilds[clean].duplicate(true)
	player_guild_name = clean
	player_guild_rank = "Guild Leader"
	player_guild_donation = 0
	_save()
	guild_chat.emit("تم تأسيس عشيرة %s بقيادة %s!" % [clean,str(GameState.profile.get("character_name","Player"))])
	guild_changed.emit()
	return true

func donate_gold(amount: int) -> bool:
	if player_guild_name.is_empty() or amount <= 0 or not GlobalEconomy.remove_gold(amount):
		return false
	var guild: Dictionary = guilds[player_guild_name]
	guild["guild_fund"] = int(guild.get("guild_fund",0)) + amount
	player_guild_donation += amount
	_refresh_player_rank()
	_save()
	guild_chat.emit("[Guild] تبرع %s بمبلغ %s ذهب لصندوق %s!" % [str(GameState.profile.get("character_name","Player")),_format_gold(amount),player_guild_name])
	guild_changed.emit()
	return true

func _refresh_player_rank() -> void:
	if player_guild_rank == "Guild Leader": return
	if player_guild_donation >= int(RANK_THRESHOLDS["Deputy Leader"]):
		player_guild_rank = "Deputy Leader"
	elif player_guild_donation >= int(RANK_THRESHOLDS["Honorary Deputy Leader"]):
		player_guild_rank = "Honorary Deputy Leader"
	elif player_guild_donation >= int(RANK_THRESHOLDS.Supervisor):
		player_guild_rank = "Supervisor"
	else:
		player_guild_rank = "Member"

func record_bot_donation(player_id: int, amount: int) -> bool:
	if amount <= 0 or not roster.donate_to_guild(player_id,amount): return false
	var bot := roster.get_player(player_id)
	var guild_name := str(bot.get("guild_name",""))
	if not guilds.has(guild_name): return false
	guilds[guild_name].guild_fund = int(guilds[guild_name].get("guild_fund",0)) + amount
	_save()
	guild_chat.emit("[Guild] %s تبرع بمبلغ %s ذهب لصندوق %s!" % [str(bot.get("name","Warrior")),_format_gold(amount),guild_name])
	guild_changed.emit()
	return true

func challenge_guild_leader() -> bool:
	if player_guild_name.is_empty() or player_guild_rank == "Guild Leader": return false
	var members := roster.get_guild_members(player_guild_name)
	var leader: Dictionary = {}
	for member in members:
		if str(member.guild_rank) == "Guild Leader": leader = member; break
	if leader.is_empty() or ClassSystem.level <= int(leader.level) or player_guild_donation <= int(leader.guild_donation):
		return false
	for index in range(roster.players.size()):
		if int(roster.players[index].id) == int(leader.id):
			roster.players[index].guild_rank = "Deputy Leader"
			break
	player_guild_rank = "Guild Leader"
	_save()
	guild_chat.emit("تغيّر قائد عشيرة %s بعد تحدي القيادة!" % player_guild_name)
	guild_changed.emit()
	return true

func set_bulletin(message: String) -> bool:
	if player_guild_name.is_empty() or player_guild_rank != "Guild Leader": return false
	var clean := message.strip_edges()
	if clean.is_empty() or clean.length() > 180: return false
	guilds[player_guild_name].bulletin = clean
	_save()
	guild_changed.emit()
	return true

func set_diplomacy(other_guild: String, relation: String) -> bool:
	if player_guild_name.is_empty() or player_guild_rank != "Guild Leader" or other_guild == player_guild_name or not guilds.has(other_guild) or relation not in ["Ally","Enemy","Neutral"]:
		return false
	var own: Dictionary = guilds[player_guild_name]
	var other: Dictionary = guilds[other_guild]
	own.allies.erase(other_guild); own.enemies.erase(other_guild)
	other.allies.erase(player_guild_name); other.enemies.erase(player_guild_name)
	if relation == "Ally":
		own.allies.append(other_guild); other.allies.append(player_guild_name)
	elif relation == "Enemy":
		own.enemies.append(other_guild); other.enemies.append(player_guild_name)
	roster.guilds = guilds.duplicate(true)
	_save()
	guild_changed.emit()
	get_tree().call_group("ai_players_manager","refresh_diplomacy")
	return true

func get_diplomacy_color(guild_name: String) -> Color:
	if guild_name == player_guild_name and not player_guild_name.is_empty(): return Color(0.25,0.78,1.0)
	var own := get_guild(player_guild_name)
	if Array(own.get("allies",[])).has(guild_name): return Color(0.25,0.95,0.42)
	if Array(own.get("enemies",[])).has(guild_name): return Color(1.0,0.28,0.25)
	return Color(0.94,0.94,0.9)

func get_guild_buffs() -> Dictionary:
	var fund := int(get_player_guild().get("guild_fund",0))
	var rank_bonus := 0.0
	match player_guild_rank:
		"Supervisor": rank_bonus = 0.02
		"Honorary Deputy Leader": rank_bonus = 0.04
		"Deputy Leader": rank_bonus = 0.06
		"Guild Leader": rank_bonus = 0.08
	var treasury_bonus := minf(0.12,float(fund) / 10000000.0 * 0.12)
	var winner_bonus := 0.05 if not player_guild_name.is_empty() and war_winner_guild == player_guild_name else 0.0
	return {"attack_pct":rank_bonus+treasury_bonus+winner_bonus,"defense_pct":rank_bonus+treasury_bonus+winner_bonus,"xp_pct":minf(0.20,rank_bonus+treasury_bonus*0.75+winner_bonus)}

func get_attack_multiplier() -> float: return 1.0 + float(get_guild_buffs().attack_pct)
func get_defense_multiplier() -> float: return 1.0 + float(get_guild_buffs().defense_pct)
func get_xp_multiplier() -> float: return 1.0 + float(get_guild_buffs().xp_pct)

func request_bot_recruitment() -> void:
	_bot_join_cursor = 0

func _recruit_available_bot() -> void:
	var own := get_members(player_guild_name)
	if own.size() >= MAX_GUILD_MEMBERS: return
	var candidates: Array[int] = []
	for index in range(roster.players.size()):
		if str(roster.players[index].guild_name) != player_guild_name and str(roster.players[index].guild_rank) != "Guild Leader":
			candidates.append(index)
	if candidates.is_empty(): return
	var index := candidates[_bot_join_cursor % candidates.size()]
	_bot_join_cursor += 1
	var old_guild := str(roster.players[index].guild_name)
	var old_record: Dictionary = roster.players[index]
	roster.players[index].guild_name = player_guild_name
	roster.players[index].guild_donation = 0
	roster.players[index].guild_rank = "Member"
	guilds[player_guild_name].guild_fund = int(guilds[player_guild_name].get("guild_fund",0))
	_save()
	get_tree().call_group("ai_players_manager","refresh_diplomacy")
	guild_chat.emit("%s طلب الانضمام إلى العشيرة وتم قبوله!" % str(old_record.get("name","Warrior")))
	guild_changed.emit()

func leave_guild() -> bool:
	if player_guild_name.is_empty() or player_guild_rank == "Guild Leader": return false
	player_guild_name = ""
	player_guild_rank = ""
	player_guild_donation = 0
	_save()
	guild_changed.emit()
	get_tree().call_group("ai_players_manager","refresh_diplomacy")
	return true

func get_war_winner() -> String: return war_winner_guild
func set_war_winner(guild_name: String) -> void:
	war_winner_guild = guild_name
	_guild_war_active = false
	_save()
	guild_war_result.emit(guild_name)
	guild_chat.emit("إعلان حرب العشائر: %s سيطرت على الساحة!" % guild_name)
	guild_changed.emit()

func set_war_active(active: bool) -> void:
	_guild_war_active = active
	if active: guild_war_started.emit()

func _format_gold(amount: int) -> String:
	var raw := str(maxi(0,amount)); var formatted := ""
	for index in range(raw.length()):
		if index > 0 and (raw.length()-index)%3 == 0: formatted += ","
		formatted += raw[index]
	return formatted

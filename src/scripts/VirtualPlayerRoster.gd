extends RefCounted
## Lightweight, deterministic offline roster. No Nodes or 3D resources are stored here.
const TARGET_PLAYERS := 200
const GUILD_NAMES := ["Pharaohs","Dragons","ShadowKnights","Titans","Legends","Wolves","Kings","Vipers"]
const CLASS_TYPES := ["Archer","Oriental_Assassin","Trojan","Warrior","Ninja","Water_Taoist","Fire_Taoist"]
const FIRST_NAMES := ["Shadow","Rex","Storm","Dragon","Blade","Hunter","Legend","Raven","Sultan","Nile","Anubis","Kairo","Zed","Falcon","Ghost","Viper","Titan","Nova","Azrael","Saber","سيف","فارس","الظل","الصقر","الأسد","الفرعون","قيصر","النينجا","قاهر","رعد","شاهين","عنتر"]
const LAST_NAMES := ["X","II","King","Pro","Legend","M7","Xx","99","Prime","ElMasry","Killer","Hero","Zero","Night","القناص","المصري","الأسطوري","الذيب","الملك","الصياد"]
const GUILD_BULLETINS := ["Welcome warriors. Respect the code, protect the guild.","Strength through unity. Donate, grow, and fight with honor.","أهلاً بالمحاربين! التعاون والاحترام أساس العشيرة."]
const _ALLY_PAIRS := [["Pharaohs","Titans"],["Dragons","Legends"],["ShadowKnights","Vipers"],["Wolves","Kings"]]
var players: Array[Dictionary] = []
var guilds: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func build_roster() -> void:
	if players.size() == TARGET_PLAYERS:
		var base_guilds_exist := true
		for guild_name in GUILD_NAMES:
			if not guilds.has(guild_name):
				base_guilds_exist = false
				break
		if base_guilds_exist:
			return
	_rng.seed = 130013
	players.clear()
	guilds.clear()
	for guild_index in range(GUILD_NAMES.size()):
		var guild_name: String = GUILD_NAMES[guild_index]
		guilds[guild_name] = {"guild_name":guild_name,"guild_fund":0,"bulletin":GUILD_BULLETINS[guild_index % GUILD_BULLETINS.size()],"allies":[],"enemies":[]}
	for pair in _ALLY_PAIRS:
		guilds[pair[0]].allies.append(pair[1])
		guilds[pair[1]].allies.append(pair[0])
	for guild_name in GUILD_NAMES:
		for enemy_name in GUILD_NAMES:
			if enemy_name != guild_name and not guilds[guild_name].allies.has(enemy_name):
				guilds[guild_name].enemies.append(enemy_name)
	for index in range(TARGET_PLAYERS):
		var guild_name: String = GUILD_NAMES[index / 25]
		var member_index: int = index % 25
		var level := _rng.randi_range(1, 130)
		var plus := _rng.randi_range(0, 12)
		var quality := ["Normal","Elite","Super"][_rng.randi_range(0,2)]
		var class_roll := _rng.randf()
		var class_type := "Archer" if class_roll < 0.38 else ("Oriental_Assassin" if class_roll < 0.68 else CLASS_TYPES[_rng.randi_range(2,6)])
		var donation := _rng.randi_range(0, 850000)
		var rank := "Member"
		if member_index == 0:
			level = 125
			plus = 12
			quality = "Elite"
			donation = 12000000
			rank = "Guild Leader"
		elif member_index <= 2:
			level = maxi(100, level)
			donation = maxi(donation, 2500000)
			rank = "Deputy Leader"
		elif donation >= 900000:
			rank = "Honorary Deputy Leader"
		elif donation >= 350000:
			rank = "Supervisor"
		var bot := {"id":index + 1,"name":_make_name(index),"class_type":class_type,"level":level,"gear_plus":plus,"gear_quality":quality,"has_wings":level >= 40 and plus >= 8 and class_type in ["Archer","Oriental_Assassin"],"guild_name":guild_name,"guild_donation":donation,"guild_rank":rank}
		players.append(bot)
		guilds[guild_name].guild_fund += donation

func _make_name(index: int) -> String:
	return FIRST_NAMES[index % FIRST_NAMES.size()] + LAST_NAMES[(index * 7 + 3) % LAST_NAMES.size()]

func get_all_players() -> Array[Dictionary]:
	build_roster()
	return players.duplicate(true)

func get_player(player_id: int) -> Dictionary:
	build_roster()
	for player in players:
		if int(player.id) == player_id:
			return player.duplicate(true)
	return {}

func get_guild(guild_name: String) -> Dictionary:
	build_roster()
	return guilds.get(guild_name, {}).duplicate(true)

func get_guild_names() -> Array:
	build_roster()
	return GUILD_NAMES.duplicate()

func get_guild_members(guild_name: String) -> Array[Dictionary]:
	build_roster()
	var result: Array[Dictionary] = []
	for player in players:
		if str(player.guild_name) == guild_name:
			result.append(player.duplicate(true))
	return result

func get_guild_fund(guild_name: String) -> int:
	build_roster()
	return int(guilds.get(guild_name, {}).get("guild_fund", 0))

func get_guild_diplomacy(guild_name: String) -> Dictionary:
	var guild := get_guild(guild_name)
	return {"allies":guild.get("allies",[]),"enemies":guild.get("enemies",[])}

func get_player_rank(player_id: int) -> String:
	return str(get_player(player_id).get("guild_rank", "Member"))

func donate_to_guild(player_id: int, amount: int) -> bool:
	build_roster()
	if amount <= 0:
		return false
	for index in range(players.size()):
		if int(players[index].id) != player_id:
			continue
		var guild_name: String = str(players[index].guild_name)
		players[index].guild_donation = int(players[index].guild_donation) + amount
		guilds[guild_name].guild_fund = int(guilds[guild_name].guild_fund) + amount
		_refresh_rank(index)
		return true
	return false

func _refresh_rank(player_index: int) -> void:
	var player: Dictionary = players[player_index]
	var member_index := (int(player.id) - 1) % 25
	if member_index == 0:
		player.guild_rank = "Guild Leader"
	elif member_index <= 2:
		player.guild_rank = "Deputy Leader"
	elif int(player.guild_donation) >= 900000:
		player.guild_rank = "Honorary Deputy Leader"
	elif int(player.guild_donation) >= 350000:
		player.guild_rank = "Supervisor"
	else:
		player.guild_rank = "Member"
	player.has_wings = int(player.level) >= 40 and int(player.gear_plus) >= 8 and str(player.class_type) in ["Archer","Oriental_Assassin"]

func record_player_milestone(milestone: String) -> Array[String]:
	var messages: Array[String] = []
	match milestone:
		"assassin_promotion":
			messages = ["[عام] ShadowX: مبروك السفاح الشرقي!","[عام] Falcon: Path of Shadow unlocked — respect!"]
		"gear_plus_9":
			messages = ["[عام] DragonKing: مبروك +9 يا بطل!","[عام] Raven: Upgrade luck!"]
		"gear_plus_12":
			messages = ["[عام] Pharaoh: +12؟ ملك السيرفر وصل!","[عام] ViperX: أسطورة والله!"]
	return messages

func validate_data() -> bool:
	build_roster()
	if players.size() != TARGET_PLAYERS:
		return false
	for guild_name in GUILD_NAMES:
		if not guilds.has(guild_name):
			return false
	for guild_name in GUILD_NAMES:
		var guild: Dictionary = guilds[guild_name]
		if not guild.has_all(["guild_name","guild_fund","bulletin","allies","enemies"]):
			return false
		var leaders := 0
		for player in players:
			if str(player.guild_name) == guild_name and str(player.guild_rank) == "Guild Leader":
				leaders += 1
				if int(player.level) < 120 or int(player.gear_plus) != 12 or str(player.gear_quality) != "Elite":
					return false
		if leaders != 1:
			return false
	return true

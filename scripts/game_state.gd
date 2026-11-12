extends Node
signal stats_changed
signal inventory_changed
signal quest_changed
const SAVE_PATH := "user://offline_profile.json"
var profile := {"character_name":"Player","level":1,"experience":0,"gold":100,"hp":100,"max_hp":100,"mp":50,"max_mp":50,"inventory":[],"quests":{"first_hunt":"not_started"},"settlement_id":"TwinCity","world_position":[0.0,0.0,0.0],"player_guild_name":"","player_guild_rank":"","player_guild_donation":0,"guild_war_title":""}
func _ready() -> void:
  if not GlobalEconomy.gold_changed.is_connected(_on_global_gold_changed):
    GlobalEconomy.gold_changed.connect(_on_global_gold_changed)
  profile.gold = GlobalEconomy.current_gold

func _on_global_gold_changed(new_amount: int) -> void:
  profile.gold = new_amount
  stats_changed.emit()

func add_gold(amount: int) -> void:
  GlobalEconomy.add_gold(amount)
func add_experience(amount: int) -> void:
  var guild = get_tree().get_first_node_in_group("guild_system")
  var xp_multiplier := float(guild.call("get_xp_multiplier")) if is_instance_valid(guild) else 1.0
  profile.experience = maxi(0, int(profile.experience) + int(round(float(amount) * xp_multiplier)))
  while profile.experience >= int(profile.level) * 100:
    profile.experience -= int(profile.level) * 100
    profile.level += 1
    profile.max_hp += 10
    profile.max_mp += 5
    profile.hp = profile.max_hp
    profile.mp = profile.max_mp
  stats_changed.emit()
func damage_player(amount: int) -> void:
  var guild = get_tree().get_first_node_in_group("guild_system")
  var mitigation := float(guild.call("get_defense_multiplier")) if is_instance_valid(guild) else 1.0
  profile.hp = maxi(0, int(profile.hp) - int(round(float(maxi(0,amount)) / mitigation)))
  stats_changed.emit()
func add_item(item_id: String, quantity: int = 1) -> void:
  if item_id.is_empty() or quantity <= 0: return
  for item in profile.inventory:
    if item.id == item_id:
      item.quantity += quantity
      inventory_changed.emit()
      return
  profile.inventory.append({"id":item_id,"quantity":quantity})
  inventory_changed.emit()
func use_consumable(item_id: String) -> bool:
  if item_id != "HP_Potion" and item_id != "Mana_Potion":
    return false
  var inventory: Array = profile.get("inventory", [])
  var found_index := -1
  for index in range(inventory.size()):
    var entry: Dictionary = inventory[index]
    if str(entry.get("id", "")) == item_id and int(entry.get("quantity", 1)) > 0:
      found_index = index
      break
  if found_index < 0:
    return false
  if item_id == "HP_Potion":
    if ClassSystem.hp >= ClassSystem.max_hp:
      return false
    ClassSystem.restore_hp(maxi(1, int(round(float(ClassSystem.max_hp) * 0.30))))
  else:
    if ClassSystem.mp >= ClassSystem.max_mp:
      return false
    ClassSystem.restore_mana(maxi(1, int(round(float(ClassSystem.max_mp) * 0.30))))
  var remaining := int(inventory[found_index].get("quantity", 1)) - 1
  if remaining <= 0:
    inventory.remove_at(found_index)
  else:
    inventory[found_index]["quantity"] = remaining
  profile["inventory"] = inventory
  profile["hp"] = ClassSystem.hp
  profile["mp"] = ClassSystem.mp
  save_local()
  inventory_changed.emit()
  return true

func update_quest(quest_id: String, state: String) -> void:
  profile.quests[quest_id] = state
  quest_changed.emit()
func save_local() -> bool:
  var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
  if f == null: return false
  f.store_string(JSON.stringify(profile))
  f.close()
  return true
func load_local() -> bool:
  if not FileAccess.file_exists(SAVE_PATH): return false
  var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
  if f == null: return false
  var raw_text := f.get_as_text()
  f.close()
  var data = JSON.parse_string(raw_text)
  if typeof(data) != TYPE_DICTIONARY: return false
  var merged := {"character_name":"Player","level":1,"experience":0,"gold":100,"hp":100,"max_hp":100,"mp":50,"max_mp":50,"inventory":[],"quests":{"first_hunt":"not_started"},"settlement_id":"TwinCity","world_position":[0.0,0.0,0.0],"player_guild_name":"","player_guild_rank":"","player_guild_donation":0,"guild_war_title":""}
  for key in data:
    merged[key] = data[key]
  if typeof(merged.get("inventory",[])) != TYPE_ARRAY: merged["inventory"] = []
  if typeof(merged.get("quests",{})) != TYPE_DICTIONARY: merged["quests"] = {}
  var saved_position = merged.get("world_position",[])
  if typeof(saved_position) != TYPE_ARRAY or saved_position.size() < 3: merged["world_position"] = [0.0,0.0,0.0]
  merged["level"] = maxi(1,int(merged.get("level",1)))
  merged["experience"] = maxi(0,int(merged.get("experience",0)))
  merged["hp"] = maxi(0,int(merged.get("hp",100)))
  merged["max_hp"] = maxi(1,int(merged.get("max_hp",100)))
  merged["mp"] = maxi(0,int(merged.get("mp",50)))
  merged["max_mp"] = maxi(1,int(merged.get("max_mp",50)))
  profile = merged
  profile["gold"] = GlobalEconomy.current_gold
  stats_changed.emit()
  inventory_changed.emit()
  quest_changed.emit()
  return true

extends Node
signal stats_changed
signal inventory_changed
signal quest_changed
const SAVE_PATH := "user://offline_profile.json"
var profile := {"character_name":"Player","level":1,"experience":0,"gold":100,"hp":100,"max_hp":100,"mp":50,"max_mp":50,"inventory":[],"quests":{"first_hunt":"not_started"},"world_position":[0.0,0.0,0.0]}
func add_gold(amount: int) -> void:
  if GlobalEconomy.add_gold(amount):
    profile.gold = GlobalEconomy.current_gold
    stats_changed.emit()
func add_experience(amount: int) -> void:
  profile.experience = maxi(0, int(profile.experience) + amount)
  while profile.experience >= int(profile.level) * 100:
    profile.experience -= int(profile.level) * 100
    profile.level += 1
    profile.max_hp += 10
    profile.max_mp += 5
    profile.hp = profile.max_hp
    profile.mp = profile.max_mp
  stats_changed.emit()
func damage_player(amount: int) -> void:
  profile.hp = maxi(0, int(profile.hp) - maxi(0, amount))
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
func update_quest(quest_id: String, state: String) -> void:
  profile.quests[quest_id] = state
  quest_changed.emit()
func save_local() -> bool:
  var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
  if f == null: return false
  f.store_string(JSON.stringify(profile))
  return true
func load_local() -> bool:
  if not FileAccess.file_exists(SAVE_PATH): return false
  var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
  if f == null: return false
  var data = JSON.parse_string(f.get_as_text())
  if typeof(data) != TYPE_DICTIONARY: return false
  profile = data
  profile.gold = GlobalEconomy.current_gold
  stats_changed.emit()
  inventory_changed.emit()
  quest_changed.emit()
  return true

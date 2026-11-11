extends Node
signal changed
const DATA={"promotion_15":{"title":"اختبار الترقية 15","level":15,"target":"ClassTrainer","goal":1,"gold":25000,"xp":1500,"items":[{"id":"Meteor","quantity":2}],"kind":"npc"},"promotion_40":{"title":"السفاح الشرقي والسكاكين المزدوجة","level":40,"target":"Bandit","goal":12,"gold":90000,"xp":7000,"items":[{"id":"assassin_throwing_knife","quantity":2}],"kind":"kill"},"promotion_70":{"title":"اختبار الترقية 70","level":70,"target":"GiantApe","goal":15,"gold":180000,"xp":16000,"items":[{"id":"PlusStone_2","quantity":2}],"kind":"kill"},"promotion_100":{"title":"اختبار الترقية 100","level":100,"target":"WaterDragon","goal":1,"gold":400000,"xp":45000,"items":[{"id":"DragonBall","quantity":1}],"kind":"kill"},"promotion_110":{"title":"سيد الغابة المظلمة","level":110,"target":"AncientDragon","goal":1,"gold":650000,"xp":80000,"items":[{"id":"Super_Dragon","quantity":1}],"kind":"kill"},"hunt_twin":{"title":"حماية مدينة التوأم","level":1,"target":"Pheasant","goal":10,"gold":1200,"xp":250,"items":[{"id":"monster_material","quantity":3}],"kind":"kill"},"hunt_desert":{"title":"قطاع الطرق","level":15,"target":"Bandit","goal":12,"gold":6000,"xp":1200,"items":[{"id":"Meteor","quantity":1}],"kind":"kill"},"hunt_volcano":{"title":"لهيب البركان","level":40,"target":"FireRat","goal":15,"gold":18000,"xp":4000,"items":[{"id":"PlusStone_1","quantity":2}],"kind":"kill"},"hunt_ice":{"title":"حراس الجليد","level":70,"target":"IceMonster","goal":15,"gold":32000,"xp":8000,"items":[{"id":"Phoenix_Refined","quantity":1}],"kind":"kill"},"hunt_water":{"title":"سر الماء القديم","level":95,"target":"Serpent","goal":18,"gold":55000,"xp":14000,"items":[{"id":"DragonBall","quantity":1}],"kind":"kill"},"hunt_forest":{"title":"قلب الغابة المظلمة","level":115,"target":"AncientDragon","goal":1,"gold":120000,"xp":30000,"items":[{"id":"Meteor","quantity":5}],"kind":"kill"},"treasure_01":{"title":"خريطة الكنز المنسي","level":20,"target":"TreasureChest","goal":1,"gold":45000,"xp":3500,"items":[{"id":"Super_Rainbow","quantity":1}],"kind":"treasure"}}
var progress:Dictionary={}
var active_quest=""
func _ready() -> void:
 add_to_group("quest_system"); progress=GlobalEconomy.quest_data.duplicate(true)
 for id in DATA:
  if not progress.has(id): progress[id]={"state":"locked","count":0}
func available() -> Array:
 var out=[]
 for id in DATA:
  var q=DATA[id]; var p=progress[id]
  if ClassSystem.level>=int(q.level) and p.state!="completed": out.append({"id":id,"title":q.title,"state":p.state,"count":int(p.count),"goal":int(q.goal),"target":q.target})
 return out
func accept(id:String) -> bool:
 if not DATA.has(id) or ClassSystem.level<int(DATA[id].level) or progress[id].state=="completed": return false
 progress[id].state="active"; active_quest=id; _save(); return true
func track(id:String) -> void:
 if not DATA.has(id): return
 active_quest=id; var q=DATA[id]; var p=get_tree().get_first_node_in_group("player")
 if is_instance_valid(p):
  if q.kind=="npc":
   for n in get_tree().get_nodes_in_group("npcs"):
    if n.get("role")=="class_trainer": p.call("move_to_world_position",n.global_position+Vector3(0,0,2)); break
  elif q.kind=="treasure":
   for n in get_tree().get_nodes_in_group("npcs"):
    if n.get("role")=="treasure_chest": p.call("move_to_world_position",n.global_position+Vector3(0,0,2)); break
  else:
   for n in get_tree().get_nodes_in_group("enemies"):
    if n.get("monster_id")==q.target: p.call("move_to_world_position",n.global_position+Vector3(0,0,2)); break
 _save()
func npc_interacted(role:String) -> void:
 if role=="treasure_chest":
  for id in DATA:
   if DATA[id].kind=="treasure" and progress[id].state=="active": progress[id].count=1; progress[id].state="ready"; _save()
 for id in DATA:
  if DATA[id].kind=="npc" and progress[id].state=="active" and role=="class_trainer": progress[id].count=1; progress[id].state="ready"; _save()
func monster_killed(monster_id:String) -> void:
 for id in DATA:
  var q=DATA[id]; var p=progress[id]
  if q.kind=="kill" and p.state=="active" and q.target==monster_id:
   p.count=mini(int(q.goal),int(p.count)+1)
   if p.count>=int(q.goal): p.state="ready"
   _save()
func claim(id:String) -> bool:
 if not DATA.has(id) or progress[id].state!="ready": return false
 var q=DATA[id]; GlobalEconomy.add_gold(int(q.gold)); ClassSystem.add_experience(int(q.xp))
 for item in q.items: GameState.add_item(item.id,int(item.quantity))
 if id.begins_with("promotion_") and ClassSystem.can_promote(): ClassSystem.promote()
 if id=="promotion_40" and ClassSystem.can_evolve_to("Oriental_Assassin"): ClassSystem.evolve_to("Oriental_Assassin")
 progress[id].state="completed"; _save(); return true
func _save() -> void:
 GlobalEconomy.quest_data=progress.duplicate(true); GlobalEconomy.save_runtime_state(); changed.emit()

extends Node3D
const ROLES=[["ClassTrainer","مدرب الفئات","class_trainer",Vector3(-18,0,14)],["Blacksmith","الحداد","blacksmith",Vector3(-4,0,22)],["Armorer","تاجر الدروع","armorer",Vector3(11,0,19)],["Pharmacist","الصيدلي","pharmacist",Vector3(21,0,5)],["Warehouseman","أمين الخزنة","warehouseman",Vector3(17,0,-14)],["GuildDirector","مدير العشائر","guild_director",Vector3(-7,0,-22)]]
func setup(world:Node3D,settlement:String) -> void:
 for d in ROLES:
  if d[0] == "GuildDirector" and settlement != "TwinCity": continue
  var n=load("res://src/scenes/NPC.tscn").instantiate(); n.name=d[0]; n.npc_id=settlement+"_"+d[0]; n.display_name=d[1]; n.role=d[2]; n.position=d[3]; n.interacted.connect(_on_interacted); world.add_child(n)
  var marker=Marker3D.new(); marker.name="BotInteractionSpot_"+d[2]; marker.position=d[3]+Vector3(0,0,2.8); world.add_child(marker)
 var chest=load("res://src/scenes/NPC.tscn").instantiate(); chest.name="TreasureChest"; chest.npc_id=settlement+"_TreasureChest"; chest.display_name="صندوق كنز"; chest.role="treasure_chest"; chest.position=Vector3(40,0,-42); chest.interacted.connect(_on_interacted); world.add_child(chest)
func _on_interacted(_npc_id:String,role:String) -> void:
 var q=get_tree().get_first_node_in_group("quest_system")
 if is_instance_valid(q): q.call("npc_interacted",role)
 get_tree().call_group("game_hud","on_npc_interacted",role)

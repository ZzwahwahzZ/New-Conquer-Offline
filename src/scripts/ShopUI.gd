extends CanvasLayer
var panel:PanelContainer
var list:VBoxContainer
var role="blacksmith"
const STOCK={"blacksmith":[["trojan_blade_15",1200],["warrior_sword_15",1200],["ninja_katana_15",1400],["archer_bow",1100],["assassin_throwing_knife",2200]],"armorer":[["archer_armor_15",900],["archer_helmet_15",500],["basic_necklace",350],["basic_boots",300],["basic_ring",400]],"pharmacist":[["HP_Potion",35],["Mana_Potion",40],["City_Scroll",250]],"class_trainer":[["ExpBall",50000],["DoubleExp",120000]]}
func _ready() -> void:
 panel=PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position=Vector2(-220,-240); panel.size=Vector2(440,480); add_child(panel)
 var v=VBoxContainer.new(); panel.add_child(v); var h=HBoxContainer.new(); v.add_child(h); var t=Label.new(); t.text="متجر التاجر | الذهب فقط"; t.size_flags_horizontal=Control.SIZE_EXPAND_FILL; h.add_child(t); var c=Button.new(); c.text="إغلاق"; c.pressed.connect(panel.hide); h.add_child(c)
 list=VBoxContainer.new(); v.add_child(list)
func open_shop(r:String) -> void: role=r; panel.show(); refresh()
func refresh() -> void:
 for n in list.get_children(): n.queue_free()
 for entry in STOCK.get(role,STOCK.blacksmith):
  var row=HBoxContainer.new(); list.add_child(row); var l=Label.new(); l.text="%s - %d ذهب"%[entry[0],entry[1]]; l.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(l); var b=Button.new(); b.text="شراء"; b.pressed.connect(_buy.bind(entry[0],entry[1])); row.add_child(b)
 var sell=Button.new(); sell.text="بيع كل العتاد العادي"; sell.pressed.connect(_sell_all); list.add_child(sell)
func _buy(id:String,cost:int) -> void:
 if GlobalEconomy.remove_gold(cost): GameState.add_item(id,1)
func _sell_all() -> void:
 var items:Array=GameState.profile.get("inventory",[]); var earned=0
 for i in range(items.size()-1,-1,-1):
  var item=items[i]
  if str(item.get("quality","Normal"))=="Normal":
   earned+=100*int(item.get("quantity",1)); items.remove_at(i)
 GameState.profile.inventory=items; if earned>0: GlobalEconomy.add_gold(earned)
 GameState.inventory_changed.emit(); GameState.save_local()

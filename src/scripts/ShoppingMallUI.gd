extends CanvasLayer
const GOODS=[["Meteor",25000],["DragonBall",180000],["PlusStone_1",6000],["PlusStone_2",15000],["PlusStone_3",35000],["PlusStone_4",70000],["PlusStone_5",130000],["PlusStone_6",240000],["ToughDrill",45000],["StarDrill",95000],["Dragon_Normal",12000],["Dragon_Refined",50000],["Dragon_Super",200000],["Phoenix_Normal",12000],["Phoenix_Refined",50000],["Phoenix_Super",200000],["Rainbow_Normal",12000],["Rainbow_Refined",50000],["Rainbow_Super",200000],["Violet_Normal",12000],["Violet_Refined",50000],["Violet_Super",200000],["Moon_Normal",12000],["Moon_Refined",50000],["Moon_Super",200000],["Fury_Normal",12000],["Fury_Refined",50000],["Fury_Super",200000],["Kylin_Normal",12000],["Kylin_Refined",50000],["Kylin_Super",200000],["Garment_Vanguard",90000],["WeaponAccessory_Dragon",125000],["Steed_Chestnut",300000],["Steed_Cloud",650000],["ExpBall",50000],["DoubleExp",120000],["Megaphone",2500]]
var panel:PanelContainer
var list:VBoxContainer
func _ready() -> void:
 panel=PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position=Vector2(-310,-300); panel.size=Vector2(620,600); add_child(panel)
 var v=VBoxContainer.new(); panel.add_child(v); panel.add_theme_stylebox_override("panel", _lux_panel_style()); var h=HBoxContainer.new(); v.add_child(h); var t=Label.new(); t.text="المول الشامل - GOLD"; t.add_theme_color_override("font_color", Color("#FFE2A0")); t.size_flags_horizontal=Control.SIZE_EXPAND_FILL; h.add_child(t); var c=Button.new(); c.text="✕"; c.custom_minimum_size=Vector2(38,38); c.add_theme_color_override("font_color",Color("#FFE2A0")); c.add_theme_stylebox_override("normal",_lux_close_style()); c.pressed.connect(panel.hide); h.add_child(c)
 var scroll=ScrollContainer.new(); scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; v.add_child(scroll); list=VBoxContainer.new(); scroll.add_child(list)
 panel.hide()
func toggle() -> void: panel.visible=not panel.visible; refresh()
func _lux_close_style() -> StyleBoxFlat:
 var s=StyleBoxFlat.new(); s.bg_color=Color("#641D16"); s.border_color=Color("#D4AF37"); s.set_border_width_all(2); s.set_corner_radius_all(19); return s
func _lux_panel_style() -> StyleBoxFlat:
 var s=StyleBoxFlat.new(); s.bg_color=Color(0.08,0.06,0.05,0.97); s.border_color=Color("#D4AF37"); s.set_border_width_all(4); s.set_corner_radius_all(7); s.shadow_color=Color(0,0,0,0.85); s.shadow_size=9; s.shadow_offset=Vector2(0,4); return s
func refresh() -> void:
 for n in list.get_children(): n.queue_free()
 for item in GOODS:
  var row=HBoxContainer.new(); list.add_child(row); var l=Label.new(); l.text="%s | %d ذهب"%[item[0],item[1]]; l.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(l); var b=Button.new(); b.text="شراء"; b.pressed.connect(_buy.bind(item[0],item[1])); row.add_child(b)
func _buy(id:String,cost:int) -> void:
 if not GlobalEconomy.remove_gold(cost): return
 if id.begins_with("PlusStone_"):
  var level=int(id.get_slice("_",1))
  GearSystem.inventory.append({"id":"plus_stone_%d"%level,"item_type":"plus_stone","stone_level":level,"quantity":1,"instance_id":"mall_plus_%d"%Time.get_ticks_usec()})
  GearSystem.call("_save_and_emit")
 elif not GearDatabase.get_gem(id).is_empty(): GearSystem.add_gem(id,1)
 elif not GearDatabase.get_blueprint(id).is_empty(): GearSystem.add_item(id,1)
 else: GameState.add_item(id,1)

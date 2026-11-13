extends CanvasLayer
const ThemeManager = preload("res://src/scripts/ui/RPGIconThemeManager.gd")
const CAPACITY: int = 80
var page: int = 0
var panel: PanelContainer
var grid: GridContainer
var page_label: Label
func _ready() -> void:
 panel=PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position=Vector2(-300,-280); panel.size=Vector2(600,560); panel.add_theme_stylebox_override("panel",ThemeManager.frame_style()); add_child(panel)
 var v: VBoxContainer = VBoxContainer.new(); panel.add_child(v); var h: HBoxContainer = HBoxContainer.new(); v.add_child(h); var t: Label = Label.new(); t.text="الخزنة الموحدة - 80 خانة"; t.size_flags_horizontal=Control.SIZE_EXPAND_FILL; h.add_child(t); var c: Button = Button.new(); c.text="إغلاق"; c.pressed.connect(panel.hide); h.add_child(c)
 var gold: HBoxContainer = HBoxContainer.new(); v.add_child(gold); var d: Button = Button.new(); d.text="إيداع 1000 ذهب"; d.pressed.connect(_deposit); gold.add_child(d); var w: Button = Button.new(); w.text="سحب 1000 ذهب"; w.pressed.connect(_withdraw); gold.add_child(w)
 grid=GridContainer.new(); grid.columns=8; grid.size_flags_vertical=Control.SIZE_EXPAND_FILL; v.add_child(grid)
 for i in range(40):
  var b: Button = Button.new(); b.custom_minimum_size=Vector2(62,52); b.pressed.connect(_slot.bind(i)); grid.add_child(b)
 var f: HBoxContainer = HBoxContainer.new(); v.add_child(f); var p: Button = Button.new(); p.text="1"; p.pressed.connect(func():page=0;refresh()); f.add_child(p); page_label=Label.new(); page_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; page_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; f.add_child(page_label); var n: Button = Button.new(); n.text="2"; n.pressed.connect(func():page=1;refresh()); f.add_child(n)
 ThemeManager.apply_to_tree(self)
 panel.hide()
func toggle() -> void: panel.visible=not panel.visible; refresh()
func refresh() -> void:
 if not is_instance_valid(grid): return
 page_label.text = "صفحة %d / 2 | ذهب الخزنة: %d" % [page + 1, GlobalEconomy.warehouse_gold]
 for i in range(40):
  var idx: int = page * 40 + i; var item: Dictionary = GlobalEconomy.warehouse_items[idx] if idx < GlobalEconomy.warehouse_items.size() else {}
  var slot_button := grid.get_child(i) as Button
  slot_button.text=("%s x%d"%[item.get("id",""),item.get("quantity",0)]) if not item.is_empty() else "فارغ"
  slot_button.icon=ThemeManager.item_texture(str(item.get("id",""))) if not item.is_empty() else null
  slot_button.expand_icon=true
func _slot(i:int) -> void:
 var idx: int = page * 40 + i; var bank=GlobalEconomy.warehouse_items; var inv:Array=GameState.profile.get("inventory",[])
 if bank[idx].is_empty():
  if not GearSystem.inventory.is_empty():
   bank[idx]=GearSystem.inventory.pop_front(); GearSystem.call("_save_and_emit")
  elif not inv.is_empty():
   bank[idx]=inv.pop_front(); GameState.profile.inventory=inv
 elif not bank[idx].is_empty():
  var item:Dictionary=bank[idx]
  if item.has("slot") or item.has("weapon_family") or str(item.get("item_type","")) in ["gem","plus_stone"]:
   GearSystem.inventory.append(item); GearSystem.call("_save_and_emit")
  else:
   inv.append(item); GameState.profile.inventory=inv
  bank[idx]={}
 GlobalEconomy.warehouse_items=bank; GameState.inventory_changed.emit(); GlobalEconomy.save_runtime_state(); GameState.save_local(); refresh()
func _deposit() -> void:
 if not GlobalEconomy.remove_gold(1000): return
 GlobalEconomy.warehouse_gold+=1000
 if not GlobalEconomy.save_runtime_state():
  GlobalEconomy.warehouse_gold-=1000
  GlobalEconomy.add_gold(1000)
 refresh()
func _withdraw() -> void:
 if GlobalEconomy.warehouse_gold<1000: return
 GlobalEconomy.warehouse_gold-=1000
 if not GlobalEconomy.add_gold(1000):
  GlobalEconomy.warehouse_gold+=1000
  return
 GlobalEconomy.save_runtime_state()
 refresh()

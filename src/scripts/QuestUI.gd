extends CanvasLayer
var panel:PanelContainer
var list:VBoxContainer
func _ready() -> void:
 panel=PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_CENTER); panel.position=Vector2(-240,-260); panel.size=Vector2(480,520); add_child(panel)
 var v=VBoxContainer.new(); panel.add_child(v); var h=HBoxContainer.new(); v.add_child(h); var t=Label.new(); t.text="سجل المهام"; t.size_flags_horizontal=Control.SIZE_EXPAND_FILL; h.add_child(t); var c=Button.new(); c.text="إغلاق"; c.pressed.connect(panel.hide); h.add_child(c); list=VBoxContainer.new(); v.add_child(list)
 var q=get_tree().get_first_node_in_group("quest_system"); if is_instance_valid(q): q.changed.connect(refresh)
 refresh()
func toggle() -> void: panel.visible=not panel.visible; refresh()
func _accept_and_track(q:Node,id:String) -> void:
 if q.call("accept",id): q.call("track",id)
func refresh() -> void:
 if not is_instance_valid(list): return
 for n in list.get_children(): n.queue_free()
 var q=get_tree().get_first_node_in_group("quest_system"); if not is_instance_valid(q): return
 for item in q.call("available"):
  var row=HBoxContainer.new(); list.add_child(row); var l=Label.new(); l.text="%s %d/%d"%(item.title,item.count,item.goal); l.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(l)
  var b=Button.new(); b.text="استلام" if item.state=="ready" else ("تتبّع" if item.state=="active" else "قبول وتتبع"); row.add_child(b)
  if item.state=="ready": b.pressed.connect(Callable(q,"claim").bind(item.id))
  elif item.state=="active": b.pressed.connect(Callable(q,"track").bind(item.id))
  else: b.pressed.connect(_accept_and_track.bind(q,item.id))

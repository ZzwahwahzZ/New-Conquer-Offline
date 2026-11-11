extends Control
## Compact top-down map with classic 0..1000 world coordinates.
var world_manager: Node
var player: Node3D
var coordinate_label: Label
var settlement_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(184,184)
	size = Vector2(184,184)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	coordinate_label = Label.new()
	coordinate_label.position = Vector2(8,160)
	coordinate_label.size = Vector2(168,20)
	coordinate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coordinate_label.add_theme_font_size_override("font_size",12)
	add_child(coordinate_label)
	settlement_label = Label.new()
	settlement_label.position = Vector2(5,2)
	settlement_label.size = Vector2(174,20)
	settlement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settlement_label.add_theme_font_size_override("font_size",12)
	settlement_label.add_theme_color_override("font_color",Color(1.0,0.82,0.48))
	add_child(settlement_label)

func configure(manager: Node, target_player: Node3D) -> void:
	world_manager = manager
	player = target_player

func _process(_delta: float) -> void:
	queue_redraw()
	if not is_instance_valid(player) or not is_instance_valid(world_manager): return
	var p := player.global_position
	coordinate_label.text = "X: %04d   Y: %04d" % [clampi(roundi(500.0+p.x*4.0),0,9999),clampi(roundi(500.0+p.z*4.0),0,9999)]
	settlement_label.text = world_manager.call("get_settlement_name",str(world_manager.get("current_settlement")))

func _draw() -> void:
	draw_style_box(_panel_style(),Rect2(Vector2.ZERO,Vector2(184,184)))
	var center := Vector2(92,88)
	for step in [-60.0,-30.0,0.0,30.0,60.0]:
		draw_line(center+Vector2(step,-65),center+Vector2(step,65),Color(0.5,0.56,0.58,0.22),1.0)
		draw_line(center+Vector2(-65,step),center+Vector2(65,step),Color(0.5,0.56,0.58,0.22),1.0)
	if not is_instance_valid(world_manager): return
	var snapshot: Dictionary = world_manager.call("get_minimap_snapshot")
	var origin: Vector3 = snapshot.get("player",Vector3.ZERO)
	for monster_position in snapshot.get("monsters",[]):
		var delta: Vector3 = monster_position-origin
		var point := center+Vector2(delta.x,-delta.z)*0.72
		if Rect2(Vector2(8,22),Vector2(168,132)).has_point(point): draw_circle(point,2.7,Color(0.95,0.25,0.2))
	var portal_delta: Vector3 = snapshot.get("portal",Vector3.ZERO)-origin
	draw_circle(center+Vector2(portal_delta.x,-portal_delta.z)*0.72,4.0,Color(0.15,0.72,1.0))
	draw_circle(center,4.5,Color(0.35,1.0,0.48))
	draw_arc(center,6.5,0.0,TAU,24,Color(0.9,0.94,0.84),1.2)

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.04,0.055,0.88)
	style.border_color = Color(0.72,0.55,0.3,0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

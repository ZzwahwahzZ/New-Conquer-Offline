extends CanvasLayer
## Landscape equipment and inventory screen. GearSystem remains the source of truth.
const ThemeManager = preload("res://src/scripts/ui/RPGIconThemeManager.gd")
## The preview rig is procedural until production character/weapon scenes are assigned.

const SLOT_ORDER := ["Helmet", "Necklace", "Armor", "RightHand", "LeftHand", "Ring", "Boots"]
const SLOT_AR := {
	"Helmet":"خوذة", "Necklace":"قلادة", "Armor":"درع",
	"RightHand":"اليد اليمنى", "LeftHand":"اليد اليسرى", "Ring":"خاتم", "Boots":"حذاء"
}
const QUALITY_COLORS := {
	"Normal": Color("#e9edf2"), "Refined": Color("#58d879"),
	"Unique": Color("#54a7ff"), "Elite": Color("#bd6cff"), "Super": Color("#ffc84a")
}
const SLOT_ICONS := {"Helmet":"shield", "Necklace":"gem", "Armor":"shield", "RightHand":"weapon", "LeftHand":"weapon", "Ring":"gem", "Boots":"shield"}

var _root: Control
var _preview_container: SubViewportContainer
var _preview_viewport: SubViewport
var _preview_pivot: Node3D
var _equipment_list: VBoxContainer
var _grid: GridContainer
var _details: RichTextLabel
var _equip_button: Button
var _selected_index: int = -1
var _selected_item: Dictionary = {}
var _slot_buttons: Dictionary = {}
var _slot_labels: Dictionary = {}
var _touch_id: int = -1
var _last_x: float = 0.0
var _mouse_drag := false
var _preview_items: Dictionary = {}
var _stat_label: Label
var _page_label: Label
var _current_page := 0
const ITEMS_PER_PAGE := 30
const GRID_COLUMNS := 5

func _ready() -> void:
	add_to_group("inventory_ui")
	_build_ui()
	_build_preview()
	_connect_gear()
	_refresh_all()
	ThemeManager.apply_to_tree(self)
	visible = false

func toggle() -> void:
	if not visible:
		var market_ui := get_tree().get_first_node_in_group("upgrade_market_ui")
		if is_instance_valid(market_ui) and market_ui.has_method("close"):
			market_ui.call("close")
		visible = true
		_refresh_all()
	else:
		visible = false

func open() -> void:
	visible = true
	_refresh_all()

func close() -> void:
	visible = false

func _connect_gear() -> void:
	if not GearSystem.inventory_changed.is_connected(_on_gear_changed):
		GearSystem.inventory_changed.connect(_on_gear_changed)
	if not GearSystem.equipment_changed.is_connected(_on_gear_changed):
		GearSystem.equipment_changed.connect(_on_gear_changed)
	if not GameState.stats_changed.is_connected(_refresh_stats):
		GameState.stats_changed.connect(_refresh_stats)

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "InventoryRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.008, 0.012, 0.022, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var frame := PanelContainer.new()
	frame.name = "InventoryFrame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 24
	frame.offset_top = 18
	frame.offset_right = -24
	frame.offset_bottom = -18
	frame.add_theme_stylebox_override("panel", _style(Color(0.08, 0.06, 0.05, 0.97), Color("#D4AF37"), 4, 8))
	_root.add_child(frame)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	frame.add_child(body)

	var header := HBoxContainer.new()
	body.add_child(header)
	var title := Label.new()
	title.text = "الشخصية والحقيبة"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", Color("#f2d18b"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "✕"
	close_button.add_theme_color_override("font_color", Color("#FFE2A0"))
	close_button.add_theme_stylebox_override("normal", _style(Color("#641D16"), Color("#D4AF37"), 2, 20))
	close_button.add_theme_stylebox_override("hover", _style(Color("#9B2A1C"), Color("#FFE2A0"), 2, 20))
	close_button.custom_minimum_size = Vector2(48, 38)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	body.add_child(content)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 390
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	content.add_child(left)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _style(Color("#17100A"), Color("#A97932"), 2, 5))
	left.add_child(preview_panel)
	var preview_stack := VBoxContainer.new()
	preview_panel.add_child(preview_stack)
	var preview_title := Label.new()
	preview_title.text = "معاينة الشخصية  •  اسحب للتدوير"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_color_override("font_color", Color("#e9cc8d"))
	preview_stack.add_child(preview_title)
	_preview_container = SubViewportContainer.new()
	_preview_container.name = "CharacterPreview"
	_preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_container.stretch = true
	_preview_container.custom_minimum_size = Vector2(300, 310)
	_preview_container.mouse_filter = Control.MOUSE_FILTER_STOP
	preview_stack.add_child(_preview_container)
	_preview_container.gui_input.connect(_on_preview_input)

	_stat_label = Label.new()
	_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_label.add_theme_font_size_override("font_size", 16)
	_stat_label.add_theme_color_override("font_color", Color("#f4dfb5"))
	_stat_label.text = "ATK 0     DEF 0     HP 0"
	left.add_child(_stat_label)

	var slots_panel := PanelContainer.new()
	slots_panel.add_theme_stylebox_override("panel", _style(Color("#21170E"), Color("#9D7134"), 2, 5))
	left.add_child(slots_panel)
	_equipment_list = VBoxContainer.new()
	_equipment_list.add_theme_constant_override("separation", 3)
	slots_panel.add_child(_equipment_list)
	for slot in SLOT_ORDER:
		var row := HBoxContainer.new()
		row.name = "EquipmentRow_" + slot
		row.layout_direction = Control.LAYOUT_DIRECTION_LTR
		row.add_theme_constant_override("separation", 6)
		_equipment_list.add_child(row)
		var label := Label.new()
		label.name = "EquipmentLabel_" + slot
		label.text = "فارغ"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_color", Color("#d9c49b"))
		row.add_child(label)
		var button := Button.new()
		button.name = "Equipment_" + slot
		button.custom_minimum_size = Vector2(38, 34)
		button.icon = ThemeManager.item_texture(SLOT_ICONS[slot])
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text = ""
		button.tooltip_text = SLOT_AR[slot]
		button.pressed.connect(_on_equipment_slot_pressed.bind(slot))
		row.add_child(button)
		_slot_labels[slot] = label
		_slot_buttons[slot] = button

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 490
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.0
	content.add_child(right)

	var bag_header := HBoxContainer.new()
	right.add_child(bag_header)
	var bag_title := Label.new()
	bag_title.text = "الحقيبة"
	bag_title.add_theme_font_size_override("font_size", 20)
	bag_title.add_theme_color_override("font_color", Color("#f2d18b"))
	bag_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag_header.add_child(bag_title)
	_page_label = Label.new()
	_page_label.add_theme_color_override("font_color", Color("#d8c49c"))
	bag_header.add_child(_page_label)

	var grid_panel := PanelContainer.new()
	grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_panel.add_theme_stylebox_override("panel", _style(Color("#100B07"), Color("#D4AF37"), 2, 5))
	right.add_child(grid_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_panel.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(_grid)

	var pager := HBoxContainer.new()
	right.add_child(pager)
	var prev := Button.new()
	prev.text = "السابق"
	prev.pressed.connect(func(): _change_page(-1))
	pager.add_child(prev)
	var next := Button.new()
	next.text = "التالي"
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(func(): _change_page(1))
	pager.add_child(next)

	var details_panel := PanelContainer.new()
	details_panel.custom_minimum_size.y = 142
	details_panel.add_theme_stylebox_override("panel", _style(Color("#20232b"), Color("#806b48"), 2, 8))
	right.add_child(details_panel)
	var details_box := VBoxContainer.new()
	details_panel.add_child(details_box)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.fit_content = false
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.text = "اختر قطعة من الحقيبة لعرض تفاصيلها."
	details_box.add_child(_details)
	_equip_button = Button.new()
	_equip_button.text = "لبس القطعة"
	_equip_button.disabled = true
	_equip_button.pressed.connect(_on_equip_pressed)
	details_box.add_child(_equip_button)

func _build_preview() -> void:
	_preview_viewport = SubViewport.new()
	_preview_viewport.name = "PreviewViewport"
	_preview_viewport.own_world_3d = true # Isolate the paper-doll preview from the live game world and player camera.
	_preview_viewport.size = Vector2i(512, 512)
	_preview_viewport.transparent_bg = false
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_container.add_child(_preview_viewport)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8290ad")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	_preview_viewport.add_child(world)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.45, 4.4)
	camera.look_at(Vector3(0, 1.05, 0), Vector3.UP)
	camera.current = true
	camera.fov = 36
	_preview_viewport.add_child(camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-32, -28, 0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	_preview_viewport.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.0, 1.7, 2.0)
	fill_light.light_color = Color("#8eb8ff")
	fill_light.light_energy = 0.65
	fill_light.omni_range = 6.0
	_preview_viewport.add_child(fill_light)

	_preview_pivot = Node3D.new()
	_preview_pivot.name = "CharacterPivot"
	_preview_pivot.rotation.y = 0.0 # Godot humanoid forward (+Z for this preview rig) faces the camera at +Z.
	_preview_viewport.add_child(_preview_pivot)
	_build_preview_skeleton()
	_build_preview_mannequin()

func _build_preview_skeleton() -> void:
	var skeleton := Skeleton3D.new()
	skeleton.name = "PaperdollSkeleton"
	_preview_pivot.add_child(skeleton)
	var names := ["Root", "Spine", "Head", "RightHand", "LeftHand", "Chest"]
	var parents := [-1, 0, 1, 1, 1, 1]
	var rests := [
		Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.72, 0)),
		Transform3D(Basis.IDENTITY, Vector3(0.48, -0.2, 0)),
		Transform3D(Basis.IDENTITY, Vector3(-0.48, -0.2, 0)),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0))
	]
	for i in range(names.size()):
		skeleton.add_bone(names[i])
		skeleton.set_bone_parent(i, parents[i])
		skeleton.set_bone_rest(i, rests[i])
	for pair in [{"node":"RightHandMount","bone":"RightHand"},{"node":"LeftHandMount","bone":"LeftHand"},{"node":"BodyMount","bone":"Spine"},{"node":"HelmetMount","bone":"Head"},{"node":"FeetMount","bone":"Root"}]:
		var attachment := BoneAttachment3D.new()
		attachment.name = pair.node
		attachment.bone_name = pair.bone
		skeleton.add_child(attachment)
		_preview_items[pair.node] = attachment
		if pair.node == "FeetMount":
			attachment.position = Vector3(0, 0.08, 0)

func _build_preview_mannequin() -> void:
	var skin := _material(Color("#c58f68"), 0.0)
	var cloth := _material(Color("#315b80"), 0.0)
	var leather := _material(Color("#473b35"), 0.0)
	_add_capsule_mesh(_preview_pivot, Vector3(0, 1.28, 0), 0.34, 0.72, cloth)
	_add_sphere_mesh(_preview_pivot, Vector3(0, 1.92, 0), 0.19, skin)
	# Visible facial features on the camera-facing (+Z) side make orientation unambiguous.
	var face_marker := Node3D.new()
	face_marker.name = "CameraFacingFace"
	face_marker.position = Vector3(0, 1.92, 0)
	_preview_pivot.add_child(face_marker)
	var eye_mat := _material(Color("#241811"), 0.0)
	_add_sphere_mesh(face_marker, Vector3(-0.075, 0.03, 0.174), 0.026, eye_mat)
	_add_sphere_mesh(face_marker, Vector3(0.075, 0.03, 0.174), 0.026, eye_mat)
	_add_sphere_mesh(face_marker, Vector3(0, -0.025, 0.187), 0.022, skin)
	_add_capsule_mesh(_preview_pivot, Vector3(0.39, 1.28, 0), 0.105, 0.65, cloth)
	_add_capsule_mesh(_preview_pivot, Vector3(-0.39, 1.28, 0), 0.105, 0.65, cloth)
	_add_capsule_mesh(_preview_pivot, Vector3(0.16, 0.48, 0), 0.13, 0.8, leather)
	_add_capsule_mesh(_preview_pivot, Vector3(-0.16, 0.48, 0), 0.13, 0.8, leather)
	_add_capsule_mesh(_preview_pivot, Vector3(0, 1.48, 0.03), 0.37, 0.28, _material(Color("#6d5037"), 0.0))

func _add_capsule_mesh(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)

func _add_sphere_mesh(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)

func _material(color: Color, emission: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.28
	mat.roughness = 0.48
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1:
			_touch_id = event.index
			_last_x = event.position.x
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_rotate_preview(event.position.x - _last_x)
		_last_x = event.position.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_mouse_drag = event.pressed
		_last_x = event.position.x
	elif event is InputEventMouseMotion and _mouse_drag:
		_rotate_preview(event.position.x - _last_x)
		_last_x = event.position.x

func _rotate_preview(dx: float) -> void:
	_preview_pivot.rotate_y(-dx * 0.012)

func _refresh_all() -> void:
	_refresh_equipment()
	_refresh_inventory()
	_refresh_stats()
	_refresh_preview()

func _on_gear_changed() -> void:
	_refresh_all()

func _refresh_equipment() -> void:
	for slot in SLOT_ORDER:
		var item: Dictionary = GearSystem.equipment.get(slot, {})
		var button: Button = _slot_buttons[slot]
		var label: Label = _slot_labels[slot]
		if item.is_empty():
			label.text = "%s  •  فارغ" % SLOT_AR[slot]
			label.add_theme_color_override("font_color", Color("#aab0ba"))
			button.icon = ThemeManager.item_texture(SLOT_ICONS[slot])
		else:
			label.text = "%s  +%d" % [str(item.get("name", item.get("id", "قطعة"))), int(item.get("plus", 0))]
			label.add_theme_color_override("font_color", _quality_color(str(item.get("quality", "Normal"))))
			button.icon = ThemeManager.item_texture(str(item.get("id", "")))
		button.tooltip_text = "%s — %s" % [SLOT_AR[slot], label.text]

func _refresh_inventory() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var items: Array = GearSystem.inventory
	var pages := maxi(1, ceili(float(items.size()) / float(ITEMS_PER_PAGE)))
	_current_page = clampi(_current_page, 0, pages - 1)
	_page_label.text = "صفحة %d / %d" % [_current_page + 1, pages]
	for i in range(ITEMS_PER_PAGE):
		var index := _current_page * ITEMS_PER_PAGE + i
		var button := Button.new()
		button.custom_minimum_size = Vector2(68, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", _style(Color("#242a35"), Color("#4d5665"), 2, 5))
		if index < items.size():
			var item: Dictionary = items[index]
			var quality := str(item.get("quality", "Normal"))
			var sockets: Array = item.get("sockets", [])
			var socket_count := clampi(int(item.get("socket_count", sockets.size())), 0, 2)
			var filled := 0
			for socket in sockets:
				if str(socket) != "Empty":
					filled += 1
			var socket_marks := "●".repeat(filled) + "○".repeat(maxi(0, socket_count - filled)) + "·".repeat(2 - socket_count)
			button.text = "+%d\n%s" % [int(item.get("plus", 0)), socket_marks]
			button.tooltip_text = "%s | %s" % [str(item.get("name", item.get("id", "Item"))), quality]
			button.icon = ThemeManager.item_texture(str(item.get("id", "")))
			button.expand_icon = true
			var item_key := str(item.get("id", "")).to_lower()
			if item_key.begins_with("dragon"):
				button.modulate = Color("#FF7770")
			elif item_key.begins_with("phoenix"):
				button.modulate = Color("#83E58D")
			elif item_key.begins_with("rainbow"):
				button.modulate = Color("#75C9FF")
			elif item_key.begins_with("violet"):
				button.modulate = Color("#C99BFF")
			elif item_key.begins_with("fury") or item_key.begins_with("moon"):
				button.modulate = Color("#FFE080")
			else:
				button.modulate = Color.WHITE
			button.add_theme_color_override("font_color", _quality_color(quality))
			button.add_theme_stylebox_override("normal", _style(Color("#242a35"), _quality_color(quality), 2, 5))
			button.pressed.connect(_select_inventory_item.bind(index))
		else:
			button.text = ""
			button.disabled = true
		_grid.add_child(button)
	ThemeManager.apply_to_tree(_grid)

func _quality_color(quality: String) -> Color:
	return QUALITY_COLORS.get(quality, QUALITY_COLORS["Normal"])

func _select_inventory_item(index: int) -> void:
	if index < 0 or index >= GearSystem.inventory.size():
		return
	_selected_index = index
	_selected_item = GearSystem.inventory[index].duplicate(true)
	var stats: Dictionary = GearSystem.get_item_final_stats(_selected_item)
	var sockets: Array = _selected_item.get("sockets", ["Empty", "Empty"])
	var socket_text := "، ".join(PackedStringArray(sockets))
	_details.text = "[b][color=%s]%s[/color][/b]\nالجودة: %s  |  البلس: +%d\nالمستوى المطلوب: %d\nالخانة: %s\nالخصائص: %s\nالمقابس: %s\nالكمية: %d" % [
		_quality_color(str(_selected_item.get("quality", "Normal"))).to_html(),
		str(_selected_item.get("name", _selected_item.get("id", "قطعة"))),
		str(_selected_item.get("quality", "Normal")), int(_selected_item.get("plus", 0)),
		int(_selected_item.get("required_level", 1)),
		SLOT_AR.get(str(_selected_item.get("slot", "")), str(_selected_item.get("slot", "—"))),
		str(stats), socket_text, int(_selected_item.get("quantity", 1))
	]
	_equip_button.disabled = false
	_equip_button.text = "لبس القطعة"

func _on_equipment_slot_pressed(slot: String) -> void:
	var item: Dictionary = GearSystem.equipment.get(slot, {})
	if item.is_empty():
		return
	_selected_item = item.duplicate(true)
	_selected_index = -1
	_details.text = "[b]%s[/b]\nمجهزة في خانة %s\n+%d  |  %s\nالخصائص: %s" % [
		str(item.get("name", item.get("id", "قطعة"))), SLOT_AR[slot],
		int(item.get("plus", 0)), str(item.get("quality", "Normal")),
		str(GearSystem.get_item_final_stats(item))
	]
	_equip_button.disabled = false
	_equip_button.text = "خلع القطعة"
	_equip_button.set_meta("unequip_slot", slot)

func _on_equip_pressed() -> void:
	if _selected_item.is_empty():
		return
	if _equip_button.text == "خلع القطعة":
		var slot := str(_equip_button.get_meta("unequip_slot", ""))
		if not slot.is_empty():
			GearSystem.unequip_item(slot)
	else:
		var slot := str(_selected_item.get("slot", ""))
		var profile: Dictionary = GameState.profile
		var class_id := str(profile.get("class_id", "archer"))
		var current_class := "Oriental_Assassin" if class_id.to_lower() in ["oriental_assassin", "oriental assassin"] else "Archer" if class_id.to_lower() == "archer" else class_id.capitalize()
		var level := int(profile.get("class_level", profile.get("level", 1)))
		if GearSystem.equip_item(str(_selected_item.get("instance_id", "")), slot, current_class, level):
			_selected_index = -1
			_selected_item = {}
			_details.text = "تم تجهيز القطعة."
			_equip_button.disabled = true
		else:
			_details.text += "\n[color=#ff7777]تعذر اللبس: راجع الفئة والمستوى والخانة ومتطلبات السلاح.[/color]"
	_refresh_all()

func _change_page(direction: int) -> void:
	var pages := maxi(1, ceili(float(GearSystem.inventory.size()) / float(ITEMS_PER_PAGE)))
	_current_page = clampi(_current_page + direction, 0, pages - 1)
	_refresh_inventory()

func _refresh_stats() -> void:
	var atk := 0
	var defense := 0
	var bonus_hp := 0
	for slot in GearSystem.equipment:
		var item: Dictionary = GearSystem.equipment[slot]
		if item.is_empty():
			continue
		var stats: Dictionary = GearSystem.get_item_final_stats(item)
		atk += int(stats.get("physical_attack", 0)) + int(stats.get("magic_attack", 0))
		defense += int(stats.get("defense", 0))
		bonus_hp += int(stats.get("max_hp", 0))
	_stat_label.text = "ATK %d     DEF %d     HP %d" % [atk, defense, int(GameState.profile.get("max_hp", 100)) + bonus_hp]

func _refresh_preview() -> void:
	for mount_key in ["RightHandMount", "LeftHandMount", "BodyMount", "HelmetMount", "FeetMount"]:
		var mount: Node3D = _preview_items.get(mount_key)
		for child in mount.get_children():
			child.queue_free()
	for slot in GearSystem.equipment:
		var item: Dictionary = GearSystem.equipment[slot]
		if item.is_empty():
			continue
		var mount_key := "RightHandMount"
		if slot == "LeftHand":
			mount_key = "LeftHandMount"
		elif slot == "Armor":
			mount_key = "BodyMount"
		elif slot == "Helmet":
			mount_key = "HelmetMount"
		elif slot == "Necklace":
			mount_key = "BodyMount"
		elif slot == "Boots":
			mount_key = "FeetMount"
		elif slot == "Ring":
			mount_key = "RightHandMount"
		var mount: Node3D = _preview_items[mount_key]
		_add_equipment_preview(mount, slot, item)

func _add_equipment_preview(mount: Node3D, slot: String, item: Dictionary) -> void:
	var plus := clampi(int(item.get("plus", 0)), 0, 12)
	var glow := float(plus) / 12.0
	var tint := _quality_color(str(item.get("quality", "Normal")))
	var mesh_node := MeshInstance3D.new()
	if slot == "RightHand" or slot == "LeftHand":
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.07, 0.72, 0.07)
		mesh_node.mesh = mesh
		mesh_node.rotation_degrees.z = -28 if slot == "RightHand" else 28
		if str(item.get("weapon_family", "")) == "Bow":
			var bow := TorusMesh.new()
			bow.inner_radius = 0.16
			bow.outer_radius = 0.2
			mesh_node.mesh = bow
			mesh_node.scale = Vector3(0.65, 1.3, 0.45)
		elif str(item.get("weapon_family", "")) == "ThrowingKnife":
			var knife := BoxMesh.new()
			knife.size = Vector3(0.06, 0.48, 0.025)
			mesh_node.mesh = knife
	elif slot == "Ring":
		var ring := TorusMesh.new()
		ring.inner_radius = 0.045
		ring.outer_radius = 0.07
		mesh_node.mesh = ring
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.62, 0.68, 0.12) if slot == "Armor" else Vector3(0.35, 0.18, 0.25)
		mesh_node.mesh = mesh
	mesh_node.material_override = _material(tint.darkened(0.12), glow * 2.2)
	mesh_node.position = Vector3.ZERO
	mount.add_child(mesh_node)
	if plus > 0:
		var glow_light := OmniLight3D.new()
		glow_light.light_color = tint
		glow_light.light_energy = 0.15 + glow * 1.35
		glow_light.omni_range = 0.55 + glow * 1.1
		mount.add_child(glow_light)

func _style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box

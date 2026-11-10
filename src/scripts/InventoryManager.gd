extends Control
## Offline inventory with 30 visible slots per page and dynamically expandable pages.

signal page_changed(page_index: int, page_count: int)

const SLOTS_PER_PAGE: int = 30
const COLUMNS: int = 6

var current_page: int = 0
var _unlocked_pages: int = 1
var items: Array = []
var _page_label: Label
var _grid: GridContainer
var _previous_button: Button
var _next_button: Button
var _touch_start: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_load_items()
	_unlocked_pages = maxi(1, int(GameState.profile.get("inventory_pages", 1)))
	_unlocked_pages = maxi(_unlocked_pages, ceili(float(items.size()) / float(SLOTS_PER_PAGE)))
	_build_interface()
	_refresh_page()
	if not GameState.inventory_changed.is_connected(_on_inventory_changed):
		GameState.inventory_changed.connect(_on_inventory_changed)

func _load_items() -> void:
	var stored = GameState.profile.get("inventory", [])
	items = stored.duplicate(true) if stored is Array else []

func add_item(item_id: String, quantity: int = 1, metadata: Dictionary = {}) -> bool:
	if item_id.is_empty() or quantity <= 0:
		return false
	for entry in items:
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			entry["quantity"] = int(entry.get("quantity", 0)) + quantity
			_save_items()
			_refresh_page()
			return true
	items.append({"id": item_id, "quantity": quantity, "metadata": metadata.duplicate(true)})
	_save_items()
	_refresh_page()
	return true

func remove_item(item_id: String, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	for index in range(items.size()):
		var entry = items[index]
		if entry is Dictionary and str(entry.get("id", "")) == item_id:
			var remaining := int(entry.get("quantity", 0)) - quantity
			if remaining < 0:
				return false
			if remaining == 0:
				items.remove_at(index)
			else:
				entry["quantity"] = remaining
			_save_items()
			_refresh_page()
			return true
	return false

func get_page_count() -> int:
	return maxi(_unlocked_pages, maxi(1, ceili(float(items.size()) / float(SLOTS_PER_PAGE))))

func next_page() -> void:
	current_page = mini(current_page + 1, get_page_count() - 1)
	_refresh_page()

func previous_page() -> void:
	current_page = maxi(0, current_page - 1)
	_refresh_page()

func _build_interface() -> void:
	anchor_left = 0.18
	anchor_top = 0.12
	anchor_right = 0.82
	anchor_bottom = 0.88
	var frame := PanelContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

	var layout := VBoxContainer.new()
	frame.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "الحقيبة"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_page_label = Label.new()
	header.add_child(_page_label)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_grid)

	var footer := HBoxContainer.new()
	layout.add_child(footer)
	_previous_button = Button.new()
	_previous_button.text = "السابق"
	_previous_button.pressed.connect(previous_page)
	footer.add_child(_previous_button)
	var hint := Label.new()
	hint.text = "اسحب أو استخدم الأسهم للتنقل"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_child(hint)
	_next_button = Button.new()
	_next_button.text = "التالي +"
	_next_button.pressed.connect(_on_next_page)
	footer.add_child(_next_button)

	for slot_index in range(SLOTS_PER_PAGE):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(64, 54)
		var label := Label.new()
		label.name = "SlotLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(label)
		_grid.add_child(slot)

func _on_next_page() -> void:
	if current_page == get_page_count() - 1:
		# Creating the next page grants another empty bank of 30 slots.
		current_page += 1
		_unlocked_pages = maxi(_unlocked_pages, current_page + 1)
		GameState.profile["inventory_pages"] = _unlocked_pages
		GameState.save_local()
	_refresh_page()

func _refresh_page() -> void:
	if not is_instance_valid(_grid):
		return
	var page_count := get_page_count()
	_page_label.text = "صفحة %d / %d" % [current_page + 1, page_count]
	_previous_button.disabled = current_page <= 0
	_next_button.text = "التالي +" if current_page >= page_count - 1 else "التالي"
	for slot_index in range(SLOTS_PER_PAGE):
		var absolute_index := current_page * SLOTS_PER_PAGE + slot_index
		var slot := _grid.get_child(slot_index) as PanelContainer
		var label := slot.get_child(0) as Label
		if absolute_index < items.size():
			var entry = items[absolute_index]
			label.text = "%s\nx%d" % [str(entry.get("id", "Item")), int(entry.get("quantity", 1))]
		else:
			label.text = "فارغ"
	page_changed.emit(current_page, page_count)

func _save_items() -> void:
	GameState.profile["inventory"] = items.duplicate(true)
	GameState.profile["inventory_pages"] = _unlocked_pages
	GameState.inventory_changed.emit()
	GameState.save_local()

func _on_inventory_changed() -> void:
	_load_items()
	_refresh_page()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
		else:
			_handle_swipe(event.position)
	elif event is InputEventScreenDrag:
		if _touch_start == Vector2.ZERO:
			_touch_start = event.position

func _handle_swipe(end_position: Vector2) -> void:
	var delta_x := end_position.x - _touch_start.x
	if absf(delta_x) > 70.0:
		if delta_x < 0.0:
			_on_next_page()
		else:
			previous_page()
	_touch_start = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_on_next_page()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		previous_page()

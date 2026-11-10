extends Node3D
var player: CharacterBody3D
var enemy: CharacterBody3D
var status: Label
var inventory_manager: Control
func _ready() -> void:
  _setup_input()
  _build_arena()
  GameState.load_local()
  GameState.stats_changed.connect(_refresh)
  _refresh()
func _setup_input() -> void:
  var keys := {"move_left":KEY_A,"move_right":KEY_D,"move_forward":KEY_W,"move_back":KEY_S,"attack":KEY_SPACE,"save_game":KEY_F5,"inventory":KEY_I,"upgrade":KEY_U}
  for action in keys:
    if not InputMap.has_action(action): InputMap.add_action(action)
    var ev := InputEventKey.new()
    ev.physical_keycode = keys[action]
    InputMap.action_add_event(action,ev)
func _build_arena() -> void:
  var ground_body := StaticBody3D.new()
  var ground_mesh := MeshInstance3D.new()
  var plane := PlaneMesh.new()
  plane.size = Vector2(40,40)
  ground_mesh.mesh = plane
  var ground_mat := StandardMaterial3D.new()
  ground_mat.albedo_color = Color(0.12,0.18,0.16)
  ground_mesh.material_override = ground_mat
  ground_body.add_child(ground_mesh)
  var ground_shape := CollisionShape3D.new()
  var box := BoxShape3D.new()
  box.size = Vector3(40,0.2,40)
  ground_shape.shape = box
  ground_shape.position.y = -0.1
  ground_body.add_child(ground_shape)
  add_child(ground_body)
  var sun := DirectionalLight3D.new()
  sun.rotation_degrees = Vector3(-55,-25,0)
  sun.shadow_enabled = true
  add_child(sun)
  player = CharacterBody3D.new()
  player.name = "LocalPlayer"
  player.set_script(load("res://src/scripts/Player.gd"))
  player.position = Vector3(0,1,0)
  _add_capsule(player,Color(0.2,0.55,0.95),0.45,1.8)
  add_child(player)
  player.add_to_group("player")
  enemy = CharacterBody3D.new()
  enemy.name = "LocalMonster"
  enemy.set_script(load("res://src/scripts/Enemy.gd"))
  enemy.position = Vector3(4,0.8,-4)
  enemy.set("target", player)
  enemy.set("behavior", 0)
  _add_capsule(enemy,Color(0.8,0.2,0.18),0.6,1.3)
  enemy.connect("defeated", _on_defeated)
  add_child(enemy)
  var inventory_layer := CanvasLayer.new()
  inventory_layer.name = "InventoryLayer"
  add_child(inventory_layer)
  inventory_manager = Control.new()
  inventory_manager.name = "InventoryManager"
  inventory_manager.set_script(load("res://src/scripts/InventoryManager.gd"))
  inventory_manager.visible = false
  inventory_layer.add_child(inventory_manager)
  var camera_rig := load("res://src/scenes/IsometricCamera.tscn").instantiate()
  camera_rig.set("target_path", NodePath("../LocalPlayer"))
  add_child(camera_rig)
  var hud := load("res://src/scenes/HUD.tscn").instantiate()
  add_child(hud)
  var layer := CanvasLayer.new()
  add_child(layer)
  status = Label.new()
  status.position = Vector2(18,16)
  status.add_theme_font_size_override("font_size",20)
  layer.add_child(status)
  var hint := Label.new()
  hint.text = "WASD Move | SPACE Attack | F5 Save"
  hint.position = Vector2(18,48)
  layer.add_child(hint)
func _add_capsule(parent: Node3D, color: Color, radius: float, height: float) -> void:
  var mesh_node := MeshInstance3D.new()
  var mesh := CapsuleMesh.new()
  mesh.radius = radius
  mesh.height = height
  mesh_node.mesh = mesh
  var mat := StandardMaterial3D.new()
  mat.albedo_color = color
  mesh_node.material_override = mat
  parent.add_child(mesh_node)
  var collider := CollisionShape3D.new()
  var shape := CapsuleShape3D.new()
  shape.radius = radius
  shape.height = height
  collider.shape = shape
  parent.add_child(collider)
func _unhandled_input(event: InputEvent) -> void:
  if event.is_action_pressed("attack") and is_instance_valid(enemy):
    if player.global_position.distance_to(enemy.global_position) <= 3.0:
      enemy.call("take_damage", 20)
  if event.is_action_pressed("inventory"):
    var inventory_ui := get_tree().get_first_node_in_group("inventory_ui")
    if is_instance_valid(inventory_ui) and inventory_ui.has_method("toggle"):
      inventory_ui.toggle()
    get_viewport().set_input_as_handled()
  if event.is_action_pressed("upgrade"):
    var upgrade_ui := get_tree().get_first_node_in_group("upgrade_market_ui")
    if is_instance_valid(upgrade_ui) and upgrade_ui.has_method("toggle"):
      upgrade_ui.toggle()
    get_viewport().set_input_as_handled()
  if event.is_action_pressed("save_game"):
    GameState.profile.world_position = [player.position.x,player.position.y,player.position.z]
    GameState.save_local()
    _refresh()
func _on_defeated(gold: int, xp: int) -> void:
  # CPDrop.gd awards the gold on pickup; do not award it twice here.
  GameState.add_experience(xp)
  GameState.add_item("monster_material",1)
  GameState.update_quest("first_hunt","completed")
  _refresh()
func _refresh() -> void:
  if is_instance_valid(status):
    var p = GameState.profile
    status.text = "Lv.%s  HP %s/%s  MP %s/%s  Gold %s  XP %s" % [p.level,p.hp,p.max_hp,p.mp,p.max_mp,p.gold,p.experience]

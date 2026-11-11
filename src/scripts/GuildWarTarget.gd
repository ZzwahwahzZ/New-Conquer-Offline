extends StaticBody3D
var target_id := "left_gate"
var display_name := "Left Gate"
var max_hp := 10000
var hp := 10000
var manager: Node

func configure(id: String, label: String, health: int, owner: Node) -> void:
	target_id = id
	display_name = label
	max_hp = health
	hp = health
	manager = owner
	add_to_group("enemies")
	_build_visual()

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.6,4.2,0.8) if target_id != "guild_pole" else Vector3(2.2,5.5,2.2)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.42,0.31,0.2) if target_id != "guild_pole" else Color(0.78,0.57,0.2)
	material.metallic = 0.35
	material.roughness = 0.55
	mesh_instance.material_override = material
	mesh_instance.position.y = mesh.size.y * 0.5
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	collision.shape = shape
	collision.position.y = mesh.size.y * 0.5
	add_child(collision)
	var label := Label3D.new()
	label.text = display_name
	label.position.y = mesh.size.y + 0.55
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	add_child(label)

func take_damage(amount: int) -> void:
	if amount <= 0 or hp <= 0: return
	if target_id == "guild_pole" and is_instance_valid(manager) and not bool(manager.get("gates_destroyed")): return
	hp = maxi(0,hp-amount)
	if is_instance_valid(manager):
		manager.call("register_target_damage",target_id,amount)
		manager.call("update_target_health",target_id,hp,max_hp)
	if hp <= 0:
		remove_from_group("enemies")
		if is_instance_valid(manager): manager.call("target_destroyed",target_id)

extends Area3D
signal interacted(npc_id:String,role:String)
@export var npc_id="NPC"
@export var display_name="Merchant"
@export var role="blacksmith"
var near_player=false
func _ready() -> void:
 add_to_group("npcs"); body_entered.connect(_on_enter); body_exited.connect(_on_exit)
 var visual=MeshInstance3D.new(); var mesh=CapsuleMesh.new(); mesh.radius=.38; mesh.height=1.6; visual.mesh=mesh; visual.position.y=.8
 var mat=StandardMaterial3D.new(); mat.albedo_color=Color(.72,.58,.34); visual.material_override=mat; add_child(visual)
 var label=Label3D.new(); label.text=display_name; label.position.y=1.9; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; add_child(label)
 var collision=CollisionShape3D.new(); var sphere=SphereShape3D.new(); sphere.radius=2.5; collision.shape=sphere; add_child(collision)
func _on_enter(body:Node3D) -> void:
 if body.is_in_group("player"): near_player=true
func _on_exit(body:Node3D) -> void:
 if body.is_in_group("player"): near_player=false
func interact() -> void:
 if near_player: interacted.emit(npc_id,role)
func _unhandled_input(event:InputEvent) -> void:
 if near_player and event.is_action_pressed("ui_accept"): interact(); get_viewport().set_input_as_handled()

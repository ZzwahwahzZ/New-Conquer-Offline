extends Area3D
const RiggedCharacterFactory = preload("res://src/scripts/RiggedCharacterFactory.gd")
signal interacted(npc_id:String,role:String)
@export var npc_id="NPC"
@export var display_name="Merchant"
@export var role="blacksmith"
var near_player=false
func _ready() -> void:
 add_to_group("npcs"); body_entered.connect(_on_enter); body_exited.connect(_on_exit)
 var visual_root=Node3D.new(); visual_root.name="NPCVisualRoot"; add_child(visual_root)
 var rig=RiggedCharacterFactory.attach_to(visual_root,"npc",abs(role.hash()) % 8,0.92)
 if rig != null:
  RiggedCharacterFactory.set_tint(rig,Color(.72,.58,.34))
  RiggedCharacterFactory.play_state(rig,"Idle")
 else:
  push_error("NPC: missing rigged CC0 actor for role " + role)
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

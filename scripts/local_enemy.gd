extends CharacterBody3D
signal defeated(gold: int, xp: int)
@export var max_hp := 40
@export var attack_damage := 5
var hp := 40
var target: Node3D
var cooldown := 0.0
func _ready() -> void: hp = max_hp
func take_damage(amount: int) -> void:
  hp = maxi(0,hp-maxi(0,amount))
  if hp == 0:
    defeated.emit(5,20)
    queue_free()
func _physics_process(delta: float) -> void:
  if not is_instance_valid(target): return
  var offset := target.global_position-global_position
  offset.y = 0.0
  if offset.length() > 1.6:
    var d := offset.normalized()
    velocity.x = d.x*2.0
    velocity.z = d.z*2.0
    move_and_slide()
  else:
    velocity.x = 0.0
    velocity.z = 0.0
    cooldown -= delta
    if cooldown <= 0.0:
      cooldown = 1.5
      GameState.damage_player(attack_damage)

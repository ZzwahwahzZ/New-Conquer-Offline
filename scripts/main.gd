extends Node3D

## Entry point for New Conquer Offline.
## World systems, player control, and gameplay scenes will be added in separate modules.

@onready var world_root: Node3D = $WorldRoot


func _ready() -> void:
	print("New Conquer Offline — Godot project initialized.")
	print("World root ready: ", world_root.name)

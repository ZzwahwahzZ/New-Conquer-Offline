extends Node
## Local-only fast travel controller.
var world_manager: Node

func configure(manager: Node) -> void:
	world_manager = manager

func travel_to(settlement_id: String) -> bool:
	if not is_instance_valid(world_manager) or not world_manager.has_method("change_settlement"):
		return false
	if not world_manager.call("get_settlement_ids").has(settlement_id):
		return false
	world_manager.call("change_settlement",settlement_id)
	return true

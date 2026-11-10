extends SceneTree
func _initialize() -> void:
  call_deferred("_run")
func _run() -> void:
  var state = load("res://scripts/game_state.gd").new()
  root.add_child(state)
  state.add_gold(25)
  state.add_experience(100)
  state.add_item("test_drop",2)
  state.update_quest("smoke","completed")
  assert(state.profile.gold == 125)
  assert(state.profile.level == 2)
  assert(state.profile.inventory.size() == 1)
  assert(state.profile.quests.smoke == "completed")
  assert(state.save_local())
  state.profile.gold = 0
  assert(state.load_local())
  assert(state.profile.gold == 125)
  print("OFFLINE_SMOKE_TEST_PASS")
  quit(0)

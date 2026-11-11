extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
 var failures=[]
 for p in ["res://src/scripts/NPCSystem.gd","res://src/scripts/QuestSystem.gd","res://src/scripts/QuestUI.gd","res://src/scripts/ShopUI.gd","res://src/scripts/ShoppingMallUI.gd","res://src/scripts/WarehouseUI.gd","res://src/scenes/NPC.tscn","res://src/scenes/QuestUI.tscn","res://src/scenes/ShopUI.tscn","res://src/scenes/ShoppingMallUI.tscn","res://src/scenes/WarehouseUI.tscn"]:
  if not ResourceLoader.exists(p): failures.append("Missing "+p)
 var cfg=FileAccess.get_file_as_string("res://project.godot"); var a=cfg.split("[autoload]")[1].split("[")[0]
 if a.contains("QuestSystem=") or a.contains("NPCSystem="): failures.append("Autoload changed")
 if not a.contains("GlobalEconomy=") or not a.contains("GameState="): failures.append("Existing Autoload missing")
 print("STEP12_SMOKE_TEST: "+("PASS" if failures.is_empty() else "FAIL"))
 for e in failures: push_error(e)
 quit(0 if failures.is_empty() else 1)

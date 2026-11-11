extends SceneTree
## Step 16 terrain, collision, city architecture and Autoload regression test.
func _initialize() -> void:
 call_deferred("_run")
func _run() -> void:
 var cities := ["TwinCity","DesertLand","VolcanoLand","IceLand","Waterlands","DarkForest"]
 for city in cities:
  var path := "res://src/scenes/world/%s.tscn" % city
  var packed := load(path) as PackedScene
  assert(packed != null,"Missing city scene: "+city)
  var scene := packed.instantiate() as Node3D
  root.add_child(scene)
  await process_frame
  assert(scene.get_node_or_null("TerrainCollision") is StaticBody3D,"Terrain collision missing: "+city)
  assert(scene.get_node_or_null("ArchitectureAssetSlot/ChineseImperialArchitecture") != null,"Chinese architecture missing: "+city)
  assert(scene.get_node_or_null("WorldBoundary_0") is StaticBody3D,"Safety bounds missing: "+city)
  assert(scene.get_node_or_null("SanctuaryAnchors/RareSanctuaryNorthEast") != null)
  scene.queue_free()
  await process_frame
 var source := FileAccess.get_file_as_string("res://project.godot")
 var order := ["ClassSystem=","GearDatabase=","GearSystem=","GlobalEconomy=","GameState="]
 var previous := -1
 for key in order:
  var at := source.find(key)
  assert(at>previous,"Autoload order changed at "+key)
  previous=at
 assert(source.contains('renderer/rendering_method="mobile"'))
 assert(load("res://src/scripts/ChineseImperialBuilder.gd") != null)
 assert(load("res://src/scripts/WorldTerrainBuilder.gd") != null)
 assert(load("res://src/scripts/ConquerRoyalTheme.gd") != null)
 print("STEP16_SIX_CITIES_TERRAIN_COLLISION_CHINESE_ARCHITECTURE_AUTOLOAD_PASS")
 quit(0)

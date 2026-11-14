extends SceneTree

const SOURCE_PATH := "res://assets/environment/architecture/imperial_china_palace_and_garden.glb"
const OUTPUT_PATH := "res://assets/environment/architecture/imperial_china_palace_and_garden_merged.scn"

func _initialize() -> void:
	call_deferred("_build_source_scene")

func _build_source_scene() -> void:
	var source := load(SOURCE_PATH) as PackedScene
	if source == null:
		push_error("TWIN_CITY_ASSET_BUILD_FAIL: original Imperial China GLB could not be loaded")
		quit(1)
		return
	var kit := source.instantiate() as Node3D
	if kit == null:
		push_error("TWIN_CITY_ASSET_BUILD_FAIL: original Imperial China GLB did not instantiate as Node3D")
		quit(1)
		return
	kit.name = "ImperialChina_OriginalGLB_SourceScene"
	var packed := PackedScene.new()
	var pack_error := packed.pack(kit)
	if pack_error != OK:
		push_error("TWIN_CITY_ASSET_BUILD_FAIL: PackedScene.pack returned %s" % pack_error)
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		push_error("TWIN_CITY_ASSET_BUILD_FAIL: ResourceSaver.save returned %s" % save_error)
		quit(1)
		return
	print("TWIN_CITY_ASSET_BUILD_PASS: original GLB source scene copied without procedural modifications; bytes=%d" % FileAccess.get_file_as_bytes(OUTPUT_PATH).size())
	kit.free()
	quit(0)

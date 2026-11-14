extends SceneTree

const CityArchitectureBuilder = preload("res://src/scripts/CityArchitectureBuilder.gd")
const OUTPUT_PATH := "res://assets/environment/architecture/imperial_china_palace_and_garden_merged.scn"

func _initialize() -> void:
	call_deferred("_build_merged_kit")

func _build_merged_kit() -> void:
	var holder := Node3D.new()
	holder.name = "ImperialKitBuildRoot"
	root.add_child(holder)
	if not CityArchitectureBuilder._twin_import_imperial_palace_kit(holder):
		push_error("TWIN_CITY_ASSET_BUILD_FAIL: source kit could not be merged")
		quit(1)
		return
	var kit := holder.get_node_or_null("TwinCity_ImperialChina_GLBKit") as Node3D
	if kit == null:
		push_error("TWIN_CITY_ASSET_BUILD_FAIL: merged kit node missing")
		quit(1)
		return
	holder.remove_child(kit)
	kit.position = Vector3.ZERO
	var packed := PackedScene.new()
	var pack_error := packed.pack(kit)
	if pack_error != OK:
		push_error("TWIN_CITY_ASSET_BUILD_FAIL: PackedScene.pack returned %s" % pack_error)
		quit(1)
		return
	var save_error := ResourceSaver.save(packed,OUTPUT_PATH)
	if save_error != OK:
		push_error("TWIN_CITY_ASSET_BUILD_FAIL: ResourceSaver.save returned %s" % save_error)
		quit(1)
		return
	var absolute := ProjectSettings.globalize_path(OUTPUT_PATH)
	print("TWIN_CITY_ASSET_BUILD_PASS: %s bytes=%d" % [OUTPUT_PATH,FileAccess.get_file_as_bytes(OUTPUT_PATH).size()])
	quit(0)

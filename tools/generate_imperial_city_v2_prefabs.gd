extends SceneTree
const SOURCE_ROOT := "res://assets/imperial_city_kit_v2/quaternius"
const PREFAB_ROOT := "res://assets/prefabs/city"
var generated := 0
var failed := 0
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PREFAB_ROOT))
	_scan(SOURCE_ROOT)
	print("IMPERIAL_CITY_V2_PREFAB_RESULT: generated=%d failed=%d" % [generated, failed])
	quit(0 if generated > 0 and failed == 0 else 1)
func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var child := path.path_join(entry)
		if dir.current_is_dir():
			_scan(child)
		elif entry.get_extension().to_lower() == "glb":
			_create_prefab(child)
		entry = dir.get_next()
	dir.list_dir_end()
func _create_prefab(glb_path: String) -> void:
	if not ResourceLoader.exists(glb_path):
		push_error("IMPERIAL_V2_GLB_NOT_IMPORTED: " + glb_path)
		failed += 1
		return
	var packed := ResourceLoader.load(glb_path) as PackedScene
	if packed == null:
		push_error("IMPERIAL_V2_GLB_NOT_PACKED_SCENE: " + glb_path)
		failed += 1
		return
	var safe_name := glb_path.get_file().get_basename().validate_filename()
	var prefab_path := PREFAB_ROOT.path_join(safe_name + ".tscn")
	var text := "[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"PackedScene\" path=\"" + glb_path + "\" id=\"1\"]\n\n[node name=\"" + safe_name + "\" instance=ExtResource(\"1\")]\n"
	var file := FileAccess.open(prefab_path, FileAccess.WRITE)
	if file == null:
		push_error("IMPERIAL_V2_PREFAB_WRITE_FAIL: " + prefab_path)
		failed += 1
		return
	file.store_string(text)
	file.close()
	if not ResourceLoader.exists(prefab_path) or ResourceLoader.load(prefab_path) == null:
		push_error("IMPERIAL_V2_PREFAB_RESOURCELOADER_FAIL: " + prefab_path)
		failed += 1
		return
	generated += 1
	print("IMPERIAL_V2_PREFAB_PASS: " + prefab_path)

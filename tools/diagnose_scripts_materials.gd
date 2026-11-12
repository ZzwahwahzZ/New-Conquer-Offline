extends SceneTree

var script_ok := 0
var script_fail := 0
var material_ok := 0
var material_fail := 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    _scan("res://", true)
    print("DIRECT_DIAGNOSTIC_SCRIPTS: pass=%d fail=%d" % [script_ok, script_fail])
    print("DIRECT_DIAGNOSTIC_MATERIALS: pass=%d fail=%d" % [material_ok, material_fail])
    for item in failures:
        push_error("DIRECT_DIAGNOSTIC_FAILURE: " + item)
    if script_fail > 0 or material_fail > 0:
        print("DIRECT_SCRIPT_MATERIAL_DIAGNOSTIC_FAIL")
        quit(1)
        return
    print("DIRECT_SCRIPT_MATERIAL_DIAGNOSTIC_PASS")
    quit(0)

func _scan(path: String, recurse: bool) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var name := dir.get_next()
    while name != "":
        if name.begins_with(".") or name == "addons":
            name = dir.get_next()
            continue
        var full := path.path_join(name)
        if dir.current_is_dir():
            if recurse:
                _scan(full, true)
        else:
            if name.ends_with(".gd"):
                _check_script(full)
            elif name.ends_with(".tres") or name.ends_with(".res") or name.ends_with(".gdshader"):
                _check_material_resource(full)
        name = dir.get_next()
    dir.list_dir_end()

func _check_script(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        script_fail += 1
        failures.append(path + " (cannot read; open_error=%d)" % FileAccess.get_open_error())
        return
    var source := file.get_as_text()
    file.close()
    var parsed := GDScript.new()
    parsed.source_code = source
    var error := parsed.reload()
    if error == OK:
        script_ok += 1
    else:
        script_fail += 1
        failures.append(path + " (GDScript.reload error=%d)" % error)

func _check_material_resource(path: String) -> void:
    var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
    if resource == null:
        material_fail += 1
        failures.append(path + " (ResourceLoader.load returned null)")
    else:
        material_ok += 1

extends Node

var script_ok: int = 0
var script_fail: int = 0
var material_ok: int = 0
var material_fail: int = 0
var failures: Array[String] = []

func _ready() -> void:
    call_deferred("_run")

func _run() -> void:
    var log_path: String = "res://reports/godot_import_guard.log"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
    var previous_log: String = FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(log_path) else ""
    var required_autoloads: Array[String] = [
        "ClassSystem", "GearDatabase", "GearSystem", "GlobalEconomy", "GameState"
    ]
    var missing_autoloads: Array[String] = []
    for singleton_name in required_autoloads:
        if get_node_or_null("/root/" + singleton_name) == null:
            missing_autoloads.append(singleton_name)

    if not missing_autoloads.is_empty():
        failures.append("Autoloads not initialized in project scene: " + ", ".join(missing_autoloads))
    else:
        _scan("res://")

    var summary: String = "POST_IMPORT_DIAGNOSTIC: scripts_pass=%d scripts_fail=%d materials_pass=%d materials_fail=%d" % [script_ok, script_fail, material_ok, material_fail]
    var output := previous_log + "\n=== POST-IMPORT SCENE NODE DIAGNOSTIC ===\n"
    for failure in failures:
        output += "DIAGNOSTIC_FAILURE: " + failure + "\n"
    output += summary + "\n"
    output += "DIRECT_SCRIPT_MATERIAL_DIAGNOSTIC_" + ("FAIL" if script_fail > 0 or material_fail > 0 or not failures.is_empty() else "PASS") + "\n"
    var report: FileAccess = FileAccess.open(log_path, FileAccess.WRITE)
    if report == null:
        push_error("Cannot create reports/godot_import_guard.log")
        get_tree().quit(2)
        return
    report.store_string(output)
    report.flush()
    report.close()
    print(summary)
    for failure in failures:
        push_error("DIAGNOSTIC_FAILURE: " + failure)
    get_tree().quit(1 if script_fail > 0 or material_fail > 0 or not failures.is_empty() else 0)

func _scan(path: String) -> void:
    var dir: DirAccess = DirAccess.open(path)
    if dir == null:
        failures.append(path + " (cannot open directory)")
        return
    dir.list_dir_begin()
    var entry: String = dir.get_next()
    while entry != "":
        if entry.begins_with(".") or entry == "addons":
            entry = dir.get_next()
            continue
        var full_path: String = path.path_join(entry)
        if dir.current_is_dir():
            _scan(full_path)
        elif entry.ends_with(".gd"):
            _check_script(full_path)
        elif entry.ends_with(".tres"):
            _check_text_resource_dependencies(full_path)
        elif entry.ends_with(".res") or entry.ends_with(".gdshader"):
            _check_resource(full_path)
        entry = dir.get_next()
    dir.list_dir_end()

func _check_script(path: String) -> void:
    if not ResourceLoader.exists(path):
        script_fail += 1
        failures.append(path + " (ResourceLoader.exists=false)")
        return
    var parsed: GDScript = ResourceLoader.load(path, "GDScript") as GDScript
    if parsed != null:
        script_ok += 1
    else:
        script_fail += 1
        failures.append(path + " (GDScript compile/load returned null)")

func _check_text_resource_dependencies(path: String) -> void:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        material_fail += 1
        failures.append(path + " (cannot read text resource)")
        return
    var source: String = file.get_as_text()
    file.close()
    var regex := RegEx.new()
    if regex.compile('path\\s*=\\s*"res://([^"]+)"') != OK:
        material_fail += 1
        failures.append(path + " (dependency pattern failed)")
        return
    var missing: Array[String] = []
    for match_result in regex.search_all(source):
        var dependency: String = "res://" + match_result.get_string(1)
        if not ResourceLoader.exists(dependency):
            missing.append(dependency)
    if missing.is_empty():
        material_ok += 1
    else:
        material_fail += 1
        failures.append(path + " (missing dependencies: " + ", ".join(missing) + ")")

func _check_resource(path: String) -> void:
    if not ResourceLoader.exists(path):
        material_fail += 1
        failures.append(path + " (ResourceLoader.exists=false)")
        return
    var resource: Resource = ResourceLoader.load(path)
    if resource == null:
        material_fail += 1
        failures.append(path + " (ResourceLoader.load returned null)")
    else:
        material_ok += 1

extends SceneTree

var script_ok: int = 0
var script_fail: int = 0
var material_ok: int = 0
var material_fail: int = 0
var failures: Array[String] = []
var report: FileAccess

class DiagnosticNode extends Node:
    var owner_tree: SceneTree

    func _ready() -> void:
        owner_tree.call_deferred("_scan_project")

func _initialize() -> void:
    call_deferred("_start_node_diagnostic")

func _start_node_diagnostic() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
    report = FileAccess.open("res://reports/godot_import_guard.log", FileAccess.READ_WRITE)
    if report == null:
        push_error("Cannot create reports/godot_import_guard.log")
        quit(2)
        return
    report.seek_end()
    report.store_line("\n=== POST-IMPORT NODE DIAGNOSTIC ===")
    var required_autoloads: Array[String] = [
        "ClassSystem", "GearDatabase", "GearSystem", "GlobalEconomy", "GameState"
    ]
    var missing_autoloads: Array[String] = []
    for singleton_name in required_autoloads:
        if get_root().get_node_or_null(NodePath(singleton_name)) == null:
            missing_autoloads.append(singleton_name)
    if not missing_autoloads.is_empty():
        _record_failure("Autoloads not initialized in required order/context: " + ", ".join(missing_autoloads))
        _finish()
        return

    var diagnostic_node := DiagnosticNode.new()
    diagnostic_node.name = "PostImportResourceDiagnostic"
    diagnostic_node.owner_tree = self
    get_root().add_child(diagnostic_node)
    
func _scan_project() -> void:
    _scan("res://")
    _finish()

func _scan(path: String) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        _record_failure(path + " (cannot open directory)")
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
        _record_failure(path + " (ResourceLoader.exists=false)")
        return
    var parsed: GDScript = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
    if parsed != null:
        script_ok += 1
    else:
        script_fail += 1
        _record_failure(path + " (GDScript compile/load returned null)")

func _check_text_resource_dependencies(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        material_fail += 1
        _record_failure(path + " (cannot read text resource)")
        return
    var source: String = file.get_as_text()
    file.close()
    var regex := RegEx.new()
    if regex.compile('path\\s*=\\s*"res://([^"]+)"') != OK:
        material_fail += 1
        _record_failure(path + " (dependency pattern failed)")
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
        _record_failure(path + " (missing dependencies: " + ", ".join(missing) + ")")

func _check_resource(path: String) -> void:
    if not ResourceLoader.exists(path):
        material_fail += 1
        _record_failure(path + " (ResourceLoader.exists=false)")
        return
    var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
    if resource == null:
        material_fail += 1
        _record_failure(path + " (ResourceLoader.load returned null)")
    else:
        material_ok += 1

func _record_failure(message: String) -> void:
    failures.append(message)
    if report != null:
        report.store_line("DIAGNOSTIC_FAILURE: " + message)
    push_error("DIAGNOSTIC_FAILURE: " + message)

func _finish() -> void:
    var summary := "DIRECT_DIAGNOSTIC_SCRIPTS: pass=%d fail=%d | MATERIALS: pass=%d fail=%d" % [script_ok, script_fail, material_ok, material_fail]
    print(summary)
    if report != null:
        report.store_line(summary)
        report.store_line("DIRECT_SCRIPT_MATERIAL_DIAGNOSTIC_" + ("FAIL" if script_fail > 0 or material_fail > 0 else "PASS"))
        report.flush()
        report.close()
    quit(1 if script_fail > 0 or material_fail > 0 else 0)

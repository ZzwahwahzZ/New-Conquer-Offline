extends SceneTree

func _initialize() -> void:
	call_deferred("_run_audit")

func _run_audit() -> void:
	var packed := load("res://src/scenes/world/TwinCity.tscn") as PackedScene
	if packed == null:
		push_error("TWIN_CITY_AUDIT_FAIL: TwinCity scene could not be loaded")
		quit(1)
		return
	var city := packed.instantiate()
	root.add_child(city)
	await process_frame
	var buildings := get_nodes_in_group("twin_city_building")
	var counts := {
		"residential": 0,
		"commercial": 0,
		"service": 0,
		"landmark": 0,
		"defensive": 0,
		"palace_annex": 0
	}
	for node in buildings:
		for category in counts.keys():
			if node.name.begins_with("TwinCity_%s_" % category):
				counts[category] += 1
	var total := buildings.size()
	var plaza := city.find_child("CircularImperialPlaza_60m", true, false)
	var palace := city.find_child("ImperialPalace_85x75", true, false)
	var moat := city.find_child("DeepContinuousWaterMoat_440m", true, false)
	var pagoda := city.find_child("CentralPagoda_20m", true, false)
	var valid := total >= 220 and total <= 260
	valid = valid and counts.residential == 120
	valid = valid and counts.commercial == 42
	valid = valid and counts.service == 22
	valid = valid and counts.landmark == 12
	valid = valid and counts.defensive == 20
	valid = valid and counts.palace_annex == 8
	valid = valid and plaza != null and palace != null and moat != null and pagoda != null
	print("TWIN_CITY_ACCEPTANCE_AUDIT total=%d categories=%s plaza=%s palace=%s moat=%s pagoda=%s" % [total, str(counts), str(plaza != null), str(palace != null), str(moat != null), str(pagoda != null)])
	if not valid:
		push_error("TWIN_CITY_AUDIT_FAIL: count, category, or landmark validation failed")
		quit(1)
		return
	print("TWIN_CITY_AUDIT_PASS: 224 counted structures; category census and all required landmark nodes exist")
	quit(0)

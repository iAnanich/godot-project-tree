extends RefCounted

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const VALIDATOR_PATH: String = ADDON_ROOT + "core/snapshot_validator.gd"
const SCANNER_PATH: String = ADDON_ROOT + "core/project_scanner.gd"
const EXPORT_SERVICE_PATH: String = ADDON_ROOT + "export/export_service.gd"
const DOCK_SCENE_PATH: String = ADDON_ROOT + "ui/dependency_dock.tscn"
const EXPORTER_CONTRACT_PATH: String = "res://tests/contracts/exporter_contract.gd"
const MISSING_CAPABILITY_EXPORTER_PATH: String = "res://tests/contract_fixtures/exporters/missing_capability_exporter.gd"
const UPPERCASE_EXPORTER_PATH: String = "res://tests/contract_fixtures/exporters/uppercase_exporter.gd"
const EMPTY_OUTPUT_EXPORTER_PATH: String = "res://tests/contract_fixtures/exporters/empty_output_exporter.gd"


## Runs quality-boundary, extension-contract, and non-visual-access tests.
func run(valid_snapshot: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	_test_snapshot_validation(valid_snapshot, failures)
	_test_exporter_contracts(valid_snapshot, failures)
	_test_scan_root_boundary(failures)
	_test_visual_decoding_summary(valid_snapshot, failures)
	return failures


func _test_snapshot_validation(valid_snapshot: Dictionary, failures: Array[String]) -> void:
	var validator = _new_script_instance(VALIDATOR_PATH, failures)
	if validator == null:
		return
	var valid_result: Dictionary = validator.validate(valid_snapshot)
	_check(valid_result.get("ok", false), "Snapshot validator rejected a valid canonical snapshot.", failures)

	var typed_schema_snapshot: Dictionary = valid_snapshot.duplicate(true)
	typed_schema_snapshot["schema_version"] = "1"
	var typed_schema_result: Dictionary = validator.validate(typed_schema_snapshot)
	_check(
		not typed_schema_result.get("ok", true)
		and _has_issue_code(
			typed_schema_result.get("errors", []), "invalid_schema_version_type"
		),
		"Snapshot validator must reject a string schema version instead of coercing it.",
		failures
	)

	var missing_node_field_snapshot: Dictionary = valid_snapshot.duplicate(true)
	missing_node_field_snapshot["nodes"][0].erase("methods")
	var missing_node_field_result: Dictionary = validator.validate(missing_node_field_snapshot)
	_check(
		not missing_node_field_result.get("ok", true)
		and _has_issue_code(missing_node_field_result.get("errors", []), "missing_node_field"),
		"Snapshot validator must enforce the schema-required node collections.",
		failures
	)

	var invalid_node_id_snapshot: Dictionary = valid_snapshot.duplicate(true)
	invalid_node_id_snapshot["nodes"][0]["id"] = 123
	var invalid_node_id_result: Dictionary = validator.validate(invalid_node_id_snapshot)
	_check(
		not invalid_node_id_result.get("ok", true)
		and _has_issue_code(invalid_node_id_result.get("errors", []), "invalid_node_field"),
		"Snapshot validator must reject non-string node IDs instead of coercing them.",
		failures
	)

	var missing_edge_field_snapshot: Dictionary = valid_snapshot.duplicate(true)
	missing_edge_field_snapshot["edges"][0].erase("member_links")
	var missing_edge_field_result: Dictionary = validator.validate(missing_edge_field_snapshot)
	_check(
		not missing_edge_field_result.get("ok", true)
		and _has_issue_code(missing_edge_field_result.get("errors", []), "missing_edge_field"),
		"Snapshot validator must enforce the schema-required edge member_links collection.",
		failures
	)

	var invalid_edge_endpoint_snapshot: Dictionary = valid_snapshot.duplicate(true)
	invalid_edge_endpoint_snapshot["edges"][0]["source"] = 123
	var invalid_edge_endpoint_result: Dictionary = validator.validate(invalid_edge_endpoint_snapshot)
	_check(
		not invalid_edge_endpoint_result.get("ok", true)
		and _has_issue_code(invalid_edge_endpoint_result.get("errors", []), "invalid_edge_field"),
		"Snapshot validator must reject non-string edge endpoints instead of coercing them.",
		failures
	)

	var invalid_message_snapshot: Dictionary = valid_snapshot.duplicate(true)
	invalid_message_snapshot["warnings"] = [42]
	var invalid_message_result: Dictionary = validator.validate(invalid_message_snapshot)
	_check(
		not invalid_message_result.get("ok", true)
		and _has_issue_code(invalid_message_result.get("errors", []), "invalid_snapshot_message"),
		"Snapshot validator must reject non-string warning and error entries.",
		failures
	)

	var duplicate_snapshot: Dictionary = valid_snapshot.duplicate(true)
	duplicate_snapshot["nodes"].append(duplicate_snapshot["nodes"][0].duplicate(true))
	var duplicate_result: Dictionary = validator.validate(duplicate_snapshot)
	_check(
		not duplicate_result.get("ok", true)
		and _has_issue_code(duplicate_result.get("errors", []), "duplicate_node_id"),
		"Snapshot validator must reject duplicate node IDs with a stable code.",
		failures
	)

	var dangling_snapshot: Dictionary = valid_snapshot.duplicate(true)
	dangling_snapshot["edges"].append(
		{"source": str(valid_snapshot["nodes"][0]["id"]), "target": "missing://node", "kind": "uses", "member_links": []}
	)
	var dangling_result: Dictionary = validator.validate(dangling_snapshot)
	_check(
		not dangling_result.get("ok", true)
		and _has_issue_code(dangling_result.get("errors", []), "dangling_edge_target"),
		"Snapshot validator must reject dangling edge targets with a stable code.",
		failures
	)

	var unknown_member_snapshot: Dictionary = valid_snapshot.duplicate(true)
	var member_edge: Dictionary = unknown_member_snapshot["edges"][0]
	member_edge["member_links"] = [
		{
			"source_member": {"kind": "method", "name": "does_not_exist"},
			"target_member": {},
			"evidence": "test_fixture",
		}
	]
	var unknown_member_result: Dictionary = validator.validate(unknown_member_snapshot)
	_check(
		not unknown_member_result.get("ok", true)
		and _has_issue_code(unknown_member_result.get("errors", []), "unknown_member_reference"),
		"Snapshot validator must reject member provenance that contradicts its endpoint node.",
		failures
	)

	var invalid_diagnostic_snapshot: Dictionary = valid_snapshot.duplicate(true)
	invalid_diagnostic_snapshot["diagnostics"] = [
		{"severity": "critical", "code": "bad", "message": "invalid", "context": {}}
	]
	var invalid_diagnostic_result: Dictionary = validator.validate(invalid_diagnostic_snapshot)
	_check(
		not invalid_diagnostic_result.get("ok", true)
		and _has_issue_code(
			invalid_diagnostic_result.get("errors", []), "invalid_diagnostic_severity"
		),
		"Snapshot validator must reject unsupported diagnostic severities.",
		failures
	)

	var export_service = _new_script_instance(EXPORT_SERVICE_PATH, failures)
	if export_service != null:
		var export_result: Dictionary = export_service.export_to_string("json", dangling_snapshot)
		_check(
			not export_result.get("ok", true) and export_result.get("code", "") == "invalid_snapshot",
			"Export service must reject invalid snapshots before serialization.",
			failures
		)


func _test_exporter_contracts(valid_snapshot: Dictionary, failures: Array[String]) -> void:
	var service = _new_script_instance(EXPORT_SERVICE_PATH, failures)
	var contract = _new_script_instance(EXPORTER_CONTRACT_PATH, failures)
	if service == null or contract == null:
		return
	var descriptors: Array = service.format_descriptors()
	_check(descriptors.size() == 3, "Built-in exporter descriptor count changed unexpectedly.", failures)
	for descriptor_value in descriptors:
		var descriptor: Dictionary = descriptor_value
		var capabilities_value = descriptor.get("capabilities", {})
		_check(capabilities_value is Dictionary, "Exporter descriptors must expose capabilities.", failures)
		var format_id: String = str(descriptor.get("id", ""))
		var exporter_path: String = ADDON_ROOT + "export/%s_exporter.gd" % format_id
		var exporter = _new_script_instance(exporter_path, failures)
		if exporter == null:
			continue
		for message_value in contract.validate(exporter, valid_snapshot):
			failures.append("%s exporter contract: %s" % [format_id, message_value])
	_check(
		bool(service.capabilities_for("plantuml").get("exact_member_endpoints", false)),
		"PlantUML must declare exact member endpoint support.",
		failures
	)
	_check(
		not bool(service.capabilities_for("mermaid").get("exact_member_endpoints", true)),
		"Mermaid must not claim unsupported exact member endpoints.",
		failures
	)

	var missing_capability = _new_script_instance(MISSING_CAPABILITY_EXPORTER_PATH, failures)
	var uppercase_exporter = _new_script_instance(UPPERCASE_EXPORTER_PATH, failures)
	var empty_exporter = _new_script_instance(EMPTY_OUTPUT_EXPORTER_PATH, failures)
	if missing_capability != null:
		_check(
			not service.register_exporter(missing_capability),
			"Exporter registration must reject incomplete capability declarations.",
			failures
		)
	if uppercase_exporter != null:
		_check(
			not service.register_exporter(uppercase_exporter),
			"Exporter registration must reject noncanonical format IDs.",
			failures
		)
	if empty_exporter != null:
		_check(
			service.register_exporter(empty_exporter),
			"A structurally valid exporter fixture should register.",
			failures
		)
		var empty_result: Dictionary = service.export_to_string("empty", valid_snapshot)
		_check(
			not empty_result.get("ok", true)
			and empty_result.get("code", "") == "empty_export_output",
			"Export service must diagnose an exporter that produces empty output.",
			failures
		)


func _test_scan_root_boundary(failures: Array[String]) -> void:
	var scanner = _new_script_instance(SCANNER_PATH, failures)
	if scanner == null:
		return
	for invalid_root in ["/tmp", "user://", "res://../outside"]:
		var result: Dictionary = scanner.scan(invalid_root, {"use_runtime_reflection": false})
		_check(
			not result.get("errors", []).is_empty()
			and _has_issue_code(result.get("diagnostics", []), "invalid_scan_root"),
			"Scanner must reject paths outside res:// with a structured diagnostic: %s" % invalid_root,
			failures
		)


func _test_visual_decoding_summary(valid_snapshot: Dictionary, failures: Array[String]) -> void:
	var scene_resource: Resource = ResourceLoader.load(DOCK_SCENE_PATH)
	if scene_resource == null or not scene_resource is PackedScene:
		failures.append("Quality suite could not load the dependency dock scene.")
		return
	var dock: Control = (scene_resource as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(dock)
	dock.set("_snapshot", valid_snapshot.duplicate(true))
	dock.call("_render_snapshot")
	var legend: RichTextLabel = dock.get_node("LegendPanel/LegendView")
	var summary: RichTextLabel = dock.get_node("MainSplit/ControlsTabs/Summary/SummaryView")
	_check(
		legend.text.contains("Inheritance")
		and legend.text.contains("load/preload or class-member use")
		and legend.text.contains("Type-annotation use")
		and legend.text.contains("Rendered direction"),
		"The initial graph view must visibly decode edge colors and direction.",
		failures
	)
	_check(
		summary.text.contains("Dependency graph summary")
		and summary.text.contains("Canonical export direction")
		and summary.text.contains("Exact data"),
		"The dock must provide a non-visual graph summary and exact-data route.",
		failures
	)
	dock.queue_free()


func _new_script_instance(path: String, failures: Array[String]):
	var resource: Resource = ResourceLoader.load(path)
	if resource == null or not resource is Script:
		failures.append("Could not load test dependency: %s" % path)
		return null
	var instance = (resource as Script).new()
	if instance == null:
		failures.append("Could not instantiate test dependency: %s" % path)
	return instance


func _has_issue_code(issues: Array, code: String) -> bool:
	for issue_value in issues:
		if issue_value is Dictionary and str((issue_value as Dictionary).get("code", "")) == code:
			return true
	return false


func _check(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

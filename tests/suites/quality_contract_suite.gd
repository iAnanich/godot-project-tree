extends RefCounted

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const VALIDATOR_PATH: String = ADDON_ROOT + "core/snapshot_validator.gd"
const SCANNER_PATH: String = ADDON_ROOT + "core/project_scanner.gd"
const STATE_STORE_PATH: String = ADDON_ROOT + "core/editor_state_store.gd"
const SNAPSHOT_SCOPE_PATH: String = ADDON_ROOT + "core/snapshot_scope.gd"
const GRAPH_QUERY_PATH: String = ADDON_ROOT + "core/graph_query.gd"
const EXPORT_SERVICE_PATH: String = ADDON_ROOT + "export/export_service.gd"
const DOCK_SCENE_PATH: String = ADDON_ROOT + "ui/dependency_dock.tscn"
const EXPORTER_CONTRACT_PATH: String = "res://tests/contracts/exporter_contract.gd"
const MISSING_CAPABILITY_EXPORTER_PATH: String = "res://tests/contract_fixtures/exporters/missing_capability_exporter.gd"
const UPPERCASE_EXPORTER_PATH: String = "res://tests/contract_fixtures/exporters/uppercase_exporter.gd"
const EMPTY_OUTPUT_EXPORTER_PATH: String = "res://tests/contract_fixtures/exporters/empty_output_exporter.gd"
const STATIC_EXECUTION_FIXTURE_ROOT: String = "res://tests/security_fixtures"
const STATIC_EXECUTION_MARKER: String = "user://sdi_static_analysis_execution_marker.txt"
const FAILING_COMMIT_SERVICE_PATH: String = "res://tests/contract_fixtures/services/failing_commit_export_service.gd"


## Runs quality-boundary, extension-contract, and non-visual-access tests.
func run(valid_snapshot: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	_test_snapshot_validation(valid_snapshot, failures)
	_test_exporter_contracts(valid_snapshot, failures)
	_test_export_replacement_recovery(valid_snapshot, failures)
	_test_source_only_scan(failures)
	_test_service_initialization_contracts(failures)
	_test_scan_root_boundary(failures)
	_test_visual_decoding_summary(valid_snapshot, failures)
	_test_control_tooltips(failures)
	_test_toolbar_and_export_only_contract(valid_snapshot, failures)
	_test_scope_projection_and_graph_queries(failures)
	_test_editor_state_round_trip(failures)
	return failures


func _test_snapshot_validation(valid_snapshot: Dictionary, failures: Array[String]) -> void:
	var validator = _new_script_instance(VALIDATOR_PATH, failures)
	if validator == null:
		return
	var valid_result: Dictionary = validator.validate(valid_snapshot)
	_check(
		valid_result.get("ok", false),
		"Snapshot validator rejected a valid canonical snapshot.",
		failures
	)

	var typed_schema_snapshot: Dictionary = valid_snapshot.duplicate(true)
	typed_schema_snapshot["schema_version"] = "1"
	var typed_schema_result: Dictionary = validator.validate(typed_schema_snapshot)
	_check(
		(
			not typed_schema_result.get("ok", true)
			and _has_issue_code(
				typed_schema_result.get("errors", []), "invalid_schema_version_type"
			)
		),
		"Snapshot validator must reject a string schema version instead of coercing it.",
		failures
	)

	var missing_node_field_snapshot: Dictionary = valid_snapshot.duplicate(true)
	missing_node_field_snapshot["nodes"][0].erase("methods")
	var missing_node_field_result: Dictionary = validator.validate(missing_node_field_snapshot)
	_check(
		(
			not missing_node_field_result.get("ok", true)
			and _has_issue_code(missing_node_field_result.get("errors", []), "missing_node_field")
		),
		"Snapshot validator must enforce the schema-required node collections.",
		failures
	)

	var invalid_node_id_snapshot: Dictionary = valid_snapshot.duplicate(true)
	invalid_node_id_snapshot["nodes"][0]["id"] = 123
	var invalid_node_id_result: Dictionary = validator.validate(invalid_node_id_snapshot)
	_check(
		(
			not invalid_node_id_result.get("ok", true)
			and _has_issue_code(invalid_node_id_result.get("errors", []), "invalid_node_field")
		),
		"Snapshot validator must reject non-string node IDs instead of coercing them.",
		failures
	)

	var missing_edge_field_snapshot: Dictionary = valid_snapshot.duplicate(true)
	missing_edge_field_snapshot["edges"][0].erase("member_links")
	var missing_edge_field_result: Dictionary = validator.validate(missing_edge_field_snapshot)
	_check(
		(
			not missing_edge_field_result.get("ok", true)
			and _has_issue_code(missing_edge_field_result.get("errors", []), "missing_edge_field")
		),
		"Snapshot validator must enforce the schema-required edge member_links collection.",
		failures
	)

	var invalid_edge_endpoint_snapshot: Dictionary = valid_snapshot.duplicate(true)
	invalid_edge_endpoint_snapshot["edges"][0]["source"] = 123
	var invalid_edge_endpoint_result: Dictionary = validator.validate(
		invalid_edge_endpoint_snapshot
	)
	_check(
		(
			not invalid_edge_endpoint_result.get("ok", true)
			and _has_issue_code(
				invalid_edge_endpoint_result.get("errors", []), "invalid_edge_field"
			)
		),
		"Snapshot validator must reject non-string edge endpoints instead of coercing them.",
		failures
	)

	var invalid_message_snapshot: Dictionary = valid_snapshot.duplicate(true)
	invalid_message_snapshot["warnings"] = [42]
	var invalid_message_result: Dictionary = validator.validate(invalid_message_snapshot)
	_check(
		(
			not invalid_message_result.get("ok", true)
			and _has_issue_code(
				invalid_message_result.get("errors", []), "invalid_snapshot_message"
			)
		),
		"Snapshot validator must reject non-string warning and error entries.",
		failures
	)

	var duplicate_snapshot: Dictionary = valid_snapshot.duplicate(true)
	duplicate_snapshot["nodes"].append(duplicate_snapshot["nodes"][0].duplicate(true))
	var duplicate_result: Dictionary = validator.validate(duplicate_snapshot)
	_check(
		(
			not duplicate_result.get("ok", true)
			and _has_issue_code(duplicate_result.get("errors", []), "duplicate_node_id")
		),
		"Snapshot validator must reject duplicate node IDs with a stable code.",
		failures
	)

	var invalid_scope_snapshot: Dictionary = valid_snapshot.duplicate(true)
	invalid_scope_snapshot["nodes"][0]["scope_role"] = "maybe"
	var invalid_scope_result: Dictionary = validator.validate(invalid_scope_snapshot)
	_check(
		(
			not invalid_scope_result.get("ok", true)
			and _has_issue_code(invalid_scope_result.get("errors", []), "invalid_scope_role")
		),
		"Snapshot validator must reject unsupported node scope roles.",
		failures
	)

	var dangling_snapshot: Dictionary = valid_snapshot.duplicate(true)
	dangling_snapshot["edges"].append(
		{
			"source": str(valid_snapshot["nodes"][0]["id"]),
			"target": "missing://node",
			"kind": "uses",
			"member_links": []
		}
	)
	var dangling_result: Dictionary = validator.validate(dangling_snapshot)
	_check(
		(
			not dangling_result.get("ok", true)
			and _has_issue_code(dangling_result.get("errors", []), "dangling_edge_target")
		),
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
		(
			not unknown_member_result.get("ok", true)
			and _has_issue_code(unknown_member_result.get("errors", []), "unknown_member_reference")
		),
		"Snapshot validator must reject member provenance that contradicts its endpoint node.",
		failures
	)

	var invalid_diagnostic_snapshot: Dictionary = valid_snapshot.duplicate(true)
	invalid_diagnostic_snapshot["diagnostics"] = [
		{"severity": "critical", "code": "bad", "message": "invalid", "context": {}}
	]
	var invalid_diagnostic_result: Dictionary = validator.validate(invalid_diagnostic_snapshot)
	_check(
		(
			not invalid_diagnostic_result.get("ok", true)
			and _has_issue_code(
				invalid_diagnostic_result.get("errors", []), "invalid_diagnostic_severity"
			)
		),
		"Snapshot validator must reject unsupported diagnostic severities.",
		failures
	)

	var invalid_scene_usage_snapshot: Dictionary = valid_snapshot.duplicate(true)
	if not invalid_scene_usage_snapshot.get("scene_usages", []).is_empty():
		invalid_scene_usage_snapshot["scene_usages"][0].erase("column")
		var invalid_scene_usage_result: Dictionary = validator.validate(
			invalid_scene_usage_snapshot
		)
		_check(
			(
				not invalid_scene_usage_result.get("ok", true)
				and _has_issue_code(
					invalid_scene_usage_result.get("errors", []), "invalid_scene_usage_field"
				)
			),
			"Snapshot validator must reject scene evidence without an exact positive column.",
			failures
		)

	var missing_node_scene_usage_snapshot: Dictionary = valid_snapshot.duplicate(true)
	if not missing_node_scene_usage_snapshot.get("scene_usages", []).is_empty():
		var canonical_usage: Dictionary = missing_node_scene_usage_snapshot["scene_usages"][0]
		var usage_script_path: String = str(canonical_usage.get("script_path", ""))
		for node_value in missing_node_scene_usage_snapshot.get("nodes", []):
			if not node_value is Dictionary:
				continue
			var node: Dictionary = node_value
			if str(node.get("path", "")) != usage_script_path:
				continue
			var retained_usages: Array = []
			for usage_value in node.get("scene_usages", []):
				if usage_value != canonical_usage:
					retained_usages.append(usage_value)
			node["scene_usages"] = retained_usages
			break
		var missing_node_scene_usage_result: Dictionary = validator.validate(
			missing_node_scene_usage_snapshot
		)
		_check(
			(
				not missing_node_scene_usage_result.get("ok", true)
				and _has_issue_code(
					missing_node_scene_usage_result.get("errors", []), "missing_node_scene_usage"
				)
			),
			"Snapshot validator must reject canonical scene evidence missing from its script node.",
			failures
		)

	var invalid_occurrence_snapshot: Dictionary = valid_snapshot.duplicate(true)
	var occurrence_mutated: bool = false
	for edge_value in invalid_occurrence_snapshot.get("edges", []):
		if not edge_value is Dictionary:
			continue
		for link_value in edge_value.get("member_links", []):
			if link_value is Dictionary and link_value.has("source_location"):
				link_value["source_location"]["line"] = 0
				occurrence_mutated = true
				break
		if occurrence_mutated:
			break
	if occurrence_mutated:
		var invalid_occurrence_result: Dictionary = validator.validate(invalid_occurrence_snapshot)
		_check(
			(
				not invalid_occurrence_result.get("ok", true)
				and _has_issue_code(
					invalid_occurrence_result.get("errors", []), "invalid_source_location"
				)
			),
			"Snapshot validator must reject dependency evidence without an exact positive line.",
			failures
		)

	var export_service = _new_script_instance(EXPORT_SERVICE_PATH, failures)
	if export_service != null:
		var export_result: Dictionary = export_service.export_to_string("json", dangling_snapshot)
		_check(
			(
				not export_result.get("ok", true)
				and export_result.get("code", "") == "invalid_snapshot"
			),
			"Export service must reject invalid snapshots before serialization.",
			failures
		)


func _test_exporter_contracts(valid_snapshot: Dictionary, failures: Array[String]) -> void:
	var service = _new_script_instance(EXPORT_SERVICE_PATH, failures)
	var contract = _new_script_instance(EXPORTER_CONTRACT_PATH, failures)
	if service == null or contract == null:
		return
	var descriptors: Array = service.format_descriptors()
	_check(
		descriptors.size() == 3,
		"Built-in exporter descriptor count changed unexpectedly.",
		failures
	)
	for descriptor_value in descriptors:
		var descriptor: Dictionary = descriptor_value
		var capabilities_value = descriptor.get("capabilities", {})
		_check(
			capabilities_value is Dictionary,
			"Exporter descriptors must expose capabilities.",
			failures
		)
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
			(
				not empty_result.get("ok", true)
				and empty_result.get("code", "") == "empty_export_output"
			),
			"Export service must diagnose an exporter that produces empty output.",
			failures
		)


func _test_export_replacement_recovery(valid_snapshot: Dictionary, failures: Array[String]) -> void:
	var service = _new_script_instance(FAILING_COMMIT_SERVICE_PATH, failures)
	if service == null:
		return
	var directory: String = "user://script_dependency_inspector/export_recovery"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var destination: String = directory + "/existing.json"
	var original_text: String = "previous-valid-export"
	var original_file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if original_file == null:
		failures.append("Could not create export-recovery fixture destination.")
		return
	original_file.store_string(original_text)
	original_file.close()
	var result: Dictionary = service.export_to_file("json", destination, valid_snapshot)
	_check(
		not result.get("ok", true) and result.get("code", "") == "commit_failed_restored",
		"A failed replacement commit must report that the previous export was restored.",
		failures
	)
	var restored_file: FileAccess = FileAccess.open(destination, FileAccess.READ)
	_check(
		restored_file != null,
		"The previous export must remain readable after commit failure.",
		failures
	)
	if restored_file != null:
		var restored_text: String = restored_file.get_as_text()
		restored_file.close()
		_check(
			restored_text == original_text,
			"A failed replacement commit must preserve the previous destination content.",
			failures
		)


func _test_source_only_scan(failures: Array[String]) -> void:
	var scanner = _new_script_instance(SCANNER_PATH, failures)
	if scanner == null:
		return
	if FileAccess.file_exists(STATIC_EXECUTION_MARKER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STATIC_EXECUTION_MARKER))
	var result: Dictionary = (
		scanner
		. scan(
			STATIC_EXECUTION_FIXTURE_ROOT,
			{
				"use_runtime_reflection": true,
				"include_scene_usages": false,
				"excluded_path_prefixes": PackedStringArray(),
			}
		)
	)
	_check(
		result.get("errors", []).is_empty(),
		"Source-only security fixture scan should complete without scanner errors.",
		failures
	)
	_check(
		not FileAccess.file_exists(STATIC_EXECUTION_MARKER),
		"Dependency discovery must not execute a scanned script static initializer, even when the legacy reflection option is true.",
		failures
	)


func _test_service_initialization_contracts(failures: Array[String]) -> void:
	for service_path in [SCANNER_PATH, ADDON_ROOT + "core/graph_builder.gd"]:
		var service = _new_script_instance(service_path, failures)
		if service == null:
			continue
		_check(
			service.has_method("initialization_errors"),
			"Core service must expose transitive initialization failures: %s" % service_path,
			failures
		)
		if service.has_method("initialization_errors"):
			_check(
				(service.call("initialization_errors") as Array).is_empty(),
				"Core service reported unexpected initialization failures: %s" % service_path,
				failures
			)


func _test_scan_root_boundary(failures: Array[String]) -> void:
	var scanner = _new_script_instance(SCANNER_PATH, failures)
	if scanner == null:
		return

	var project_absolute_root: String = ProjectSettings.globalize_path("res://tests/fixtures")
	var localized: Dictionary = scanner.validate_root(project_absolute_root)
	_check(
		localized.get("ok", false) and str(localized.get("root", "")) == "res://tests/fixtures",
		"Absolute folders selected by a native FileDialog must normalize to their res:// project path.",
		failures
	)
	var absolute_scan: Dictionary = scanner.scan(
		project_absolute_root, {"use_runtime_reflection": false, "include_scene_usages": false}
	)
	_check(
		(
			absolute_scan.get("errors", []).is_empty()
			and str(absolute_scan.get("root_path", "")) == "res://tests/fixtures"
		),
		"The public scanner must accept an absolute path when it resolves inside the current project.",
		failures
	)

	for invalid_root in ["/tmp", "user://", "res://../outside"]:
		var result: Dictionary = scanner.scan(invalid_root, {"use_runtime_reflection": false})
		_check(
			(
				not result.get("errors", []).is_empty()
				and _has_issue_code(result.get("diagnostics", []), "invalid_scan_root")
			),
			(
				"Scanner must reject paths outside res:// with a structured diagnostic: %s"
				% invalid_root
			),
			failures
		)


func _test_visual_decoding_summary(valid_snapshot: Dictionary, failures: Array[String]) -> void:
	var scene_resource: Resource = ResourceLoader.load(DOCK_SCENE_PATH)
	if scene_resource == null or not scene_resource is PackedScene:
		failures.append("Quality suite could not load the dependency dock scene.")
		return
	var dock: Control = (scene_resource as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(dock)
	var invalid_candidate: Dictionary = valid_snapshot.duplicate(true)
	invalid_candidate["nodes"][0].erase("methods")
	var candidate_validation: Dictionary = dock.call(
		"_validate_snapshot_candidate", invalid_candidate
	)
	_check(
		(
			not candidate_validation.get("ok", true)
			and _has_issue_code(candidate_validation.get("errors", []), "missing_node_field")
		),
		"Dock scan lifecycle must reject a structurally invalid snapshot candidate before acceptance.",
		failures
	)
	dock.set("_snapshot", valid_snapshot.duplicate(true))
	dock.call("_render_snapshot")
	var legend: RichTextLabel = dock.get_node("%LegendView")
	var summary: RichTextLabel = dock.get_node("%SummaryView")
	_check(
		(
			legend.text.contains("Inheritance")
			and legend.text.contains("load/preload or class-member use")
			and legend.text.contains("Type-annotation use")
			and legend.text.contains("Rendered direction")
		),
		"The initial graph view must visibly decode edge colors and direction.",
		failures
	)
	_check(
		(
			summary.text.contains("Dependency graph summary")
			and summary.text.contains("Canonical export direction")
			and summary.text.contains("Exact data")
		),
		"The dock must provide a non-visual graph summary and exact-data route.",
		failures
	)
	var first_node: Dictionary = valid_snapshot.get("nodes", [])[0]
	var first_node_id: String = str(first_node.get("id", ""))
	var search_input: LineEdit = dock.get_node("%SearchInput")
	var search_status: Label = dock.get_node("%SearchStatus")
	search_input.text = str(first_node.get("name", first_node_id))
	dock.call("_apply_search")
	var match_ids: Array = dock.get("_search_match_ids")
	var rendered_node: GraphNode = dock.get("_id_to_graph_node").get(first_node_id)
	_check(
		(
			match_ids.has(first_node_id)
			and search_status.text.contains("/")
			and rendered_node != null
			and rendered_node.selected
		),
		"Search must index node names, report a match count, and focus the current result.",
		failures
	)
	dock.queue_free()


func _test_control_tooltips(failures: Array[String]) -> void:
	var scene_resource: Resource = ResourceLoader.load(DOCK_SCENE_PATH)
	if scene_resource == null or not scene_resource is PackedScene:
		failures.append("Tooltip contract could not load the dependency dock scene.")
		return
	var dock: Control = (scene_resource as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(dock)
	var required_names: Array[String] = [
		"ScanButton",
		"ScanModeIndicator",
		"ExportButton",
		"FormatOption",
		"ShowGraph",
		"ScopeOption",
		"ChooseScope",
		"IncludeDescendants",
		"IsolateNeighborhood",
		"ClearFocus",
		"IncludeAddons",
		"IncludeNative",
		"IncludeExternal",
		"IncludeMethods",
		"IncludeSignals",
		"IncludeProperties",
		"IncludeDependencies",
		"IncludeTypeDependencies",
		"IncludeMemberAccessDependencies",
		"ShowMemberDependencyEdges",
		"MethodSignatures",
		"SignalSignatures",
		"PropertyTypes",
		"ExportColors",
		"GraphNodeWidth",
		"GraphNodeMaxWidth",
		"NativeNodeWidth",
		"MaxMembers",
		"MaxMemberHeight",
		"SiblingSpacing",
		"LayerSpacing",
		"DepthTopToBottom",
		"SearchInput",
		"PreviousMatch",
		"NextMatch",
		"SyncOnEditorChanges",
		"EditorSyncDebounce",
		"FollowActiveScript",
		"AutoRescan",
		"AutoRescanDelay",
		"AutoExportJson",
		"AutoExportJsonPath",
		"BrowseAutoExportJson",
		"AutoExportMermaid",
		"AutoExportMermaidPath",
		"BrowseAutoExportMermaid",
		"AutoExportPlantUML",
		"AutoExportPlantUMLPath",
		"BrowseAutoExportPlantUML",
		"ContentSourcesHeader",
		"ContentMembersHeader",
		"ContentRelationsHeader",
		"ContentExportHeader",
		"AppearanceSizingHeader",
		"AppearanceDensityHeader",
		"AppearanceLayoutHeader",
		"ColorsNodesHeader",
		"ColorsMembersHeader",
		"ColorsRelationsHeader",
		"ColorsFamiliesHeader",
		"AutomationEditorHeader",
		"AutomationTimedHeader",
		"AutomationExportHeader",
	]
	for control_name in required_names:
		var control: Control = dock.get_node_or_null("%%%s" % control_name)
		_check(control != null, "Expected dock control is missing: %s" % control_name, failures)
		if control != null:
			_check(
				not control.tooltip_text.strip_edges().is_empty(),
				"Every option control must explain itself with a tooltip: %s" % control_name,
				failures
			)
	for color_name in [
		"UserColor",
		"AddonColor",
		"NativeColor",
		"ExternalColor",
		"PropertyColor",
		"SignalColor",
		"MethodColor",
		"MetadataColor",
		"InheritanceColor",
		"DependencyColor",
		"TypeDependencyColor",
		"ObjectFamilyColor",
		"RefCountedFamilyColor",
		"NodeFamilyColor",
		"Node2DFamilyColor",
		"Node3DFamilyColor",
		"ControlFamilyColor",
		"OtherFamilyColor",
	]:
		var picker: ColorPickerButton = (
			dock.get_node_or_null("%%%s" % color_name) as ColorPickerButton
		)
		_check(picker != null, "Expected color option is missing: %s" % color_name, failures)
		if picker != null:
			_check(
				not picker.tooltip_text.strip_edges().is_empty(),
				"Every color option must explain its visual role: %s" % color_name,
				failures
			)
	dock.queue_free()


func _test_toolbar_and_export_only_contract(
	valid_snapshot: Dictionary, failures: Array[String]
) -> void:
	var scene_resource: Resource = ResourceLoader.load(DOCK_SCENE_PATH)
	if scene_resource == null or not scene_resource is PackedScene:
		failures.append("UI layout contract could not load the dependency dock scene.")
		return
	var dock: Control = (scene_resource as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(dock)
	var format_option: OptionButton = dock.get_node("%FormatOption")
	var indicator: Label = dock.get_node("%ScanModeIndicator")
	var show_graph: CheckButton = dock.get_node("%ShowGraph")
	var graph: GraphEdit = dock.get_node("%GraphEdit")
	var search_bar: HBoxContainer = dock.get_node("%SearchBar")
	var focus_bar: HBoxContainer = dock.get_node("%FocusBar")
	var legend_panel: PanelContainer = dock.get_node("%LegendPanel")
	_check(
		(
			format_option.custom_minimum_size.x <= 100.0
			and not bool(format_option.size_flags_horizontal & Control.SIZE_EXPAND)
		),
		"The export-format selector must remain compact instead of consuming toolbar action space.",
		failures
	)
	_check(
		indicator.text == "Save sync" and not indicator.tooltip_text.is_empty(),
		"The toolbar must expose the default editor-synchronized scan mode next to Scan.",
		failures
	)
	_check(
		show_graph.button_pressed and graph.visible,
		"Graph view must be enabled by default.",
		failures
	)
	dock.set("_snapshot", valid_snapshot.duplicate(true))
	dock.call("_render_snapshot")
	_check(
		not (dock.get("_graph_nodes") as Array).is_empty(),
		"Enabled graph view must render the current snapshot.",
		failures
	)
	show_graph.button_pressed = false
	dock.call("_on_graph_view_toggled", false)
	_check(
		(
			not graph.visible
			and not search_bar.visible
			and not focus_bar.visible
			and not legend_panel.visible
		),
		"Export-only mode must hide graph-specific surfaces together.",
		failures
	)
	_check(
		(
			(dock.get("_graph_nodes") as Array).is_empty()
			and (dock.get_node("%SummaryView") as RichTextLabel).text.contains(
				"Dependency graph summary"
			)
		),
		"Export-only mode must release rendered nodes while retaining the snapshot summary.",
		failures
	)
	show_graph.button_pressed = true
	dock.call("_on_graph_view_toggled", true)
	_check(
		graph.visible and not (dock.get("_graph_nodes") as Array).is_empty(),
		"Re-enabling the graph must render the existing snapshot without rescanning.",
		failures
	)
	var folded_header: Button = dock.get_node("%ContentExportHeader")
	var folded_body: Control = dock.get_node("%ContentExportBody")
	_check(
		not folded_header.button_pressed and not folded_body.visible,
		"Secondary control groups should start folded.",
		failures
	)
	folded_header.button_pressed = true
	dock.call("_on_fold_section_toggled", true, "content_export")
	_check(
		folded_body.visible and folded_header.text.begins_with("▾"),
		"Fold headers must visibly reveal their grouped controls.",
		failures
	)
	dock.queue_free()


func _test_scope_projection_and_graph_queries(failures: Array[String]) -> void:
	var scope_projector = _new_script_instance(SNAPSHOT_SCOPE_PATH, failures)
	var graph_query = _new_script_instance(GRAPH_QUERY_PATH, failures)
	if scope_projector == null or graph_query == null:
		return
	var child_usage: Dictionary = {
		"scene_path": "res://scene.tscn",
		"node_path": "Child",
		"script_path": "res://feature/child.gd",
		"line": 1,
		"column": 1,
		"evidence": "tscn_node_script_attachment",
	}
	var child_node: Dictionary = _test_node("res://feature/child.gd", "Child", "user")
	child_node["scene_usages"] = [child_usage.duplicate(true)]
	var snapshot: Dictionary = {
		"schema_version": 2,
		"metadata": {"root_path": "res://", "engine_version": "test", "options": {}, "style": {}},
		"nodes":
		[
			child_node,
			_test_node("res://shared/base.gd", "Base", "user"),
			_test_node("res://shared/service.gd", "Service", "user"),
			_test_node("native://RefCounted", "RefCounted", "native"),
			_test_node("res://unrelated/other.gd", "Other", "user"),
		],
		"edges":
		[
			{
				"source": "res://feature/child.gd",
				"target": "res://shared/base.gd",
				"kind": "extends",
				"member_links": []
			},
			{
				"source": "res://shared/base.gd",
				"target": "native://RefCounted",
				"kind": "extends",
				"member_links": []
			},
			{
				"source": "res://feature/child.gd",
				"target": "res://shared/service.gd",
				"kind": "uses",
				"member_links": []
			},
			{
				"source": "res://shared/service.gd",
				"target": "native://RefCounted",
				"kind": "extends",
				"member_links": []
			},
		],
		"scene_usages":
		[
			child_usage,
			{
				"scene_path": "res://other.tscn",
				"node_path": "Other",
				"script_path": "res://unrelated/other.gd",
				"line": 1,
				"column": 1,
				"evidence": "tscn_node_script_attachment"
			},
		],
		"warnings": [],
		"errors": [],
		"diagnostics": [],
	}
	var projected: Dictionary = scope_projector.project(snapshot, "res://feature")
	var ids: Array[String] = []
	var roles: Dictionary = {}
	for node_value in projected.get("nodes", []):
		var node: Dictionary = node_value
		ids.append(str(node.get("id", "")))
		roles[str(node.get("id", ""))] = str(node.get("scope_role", ""))
	_check(
		ids.has("res://feature/child.gd"),
		"Selected-scope script must remain in the projected snapshot.",
		failures
	)
	_check(
		ids.has("res://shared/base.gd") and ids.has("res://shared/service.gd"),
		"Required out-of-scope ancestors and direct dependencies must remain as context.",
		failures
	)
	_check(
		ids.has("native://RefCounted"),
		"Required native ancestry must remain in a scoped snapshot.",
		failures
	)
	_check(
		not ids.has("res://unrelated/other.gd"),
		"Unrelated out-of-scope scripts must be omitted.",
		failures
	)
	_check(
		(
			roles.get("res://feature/child.gd") == "in_scope"
			and roles.get("res://shared/base.gd") == "context"
		),
		"Scoped nodes must expose explicit in-scope/context roles.",
		failures
	)
	_check(
		projected.get("scene_usages", []).size() == 1,
		"Scoped projection must remove scene evidence for omitted scripts.",
		failures
	)
	var validator = _new_script_instance(VALIDATOR_PATH, failures)
	if validator != null:
		var validation_result: Dictionary = validator.validate(projected)
		_check(
			validation_result.get("ok", false),
			"Projected scope snapshots must satisfy the public snapshot validator.",
			failures
		)
		var mismatched: Dictionary = projected.duplicate(true)
		(mismatched["metadata"]["scope_summary"] as Dictionary)["context_nodes"] = 999
		var mismatch_result: Dictionary = validator.validate(mismatched)
		_check(
			(
				not mismatch_result.get("ok", true)
				and _has_issue_code(mismatch_result.get("errors", []), "scope_summary_mismatch")
			),
			"Scope summary drift must be rejected at the serialization boundary.",
			failures
		)

	var counts: Dictionary = graph_query.descendant_counts(projected)
	_check(
		int((counts.get("res://shared/base.gd", {}) as Dictionary).get("direct", -1)) == 1,
		"Direct descendant counts must be computed from inheritance edges.",
		failures
	)
	var related: Dictionary = graph_query.relationship_focus_ids(
		projected, "res://feature/child.gd", false
	)
	_check(
		(
			related.has("res://shared/base.gd")
			and related.has("native://RefCounted")
			and not related.has("res://shared/service.gd")
		),
		"Relationship focus must emphasize inheritance context without conflating dependencies.",
		failures
	)
	var neighborhood: Dictionary = graph_query.neighborhood_ids(
		projected, "res://feature/child.gd", false
	)
	_check(
		neighborhood.has("res://shared/service.gd"),
		"Neighborhood isolation must include direct dependency targets.",
		failures
	)
	var base_neighborhood: Dictionary = graph_query.neighborhood_ids(
		projected, "res://shared/base.gd", false
	)
	_check(
		not base_neighborhood.has("res://feature/child.gd"),
		"Neighborhood isolation must not include descendants when descendant focus is disabled.",
		failures
	)
	var base_neighborhood_with_descendants: Dictionary = graph_query.neighborhood_ids(
		projected, "res://shared/base.gd", true
	)
	_check(
		base_neighborhood_with_descendants.has("res://feature/child.gd"),
		"Neighborhood isolation must include descendants when descendant focus is enabled.",
		failures
	)


func _test_node(id: String, name: String, kind: String) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"qualified_name": name,
		"class_name": name if kind in ["user", "addon"] else "",
		"has_custom_name": kind in ["user", "addon"],
		"path": id if id.begins_with("res://") else "",
		"kind": kind,
		"base": {},
		"native_base": name if kind == "native" else "",
		"inheritance_family": "ref_counted",
		"methods": [],
		"signals": [],
		"properties": [],
		"inner_classes": [],
		"autoload": {},
		"scene_usages": [],
	}


func _test_editor_state_round_trip(failures: Array[String]) -> void:
	var store = _new_script_instance(STATE_STORE_PATH, failures)
	if store == null:
		return
	var path: String = "user://script_dependency_inspector/state_round_trip/editor_state.json"
	var state: Dictionary = {
		"schema_version": 4,
		"scan_root": "res://tests/fixtures",
		"recent_scan_roots": ["res://tests/fixtures", "res://"],
		"focus_include_descendants": true,
		"isolate_neighborhood": true,
		"graph_view_enabled": false,
		"control_section_expanded": {"content_export": true, "automation_timed": true},
		"sync_on_editor_changes": false,
		"editor_change_debounce_seconds": 2.5,
		"follow_active_script": false,
		"auto_rescan_enabled": true,
		"auto_rescan_delay_seconds": 37.0,
		"auto_export": {"json": true, "mermaid": false, "plantuml": true},
		"export_paths":
		{
			"json": "res://generated/dependencies.json",
			"mermaid": "res://generated/dependencies.mmd",
			"plantuml": "res://generated/dependencies.puml",
		},
	}
	var save_result: Dictionary = store.save_state(path, state)
	_check(save_result.get("ok", false), "Editor state should save atomically.", failures)
	var defaults: Dictionary = {
		"schema_version": 4,
		"scan_root": "res://",
		"recent_scan_roots": ["res://"],
		"focus_include_descendants": false,
		"isolate_neighborhood": false,
		"graph_view_enabled": true,
		"control_section_expanded": {"content_export": false, "automation_timed": false},
		"sync_on_editor_changes": true,
		"editor_change_debounce_seconds": 1.0,
		"follow_active_script": true,
		"auto_rescan_enabled": false,
		"auto_rescan_delay_seconds": 60.0,
		"auto_export": {"json": false, "mermaid": false, "plantuml": false},
		"export_paths": {"json": "", "mermaid": "", "plantuml": ""},
	}
	var load_result: Dictionary = store.load_state(path, defaults)
	var loaded: Dictionary = load_result.get("state", {})
	_check(load_result.get("ok", false), "Editor state should load after save.", failures)
	_check(
		(
			str(loaded.get("scan_root", "")) == "res://tests/fixtures"
			and bool(loaded.get("focus_include_descendants", false))
			and bool(loaded.get("isolate_neighborhood", false))
		),
		"Scan scope and graph-focus preferences must round-trip.",
		failures
	)
	_check(
		(
			not bool(loaded.get("graph_view_enabled", true))
			and bool(
				(loaded.get("control_section_expanded", {}) as Dictionary).get(
					"content_export", false
				)
			)
			and bool(
				(loaded.get("control_section_expanded", {}) as Dictionary).get(
					"automation_timed", false
				)
			)
		),
		"Graph visibility and fold-section preferences must round-trip.",
		failures
	)

	_check(
		(
			not bool(loaded.get("sync_on_editor_changes", true))
			and is_equal_approx(float(loaded.get("editor_change_debounce_seconds", 0.0)), 2.5)
			and not bool(loaded.get("follow_active_script", true))
		),
		"Editor synchronization preferences must round-trip independently.",
		failures
	)
	_check(
		(
			loaded.get("auto_rescan_enabled", false)
			and is_equal_approx(float(loaded.get("auto_rescan_delay_seconds", 0.0)), 37.0)
		),
		"Editor automation timer preferences must round-trip.",
		failures
	)
	_check(
		(
			bool((loaded.get("auto_export", {}) as Dictionary).get("json", false))
			and str((loaded.get("export_paths", {}) as Dictionary).get("plantuml", "")).ends_with(
				".puml"
			)
		),
		"Per-format automatic export preferences and paths must round-trip.",
		failures
	)

	# Schema 1 remains readable and receives schema-4 synchronization, scope, focus, view, and fold defaults.
	var legacy_path: String = "user://script_dependency_inspector/state_round_trip/editor_state_v1.json"
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	if legacy_file == null:
		failures.append("Could not create legacy editor-state migration fixture.")
		return
	(
		legacy_file
		. store_string(
			(
				JSON
				. stringify(
					{
						"schema_version": 1,
						"auto_rescan_enabled": true,
						"auto_rescan_delay_seconds": 19.0,
						"auto_export": {"json": false, "mermaid": true, "plantuml": false},
						"export_paths": {"json": "", "mermaid": "res://legacy.mmd", "plantuml": ""},
					}
				)
			)
		)
	)
	legacy_file.close()
	var legacy_result: Dictionary = store.load_state(legacy_path, defaults)
	var migrated: Dictionary = legacy_result.get("state", {})
	_check(
		(
			legacy_result.get("ok", false)
			and bool(migrated.get("sync_on_editor_changes", false))
			and bool(migrated.get("follow_active_script", false))
			and bool((migrated.get("auto_export", {}) as Dictionary).get("mermaid", false))
		),
		"Schema-1 editor state must migrate by retaining old values and applying schema-4 defaults.",
		failures
	)

	var invalid_schema_path: String = "user://script_dependency_inspector/state_round_trip/editor_state_invalid_schema.json"
	var invalid_schema_file: FileAccess = FileAccess.open(invalid_schema_path, FileAccess.WRITE)
	if invalid_schema_file == null:
		failures.append("Could not create invalid editor-state schema fixture.")
		return
	invalid_schema_file.store_string(JSON.stringify({"schema_version": "4"}))
	invalid_schema_file.close()
	var invalid_schema_result: Dictionary = store.load_state(invalid_schema_path, defaults)
	_check(
		(
			not invalid_schema_result.get("ok", true)
			and "integer" in str(invalid_schema_result.get("warning", ""))
		),
		"Editor-state schema must reject string values instead of coercing them.",
		failures
	)


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

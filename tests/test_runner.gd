extends SceneTree

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const ANALYZER_SCRIPT_PATH: String = ADDON_ROOT + "core/gdscript_analyzer.gd"
const SCANNER_SCRIPT_PATH: String = ADDON_ROOT + "core/project_scanner.gd"
const BUILDER_SCRIPT_PATH: String = ADDON_ROOT + "core/graph_builder.gd"
const EXPORT_SERVICE_SCRIPT_PATH: String = ADDON_ROOT + "export/export_service.gd"
const GRAPH_NODE_SCENE_PATH: String = ADDON_ROOT + "ui/dependency_graph_node.tscn"
const GRAPH_EDIT_SCRIPT_PATH: String = ADDON_ROOT + "ui/dependency_graph_edit.gd"
const DOCK_SCENE_PATH: String = ADDON_ROOT + "ui/dependency_dock.tscn"
const VALIDATOR_SCRIPT_PATH: String = ADDON_ROOT + "core/snapshot_validator.gd"
const SNAPSHOT_SCOPE_SCRIPT_PATH: String = ADDON_ROOT + "core/snapshot_scope.gd"
const QUALITY_SUITE_PATH: String = "res://tests/suites/quality_contract_suite.gd"

var _analyzer_script: Script
var _scanner_script: Script
var _builder_script: Script
var _export_service_script: Script
var _graph_node_scene: PackedScene
var _dock_scene: PackedScene
var _failures: Array[String] = []
var _snapshot: Dictionary = {}
var _showcase_snapshot: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_packaged_resource_paths()
	if not _load_test_dependencies():
		_finish()
		return
	_test_source_analyzer()
	_test_scan_and_graph()
	_test_showcase_graph()
	_test_graph_presentation()
	_test_inheritance_families()
	_test_depth_layout()
	_test_rendered_connection_direction()
	_test_member_rendered_connections()
	_test_connection_tooltip_evidence()
	_test_hidden_member_scope_validation()
	_test_validator_log_rendering()
	_test_exporters()
	_test_showcase_representations()
	_test_missing_root_failure()
	_test_quality_contracts()
	_finish()


func _test_packaged_resource_paths() -> void:
	var required_files = PackedStringArray(
		[
			"plugin.cfg",
			"plugin.gd",
			"default_settings.tres",
			"core/compat.gd",
			"core/gdscript_analyzer.gd",
			"core/graph_builder.gd",
			"core/graph_query.gd",
			"core/editor_state_store.gd",
			"core/logger.gd",
			"core/models.gd",
			"core/project_scanner.gd",
			"core/scene_usage_scanner.gd",
			"core/settings.gd",
			"core/snapshot_scope.gd",
			"core/snapshot_validator.gd",
			"export/export_service.gd",
			"export/exporter.gd",
			"export/json_exporter.gd",
			"export/mermaid_exporter.gd",
			"export/plantuml_exporter.gd",
			"ui/dependency_dock.gd",
			"ui/dependency_dock.tscn",
			"ui/dependency_graph_edit.gd",
			"ui/dependency_graph_node.gd",
			"ui/dependency_graph_node.tscn",
		]
	)
	for relative_path in required_files:
		var path = ADDON_ROOT + relative_path
		_check(FileAccess.file_exists(path), "Packaged plugin file is missing: %s" % path)


func _load_test_dependencies() -> bool:
	_analyzer_script = _load_test_script(ANALYZER_SCRIPT_PATH)
	_scanner_script = _load_test_script(SCANNER_SCRIPT_PATH)
	_builder_script = _load_test_script(BUILDER_SCRIPT_PATH)
	_export_service_script = _load_test_script(EXPORT_SERVICE_SCRIPT_PATH)
	_graph_node_scene = _load_test_scene(GRAPH_NODE_SCENE_PATH)
	_dock_scene = _load_test_scene(DOCK_SCENE_PATH)
	return _failures.is_empty()


func _load_test_script(path: String) -> Script:
	if not FileAccess.file_exists(path):
		_failures.append("Required test script is missing: %s" % path)
		return null
	var resource = ResourceLoader.load(path)
	if resource == null or not resource is Script:
		_failures.append("Required test script could not be loaded: %s" % path)
		return null
	return resource as Script


func _load_test_scene(path: String) -> PackedScene:
	if not FileAccess.file_exists(path):
		_failures.append("Required test scene is missing: %s" % path)
		return null
	var resource = ResourceLoader.load(path)
	if resource == null or not resource is PackedScene:
		_failures.append("Required test scene could not be loaded: %s" % path)
		return null
	return resource as PackedScene


func _finish() -> void:
	if _failures.is_empty():
		print("Script Dependency Inspector tests passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_source_analyzer() -> void:
	var analyzer = _analyzer_script.new()
	var source = (
		"\n"
		. join(
			[
				"@tool",
				"class_name Example",
				"extends Node",
				"signal updated(value: int)",
				'@export_category("Data")',
				"var internal_count: int = 0",
				"@export var count: int = 1",
				"var helper: FixtureHelper",
				"static func build(value: FixtureBase) -> FixtureHelper:",
				"    var local_only: LocalOnlyType",
				'    var ignored := load("res://nested.gd")',
				"    FixtureHelper.make()",
				"    var text := \"load('res://not_a_dependency.gd')\"",
				"    return str(value)",
				"func inline(value: int) -> int: return value",
				'const DOC := """',
				"class_name FalsePositive",
				"func fake_method() -> void:",
				'load("res://inside_doc.gd")',
				'"""',
				"const MULTILINE := preload(",
				'    "res://multiline.gd"',
				")",
			]
		)
	)
	var result: Dictionary = analyzer.analyze(source, "res://example.gd")
	_check(result["class_name"] == "Example", "Analyzer should read class_name.")
	_check(
		int(result.get("class_name_location", {}).get("line", 0)) == 2,
		"Analyzer should preserve the class_name source line."
	)
	_check(result["extends"]["value"] == "Node", "Analyzer should read extends.")
	_check(result["signals"].size() == 1, "Analyzer should read signals.")
	_check(result["properties"].size() == 3, "Analyzer should read top-level properties.")
	_check(
		not result["properties"][0]["exported"] and result["properties"][1]["exported"],
		"Export grouping annotations must not mark the next property as exported."
	)
	_check(
		result["methods"].size() == 2 and result["methods"][0]["static"],
		"Analyzer should read static and one-line methods."
	)
	_check(
		(
			result["methods"][1]["return_type"] == "int"
			and not str(result["methods"][1]["signature"]).contains("return value")
		),
		"One-line function bodies must not be included in signatures or return types."
	)
	_check(
		result["resource_dependencies"].has("res://nested.gd"),
		"Analyzer should read nested load dependencies."
	)
	_check(
		result["resource_dependencies"].has("res://multiline.gd"),
		"Analyzer should read multiline preload dependencies."
	)
	_check(
		not result["resource_dependencies"].has("res://not_a_dependency.gd"),
		"Analyzer should ignore load-like text inside strings."
	)
	_check(
		not result["resource_dependencies"].has("res://inside_doc.gd"),
		"Analyzer should ignore load-like text inside triple-quoted strings."
	)
	_check(
		(
			result["type_references"].has("FixtureBase")
			and result["type_references"].has("FixtureHelper")
			and result["type_references"].has("LocalOnlyType")
		),
		"Analyzer should collect class references from member and local type annotations."
	)
	_check(
		_detail_has_source_member(
			result.get("resource_dependency_details", []),
			"path",
			"res://nested.gd",
			"method",
			"build"
		),
		"Literal resource dependencies should retain the source member that contains them."
	)
	_check(
		_detail_has_source_member(
			result.get("type_reference_details", []),
			"symbol",
			"FixtureHelper",
			"property",
			"helper"
		),
		"Property type dependencies should retain their source member."
	)
	_check(
		_detail_has_source_member(
			result.get("type_reference_details", []), "symbol", "LocalOnlyType", "method", "build"
		),
		"Local type dependencies should retain their containing method."
	)
	_check(
		_access_exists(
			result.get("member_accesses", []), "FixtureHelper", "method", "make", "method", "build"
		),
		"Direct class-qualified member access should retain both source and target members."
	)


func _test_scan_and_graph() -> void:
	ProjectSettings.set_setting("autoload/FixtureHelperService", "*res://tests/fixtures/helper.gd")
	var scanner = _scanner_script.new()
	var scan_result = (
		scanner
		. scan(
			"res://tests/fixtures",
			{
				"include_addons": true,
				"use_runtime_reflection": true,
				"excluded_path_prefixes": PackedStringArray(),
			}
		)
	)
	ProjectSettings.set_setting("autoload/FixtureHelperService", null)
	_check(
		scan_result["errors"].is_empty(),
		"Fixture scan should not have errors: %s" % [scan_result["errors"]]
	)
	_check(scan_result["scripts"].size() == 5, "Fixture scan should find five scripts.")
	_check(
		scan_result.get("scene_usages", []).size() == 1,
		"Fixture scan should find one exact .tscn script attachment."
	)
	if scan_result.get("scene_usages", []).size() == 1:
		var scene_usage: Dictionary = scan_result["scene_usages"][0]
		_check(
			int(scene_usage.get("line", 0)) > 0 and int(scene_usage.get("column", 0)) == 1,
			"Scene attachment evidence should preserve a one-based exact source location."
		)
	var helper_record: Dictionary = {}
	for record_value in scan_result.get("scripts", []):
		if str((record_value as Dictionary).get("path", "")) == "res://tests/fixtures/helper.gd":
			helper_record = record_value
			break
	_check(
		str(helper_record.get("autoload", {}).get("name", "")) == "FixtureHelperService",
		"Scanner should classify matching ProjectSettings autoload entries."
	)

	var builder = _builder_script.new()
	_snapshot = (
		builder
		. build(
			scan_result,
			{
				"include_native_bases": true,
				"include_external_bases": true,
				"include_methods": true,
				"include_signals": true,
				"include_properties": true,
				"include_resource_dependencies": true,
				"include_type_dependencies": true,
				"include_member_access_dependencies": true,
				"show_member_dependency_edges": true,
				"show_method_signatures": false,
				"show_signal_signatures": false,
				"show_property_types": false,
				"style": {},
			}
		)
	)
	_check(
		_find_node(_snapshot, "res://tests/fixtures/child.gd").get("name", "") == "FixtureChild",
		"Graph should preserve class display names."
	)
	_check(
		_find_node(_snapshot, "res://tests/fixtures/base.gd").get("scene_usages", []).size() == 1,
		"Graph should attach exact scene usage evidence to the referenced script node."
	)
	_check(
		_has_edge(
			_snapshot["edges"],
			"res://tests/fixtures/child.gd",
			"res://tests/fixtures/base.gd",
			"extends"
		),
		"Graph should resolve class_name inheritance."
	)
	_check(
		_has_edge(
			_snapshot["edges"],
			"res://tests/fixtures/path_child.gd",
			"res://tests/fixtures/base.gd",
			"extends"
		),
		"Graph should resolve path inheritance."
	)
	_check(
		_has_edge(
			_snapshot["edges"],
			"res://tests/fixtures/child.gd",
			"res://tests/fixtures/helper.gd",
			"uses"
		),
		"Graph should include literal load/preload dependencies."
	)
	_check(
		_has_edge(
			_snapshot["edges"],
			"res://tests/fixtures/typed_consumer.gd",
			"res://tests/fixtures/helper.gd",
			"type_uses"
		),
		"Graph should include dependencies that exist only through type annotations."
	)
	_check(
		not _has_edge(
			_snapshot["edges"],
			"res://tests/fixtures/typed_consumer.gd",
			"res://tests/fixtures/helper.gd",
			"uses"
		),
		"Annotation-only dependencies must remain distinct from load/preload dependencies."
	)
	_check(
		_find_node(_snapshot, "native://Node").get("name", "") == "Node",
		"Graph should include native base classes."
	)
	_check(
		_find_node(_snapshot, "res://tests/fixtures/base.gd").get("name", "") == "FixtureBase",
		"Scripts with class_name should display only the custom class name."
	)
	_check(
		_find_node(_snapshot, "res://tests/fixtures/path_child.gd").get("name", "") == "path_child",
		"Scripts without class_name should display the script filename without its path."
	)


func _test_showcase_graph() -> void:
	var scanner = _scanner_script.new()
	var scan_result: Dictionary = (
		scanner
		. scan(
			"res://",
			{
				"include_addons": true,
				"use_runtime_reflection": true,
				"excluded_path_prefixes":
				PackedStringArray(
					[
						"res://.godot/",
						"res://addons/script_dependency_inspector/",
						"res://tests/",
						"res://examples/media_showcase/",
						"res://tools/media_capture/",
					]
				),
			}
		)
	)
	_check(
		scan_result["errors"].is_empty(),
		"Showcase scan should not have errors: %s" % [scan_result["errors"]]
	)
	_check(scan_result["scripts"].size() == 13, "Showcase scan should find thirteen scripts.")

	var builder = _builder_script.new()
	_showcase_snapshot = (
		builder
		. build(
			scan_result,
			{
				"include_native_bases": true,
				"include_external_bases": true,
				"include_methods": true,
				"include_signals": true,
				"include_properties": true,
				"include_resource_dependencies": true,
				"include_type_dependencies": true,
				"include_member_access_dependencies": true,
				"show_member_dependency_edges": true,
				"show_method_signatures": false,
				"show_signal_signatures": false,
				"show_property_types": false,
				"style": {},
			}
		)
	)
	_check(
		_showcase_snapshot["errors"].is_empty(),
		"Showcase graph should not have errors: %s" % [_showcase_snapshot["errors"]]
	)
	_check(
		(
			(
				_find_node(
					_showcase_snapshot, "res://addons/example_dependency_framework/combat_entity.gd"
				)
				. get("kind", "")
			)
			== "addon"
		),
		"Showcase graph should identify the example framework as an add-on."
	)
	_check(
		_has_edge(
			_showcase_snapshot["edges"],
			"res://examples/showcase/actors/base_actor.gd",
			"res://addons/example_dependency_framework/combat_entity.gd",
			"extends"
		),
		"Showcase graph should resolve inheritance from a third-party add-on class."
	)
	_check(
		_has_edge(
			_showcase_snapshot["edges"],
			"res://examples/showcase/actors/player_actor.gd",
			"res://examples/showcase/actors/base_actor.gd",
			"extends"
		),
		"Showcase graph should resolve class_name inheritance."
	)
	_check(
		_has_edge(
			_showcase_snapshot["edges"],
			"res://examples/showcase/actors/enemy_actor.gd",
			"res://examples/showcase/actors/base_actor.gd",
			"extends"
		),
		"Showcase graph should resolve path-based inheritance."
	)
	_check(
		_has_edge(
			_showcase_snapshot["edges"],
			"res://examples/showcase/actors/player_actor.gd",
			"res://examples/showcase/services/damage_service.gd",
			"uses"
		),
		"Showcase graph should include literal preload dependencies."
	)
	_check(
		_has_edge(
			_showcase_snapshot["edges"],
			"res://examples/showcase/actors/enemy_actor.gd",
			"res://examples/showcase/data/weapon_profile.gd",
			"uses"
		),
		"Showcase graph should include literal load dependencies."
	)
	_check(
		_has_edge(
			_showcase_snapshot["edges"],
			"res://examples/showcase/services/targeting_service.gd",
			"res://examples/showcase/actors/base_actor.gd",
			"type_uses"
		),
		"Showcase graph should include an annotation-only service dependency."
	)
	_check(
		_edge_has_member_link(
			_showcase_snapshot.get("edges", []),
			"res://examples/showcase/actors/base_actor.gd",
			"res://examples/showcase/services/damage_service.gd",
			"uses",
			"method",
			"attack_power",
			"method",
			"calculate_damage"
		),
		"Showcase graph should retain exact member provenance for direct class-member use."
	)
	_check(
		_edge_member_link_has_location(
			_showcase_snapshot.get("edges", []),
			"res://examples/showcase/actors/base_actor.gd",
			"res://examples/showcase/services/damage_service.gd",
			"uses",
			"method",
			"attack_power"
		),
		"Showcase relationship provenance should retain an exact source occurrence location."
	)
	_check(
		_find_node(_showcase_snapshot, "native://Node").get("name", "") == "Node",
		"Showcase graph should include native inheritance."
	)


func _test_graph_presentation() -> void:
	var style = {
		"graph_node_width": 240.0,
		"graph_node_max_width": 420.0,
		"native_node_width": 120.0,
		"graph_max_member_height": 520.0,
		"graph_max_members_per_section": 2,
		"graph_title_character_limit": 36,
		"graph_member_character_limit": 84,
		"property_color": "112233",
		"signal_color": "445566",
		"method_color": "778899",
		"metadata_color": "aabbcc",
		"user_script_color": "005a8d",
		"native_class_color": "59616d",
		"inheritance_edge_color": "e5e7eb",
		"dependency_edge_color": "e69f00",
		"type_dependency_edge_color": "56b4e9",
		"object_family_color": "101010",
		"ref_counted_family_color": "202020",
		"node_family_color": "334455",
		"node_2d_family_color": "404040",
		"node_3d_family_color": "505050",
		"control_family_color": "606060",
		"other_family_color": "707070",
	}
	var node_data = {
		"name": "PresentationExample",
		"kind": "user",
		"path": "res://presentation_example.gd",
		"inheritance_family": "node",
		"autoload": {"name": "PresentationService", "singleton": true},
		"scene_usages":
		[
			{
				"scene_path": "res://presentation_scene.tscn",
				"node_path": "Root/Consumer",
				"script_path": "res://presentation_example.gd",
				"line": 8,
				"column": 1,
				"evidence": "tscn_node_script_attachment",
			}
		],
		"properties":
		[
			{
				"name": "target",
				"type": "FixtureBase",
				"declaration": "var target: FixtureBase",
				"source_location": {"line": 3, "column": 1},
			}
		],
		"signals":
		[
			{
				"name": "changed",
				"arguments": "value: int",
				"signature": "signal changed(value: int)",
				"source_location": {"line": 4, "column": 1}
			}
		],
		"methods":
		[
			{
				"name": "resolve",
				"arguments": "target: FixtureBase",
				"return_type": "FixtureHelper",
				"signature": "func resolve(target: FixtureBase) -> FixtureHelper",
				"source_location": {"line": 7, "column": 1},
			}
		],
		"inner_classes": [{"name": "LocalState", "source_location": {"line": 10, "column": 1}}],
		"member_evidence":
		{
			"method:resolve":
			{
				"incoming": 2,
				"outgoing": 3,
				"relationship_kinds": ["uses", "type_uses"],
			}
		},
		"relationship_occurrences":
		[
			{
				"kind": "uses",
				"target_id": "res://tests/fixtures/helper.gd",
				"target_name": "FixtureHelper",
				"source_member": {"kind": "method", "name": "resolve"},
				"target_member": {"kind": "method", "name": "make"},
				"source_location": {"line": 12, "column": 5},
				"evidence": "class_member_access",
			}
		],
	}
	var compact_node: GraphNode = _graph_node_scene.instantiate()
	root.add_child(compact_node)
	(
		compact_node
		. call(
			"configure",
			node_data,
			style,
			{
				"show_method_signatures": false,
				"show_signal_signatures": false,
				"show_property_types": false,
			}
		)
	)
	var source_request: Dictionary = {}
	compact_node.source_requested.connect(
		func(path: String, line: int, column: int) -> void:
			source_request["path"] = path
			source_request["line"] = line
			source_request["column"] = column
	)
	var scene_request: Dictionary = {}
	compact_node.scene_requested.connect(
		func(path: String, line: int, column: int) -> void:
			scene_request["path"] = path
			scene_request["line"] = line
			scene_request["column"] = column
	)
	var compact_labels: Array[String] = _collect_control_texts(compact_node)
	_check(
		compact_node.custom_minimum_size.x >= 240.0 and compact_node.custom_minimum_size.x <= 420.0,
		"Script nodes should remain within configured width bounds."
	)
	_check(compact_labels.has("target"), "Compact properties should display only their names.")
	_check(compact_labels.has("changed"), "Compact signals should display only their names.")
	_check(compact_labels.has("resolve"), "Compact methods should display only their names.")
	_check(compact_labels.has("LocalState"), "Inner classes should be visible and navigable.")
	_check(
		compact_labels.has("member use → FixtureHelper.make"),
		"Exact relationship occurrences should be visible as source-navigation actions."
	)
	_check(not compact_labels.has("target: FixtureBase"), "Compact properties must omit types.")
	_check(
		compact_node.title == "PresentationExample",
		"Graph title should contain only the display name."
	)
	_check(
		compact_node.tooltip_text.is_empty(), "The entire GraphNode must not mask child tooltips."
	)
	var path_button: Button = _find_button(compact_node, "Copy")
	_check(
		(
			path_button != null
			and path_button.tooltip_text.contains("res://presentation_example.gd")
			and path_button.tooltip_text.contains("Copy script path")
		),
		"A keyboard-focusable child action should expose and copy the complete script path."
	)
	var compact_method_label: Button = _find_button(compact_node, "resolve")
	_check(
		(
			compact_method_label != null
			and compact_method_label.tooltip_text.begins_with(
				"func resolve(target: FixtureBase) -> FixtureHelper"
			)
			and compact_method_label.tooltip_text.contains(
				"Declaration: res://presentation_example.gd:7:1"
			)
			and compact_method_label.tooltip_text.contains("Incoming exact member references: 2")
			and compact_method_label.tooltip_text.contains("Outgoing dependency occurrences: 3")
			and compact_method_label.tooltip_text.contains(
				"Relationship evidence: direct dependency, type dependency"
			)
			and compact_method_label.tooltip_text.contains("not runtime call counts")
			and compact_method_label.tooltip_text.contains("open the declaration")
		),
		(
			"Member actions should retain full declarations and bounded static-evidence "
			+ "context in their tooltips."
		)
	)
	if compact_method_label != null:
		compact_method_label.pressed.emit()
	_check(
		(
			str(source_request.get("path", "")) == "res://presentation_example.gd"
			and int(source_request.get("line", 0)) == 7
		),
		"Member actions must emit exact script declaration locations."
	)
	var reference_button: Button = _find_button(compact_node, "member use → FixtureHelper.make")
	if reference_button != null:
		reference_button.pressed.emit()
	_check(
		(
			reference_button != null
			and int(source_request.get("line", 0)) == 12
			and int(source_request.get("column", 0)) == 5
		),
		(
			"Relationship actions must open the exact dependency occurrence rather than "
			+ "only the member declaration."
		)
	)
	var scene_button: Button = _find_button(
		compact_node, "↗ presentation_scene.tscn · Root/Consumer"
	)
	if scene_button != null:
		scene_button.pressed.emit()
	_check(
		(
			scene_button != null
			and str(scene_request.get("path", "")) == "res://presentation_scene.tscn"
			and int(scene_request.get("line", 0)) == 8
		),
		"Scene-usage actions must emit the exact scene evidence location."
	)
	_check(
		compact_labels.has("User · Node family · Autoload"),
		"Autoload classification must remain visible without relying on color."
	)
	var compact_panel = compact_node.get_theme_stylebox("panel") as StyleBoxFlat
	_check(
		compact_panel != null and compact_panel.border_color.is_equal_approx(Color("334455")),
		"Inheritance-family color should be applied to the node border."
	)
	_check(
		compact_node.call("port_for_member", {"kind": "method", "name": "resolve"}, "uses", 1) != 1,
		"Visible method rows should expose a dedicated literal-use port."
	)
	_check(
		(
			compact_node.call(
				"port_for_member", {"kind": "property", "name": "target"}, "type_uses", 2
			)
			!= 2
		),
		"Visible property rows should expose a dedicated type-use port."
	)
	compact_node.queue_free()

	var full_node: GraphNode = _graph_node_scene.instantiate()
	root.add_child(full_node)
	(
		full_node
		. call(
			"configure",
			node_data,
			style,
			{
				"show_method_signatures": true,
				"show_signal_signatures": true,
				"show_property_types": true,
			}
		)
	)
	var full_labels: Array[String] = _collect_control_texts(full_node)
	_check(full_labels.has("target: FixtureBase"), "Full properties should display types.")
	_check(full_labels.has("signal changed(value: int)"), "Full signals should display signatures.")
	_check(
		full_labels.has("resolve(target: FixtureBase) -> FixtureHelper"),
		"Full methods should display arguments and return types."
	)
	var property_label: Button = _find_button(full_node, "target: FixtureBase")
	_check(
		property_label != null and property_label.modulate.is_equal_approx(Color("112233")),
		"Property actions should use the configured member color."
	)
	full_node.queue_free()

	var adaptive_node: GraphNode = _graph_node_scene.instantiate()
	root.add_child(adaptive_node)
	var many_methods: Array = []
	for index in range(12):
		(
			many_methods
			. append(
				{
					"name": "method_with_a_descriptive_name_%s" % index,
					"arguments": "value: Dictionary[String, Array[FixtureBase]]",
					"return_type": "FixtureHelper",
				}
			)
		)
	var adaptive_data: Dictionary = node_data.duplicate(true)
	adaptive_data["methods"] = many_methods
	var adaptive_style: Dictionary = style.duplicate(true)
	adaptive_style["graph_max_member_height"] = 520.0
	adaptive_style["graph_max_members_per_section"] = 50
	adaptive_node.call("configure", adaptive_data, adaptive_style, {"show_method_signatures": true})
	_check(
		(
			adaptive_node.custom_minimum_size.x > 240.0
			and adaptive_node.custom_minimum_size.x <= 420.0
		),
		"Script nodes should grow horizontally for longer visible content within configured bounds."
	)
	var adaptive_scroll: ScrollContainer = adaptive_node.get_node("MemberScroll")
	_check(
		adaptive_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"Moderately long classes should grow vertically instead of immediately introducing scrolling."
	)
	adaptive_node.queue_free()

	var overflow_node: GraphNode = _graph_node_scene.instantiate()
	root.add_child(overflow_node)
	var very_many_methods: Array = []
	for index in range(60):
		very_many_methods.append({"name": "method_%s" % index, "arguments": "", "return_type": ""})
	var overflow_data: Dictionary = node_data.duplicate(true)
	overflow_data["methods"] = very_many_methods
	overflow_node.call("configure", overflow_data, adaptive_style, {})
	var overflow_scroll: ScrollContainer = overflow_node.get_node("MemberScroll")
	_check(
		overflow_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO,
		"Very long classes should use bounded scrolling."
	)
	_check(
		(
			overflow_node.call("port_for_member", {"kind": "method", "name": "method_0"}, "uses", 1)
			== 1
		),
		"Scrolled member lists should explicitly fall back to the class-level dependency port."
	)
	overflow_node.queue_free()

	var native_node: GraphNode = _graph_node_scene.instantiate()
	root.add_child(native_node)
	(
		native_node
		. call(
			"configure",
			{
				"name": "Node",
				"kind": "native",
				"path": "",
				"inheritance_family": "node",
				"properties": [],
				"signals": [],
				"methods": [],
			},
			style,
			{}
		)
	)
	_check(native_node.custom_minimum_size.x == 120.0, "Native nodes should use compact width.")
	_check(
		(
			not native_node.get_node("MetadataContent").visible
			and not native_node.get_node("MemberScroll").visible
		),
		"Native nodes should hide empty metadata and member sections."
	)
	native_node.queue_free()


func _test_inheritance_families() -> void:
	var native_bases = {
		"object_script.gd": "SceneTree",
		"ref_counted_script.gd": "Resource",
		"node_script.gd": "CanvasLayer",
		"node_2d_script.gd": "Node2D",
		"node_3d_script.gd": "Node3D",
		"control_script.gd": "Control",
	}
	var scripts: Array = []
	for filename in native_bases:
		var native_base = str(native_bases[filename])
		(
			scripts
			. append(
				{
					"id": "res://" + filename,
					"path": "res://" + filename,
					"name": filename.get_basename(),
					"class_name": "",
					"is_addon": false,
					"analysis":
					{
						"methods": [],
						"signals": [],
						"properties": [],
						"inner_classes": [],
						"resource_dependencies": [],
						"type_references": [],
					},
					"reflection": {"native_base": native_base},
					"direct_base": {"kind": "native", "value": native_base, "display": native_base},
				}
			)
		)
	var builder = _builder_script.new()
	var snapshot: Dictionary = (
		builder
		. build(
			{"scripts": scripts, "warnings": [], "errors": [], "engine_version": "test"},
			{
				"include_native_bases": true,
				"include_external_bases": true,
				"include_methods": true,
				"include_signals": true,
				"include_properties": true,
				"include_resource_dependencies": false,
				"include_type_dependencies": false,
				"style": {},
			}
		)
	)
	var expected = {
		"res://object_script.gd": "object",
		"res://ref_counted_script.gd": "ref_counted",
		"res://node_script.gd": "node",
		"res://node_2d_script.gd": "node_2d",
		"res://node_3d_script.gd": "node_3d",
		"res://control_script.gd": "control",
	}
	for node_id in expected:
		_check(
			_find_node(snapshot, node_id).get("inheritance_family", "") == expected[node_id],
			"Inheritance family should classify %s as %s." % [node_id, expected[node_id]]
		)
	_check(
		(
			_has_edge(snapshot["edges"], "native://SceneTree", "native://MainLoop", "extends")
			and _has_edge(snapshot["edges"], "native://MainLoop", "native://Object", "extends")
		),
		"ClassDB parent traversal should include intermediary native bases for SceneTree."
	)
	_check(
		_has_edge(snapshot["edges"], "native://CanvasLayer", "native://Node", "extends"),
		"ClassDB parent traversal should include intermediary native bases for CanvasLayer."
	)


func _test_depth_layout() -> void:
	var dock: Control = _dock_scene.instantiate()
	root.add_child(dock)
	var snapshot = {
		"nodes":
		[
			{
				"id": "native://Object",
				"name": "Object",
				"kind": "native",
				"properties": [],
				"signals": [],
				"methods": []
			},
			{
				"id": "res://a.gd",
				"name": "A",
				"kind": "user",
				"properties": [],
				"signals": [],
				"methods": []
			},
			{
				"id": "res://b.gd",
				"name": "B",
				"kind": "user",
				"properties": [],
				"signals": [],
				"methods": []
			},
			{
				"id": "res://grandchild.gd",
				"name": "Grandchild",
				"kind": "user",
				"properties": [],
				"signals": [],
				"methods": []
			},
		],
		"edges":
		[
			{"source": "res://a.gd", "target": "native://Object", "kind": "extends"},
			{"source": "res://b.gd", "target": "native://Object", "kind": "extends"},
			{"source": "res://grandchild.gd", "target": "res://a.gd", "kind": "extends"},
		],
	}
	var positions: Dictionary = dock.call("_layout_positions", snapshot)
	_check(
		(
			positions["native://Object"].y < positions["res://a.gd"].y
			and positions["res://a.gd"].y < positions["res://grandchild.gd"].y
		),
		"Default layout should place increasing inheritance depth from top to bottom."
	)
	var a_position: Vector2 = positions["res://a.gd"]
	var b_position: Vector2 = positions["res://b.gd"]
	_check(
		(
			a_position.y < b_position.y
			or (a_position.y == b_position.y and a_position.x < b_position.x)
		),
		"Nodes at the same depth should be ordered deterministically by name."
	)
	dock.queue_free()


func _test_rendered_connection_direction() -> void:
	var dock: Control = _dock_scene.instantiate()
	root.add_child(dock)
	var snapshot = {
		"metadata": {"style": {}, "options": {}},
		"nodes":
		[
			{
				"id": "native://Object",
				"name": "Object",
				"kind": "native",
				"inheritance_family": "object",
				"properties": [],
				"signals": [],
				"methods": [],
			},
			{
				"id": "res://a.gd",
				"name": "A",
				"path": "res://a.gd",
				"kind": "user",
				"inheritance_family": "object",
				"properties": [],
				"signals": [],
				"methods": [],
			},
		],
		"edges": [{"source": "res://a.gd", "target": "native://Object", "kind": "extends"}],
	}
	dock.set("_snapshot", snapshot)
	dock.call("_render_snapshot")
	var graph_edit: GraphEdit = dock.get_node("MainSplit/GraphEdit")
	var connections: Array = graph_edit.get_connection_list()
	var names: Dictionary = dock.get("_id_to_graph_name")
	_check(connections.size() == 1, "Rendered graph should contain the inheritance connection.")
	if connections.size() == 1:
		var connection: Dictionary = connections[0]
		_check(
			(
				str(connection.get("from_node", "")) == str(names["native://Object"])
				and str(connection.get("to_node", "")) == str(names["res://a.gd"])
			),
			(
				"Rendered connection direction should place dependencies/bases before dependents "
				+ "in GraphEdit arrangement."
			)
		)
	graph_edit.arrange_nodes()
	var object_node: GraphNode = graph_edit.get_node(str(names["native://Object"]))
	var script_node: GraphNode = graph_edit.get_node(str(names["res://a.gd"]))
	_check(
		object_node.position_offset.x < script_node.position_offset.x,
		"Godot's built-in arrangement should place Object to the left of its dependent script."
	)
	dock.queue_free()


func _test_member_rendered_connections() -> void:
	var dock: Control = _dock_scene.instantiate()
	root.add_child(dock)
	dock.get("settings").set("show_member_dependency_edges", true)
	var snapshot = {
		"metadata": {"style": {}, "options": {"show_member_dependency_edges": true}},
		"nodes":
		[
			{
				"id": "res://tests/fixtures/child.gd",
				"name": "Source",
				"path": "res://tests/fixtures/child.gd",
				"kind": "user",
				"inheritance_family": "ref_counted",
				"properties": [],
				"signals": [],
				"methods": [{"name": "produce", "arguments": "", "return_type": ""}],
			},
			{
				"id": "res://tests/fixtures/helper.gd",
				"name": "Target",
				"path": "res://tests/fixtures/helper.gd",
				"kind": "user",
				"inheritance_family": "ref_counted",
				"properties": [],
				"signals": [],
				"methods": [{"name": "consume", "arguments": "", "return_type": ""}],
			},
		],
		"edges":
		[
			{
				"source": "res://tests/fixtures/child.gd",
				"target": "res://tests/fixtures/helper.gd",
				"kind": "uses",
				"member_links":
				[
					{
						"source_member": {"kind": "method", "name": "produce"},
						"target_member": {"kind": "method", "name": "consume"},
						"evidence": "class_member_access",
					}
				],
			}
		],
	}
	dock.set("_snapshot", snapshot)
	dock.call("_render_snapshot")
	var graph_edit: GraphEdit = dock.get_node("MainSplit/GraphEdit")
	var connections: Array = graph_edit.get_connection_list()
	_check(connections.size() == 1, "Member-anchored rendering should create one connection.")
	if connections.size() == 1:
		var connection: Dictionary = connections[0]
		_check(
			int(connection.get("from_port", 1)) != 1 and int(connection.get("to_port", 1)) != 1,
			"Member-anchored rendering should connect dedicated member ports instead of class ports."
		)
	dock.queue_free()


func _test_connection_tooltip_evidence() -> void:
	var graph_edit_script = _load_test_script(GRAPH_EDIT_SCRIPT_PATH)
	if graph_edit_script == null:
		return
	var graph_edit: GraphEdit = graph_edit_script.new()
	root.add_child(graph_edit)
	_check(
		graph_edit.has_method("get_closest_connection_at_point"),
		"Supported GraphEdit must expose get_closest_connection_at_point()."
	)
	var nearest_connection: Dictionary = graph_edit.get_closest_connection_at_point(Vector2.ZERO)
	_check(
		nearest_connection is Dictionary,
		"GraphEdit connection lookup must return a Dictionary on supported Godot versions."
	)
	(
		graph_edit
		. call(
			"register_connection_evidence",
			StringName("DependencyNode_1"),
			1,
			StringName("DependencyNode_0"),
			1,
			{
				"kind": "uses",
				"dependent": "res://tests/fixtures/child.gd",
				"dependency": "res://tests/fixtures/helper.gd",
				"source_member": {"kind": "method", "name": "consume"},
				"target_member": {"kind": "method", "name": "make"},
				"source_location": {"line": 14, "column": 3},
				"evidence": "class_member_access",
			}
		)
	)
	var stored: Dictionary = graph_edit.get("_connection_evidence")
	_check(stored.size() == 1, "GraphEdit should retain evidence for one rendered connection.")
	if stored.size() == 1:
		var values: Array = stored.values()[0]
		var tooltip := str(graph_edit.call("_connection_tooltip", values))
		_check(
			(
				tooltip.contains("Direct dependency")
				and tooltip.contains("Dependent: res://tests/fixtures/child.gd")
				and tooltip.contains("Dependency: res://tests/fixtures/helper.gd")
				and tooltip.contains("Canonical direction: dependent → dependency")
				and tooltip.contains("Rendered direction: dependency → dependent (layout only)")
				and tooltip.contains("Exact evidence occurrences represented: 1")
				and tooltip.contains("class-member access")
				and tooltip.contains("source method consume")
				and tooltip.contains("target method make")
				and tooltip.contains("line 14:3")
			),
			(
				"Connection tooltip should explain the exact canonical relationship and bounded "
				+ "occurrence evidence."
			)
		)
	graph_edit.queue_free()


func _test_hidden_member_scope_validation() -> void:
	var validator_script = _load_test_script(VALIDATOR_SCRIPT_PATH)
	var scope_script = _load_test_script(SNAPSHOT_SCOPE_SCRIPT_PATH)
	if validator_script == null or scope_script == null:
		return
	var scanner = _scanner_script.new()
	var scan_result: Dictionary = (
		scanner
		. scan(
			"res://tests/contract_fixtures/hidden_member_scope",
			{
				"include_addons": true,
				"use_runtime_reflection": false,
				"excluded_path_prefixes": PackedStringArray(),
			}
		)
	)
	_check(
		scan_result.get("errors", []).is_empty(),
		"Hidden-member regression fixture scan should not have acquisition errors."
	)
	var builder = _builder_script.new()
	var snapshot: Dictionary = (
		builder
		. build(
			scan_result,
			{
				"include_native_bases": true,
				"include_external_bases": true,
				"include_methods": false,
				"include_signals": true,
				"include_properties": true,
				"include_resource_dependencies": true,
				"include_type_dependencies": true,
				"include_member_access_dependencies": true,
				"show_member_dependency_edges": true,
				"show_method_signatures": false,
				"show_signal_signatures": false,
				"show_property_types": false,
				"style": {},
			}
		)
	)
	var validator = validator_script.new()
	var projector = scope_script.new()
	for root_path in [
		"res://tests/contract_fixtures/hidden_member_scope",
		"res://tests/contract_fixtures/hidden_member_scope/feature",
	]:
		var projected: Dictionary = projector.project(snapshot, root_path)
		var validation: Dictionary = validator.validate(projected)
		_check(
			validation.get("ok", false),
			(
				"Filtered methods must not leave unknown source-member references for selected root %s: %s"
				% [root_path, validation.get("errors", [])]
			)
		)
		for edge_value in projected.get("edges", []):
			if not edge_value is Dictionary:
				continue
			for link_value in (edge_value as Dictionary).get("member_links", []):
				if not link_value is Dictionary:
					continue
				_check(
					(link_value as Dictionary).get("source_member", {}).is_empty(),
					(
						"Hidden methods must be omitted from source-member provenance while exact "
						+ "location/evidence is retained."
					)
				)


func _test_validator_log_rendering() -> void:
	var dock: Control = _dock_scene.instantiate()
	root.add_child(dock)
	var log_view: RichTextLabel = dock.get_node("MainSplit/ControlsTabs/Log/LogView")
	log_view.clear()
	(
		dock
		. call(
			"_on_log_entry",
			{
				"level": "error",
				"message": "Edge source member does not exist on its endpoint node.",
				"context":
				{
					"code": "unknown_member_reference",
					"scan_root": "res://tests/contract_fixtures/hidden_member_scope/feature",
					"issue_index": 0,
					"node_id":
					"res://tests/contract_fixtures/hidden_member_scope/feature/consumer.gd",
					"member": "consume",
				},
			}
		)
	)
	var rendered_log := log_view.get_parsed_text()
	_check(
		(
			rendered_log.contains("unknown_member_reference")
			and rendered_log.contains("res://tests/contract_fixtures/hidden_member_scope/feature")
			and rendered_log.contains(
				"res://tests/contract_fixtures/hidden_member_scope/feature/consumer.gd"
			)
			and rendered_log.contains("consume")
			and rendered_log.contains("Edge source member does not exist")
		),
		(
			"Validator Log rendering should retain the stable code, selected root, affected "
			+ "context, and message."
		)
	)
	dock.queue_free()


func _collect_control_texts(parent: Node) -> Array[String]:
	var values: Array[String] = []
	for child in parent.get_children():
		if child is Label:
			values.append((child as Label).text)
		elif child is Button:
			values.append((child as Button).text)
		values.append_array(_collect_control_texts(child))
	return values


func _find_button(parent: Node, text: String) -> Button:
	for child in parent.get_children():
		if child is Button and (child as Button).text == text:
			return child as Button
		var nested: Button = _find_button(child, text)
		if nested != null:
			return nested
	return null


func _find_label(parent: Node, text: String) -> Label:
	for child in parent.get_children():
		if child is Label and (child as Label).text == text:
			return child as Label
		var nested: Label = _find_label(child, text)
		if nested != null:
			return nested
	return null


func _test_showcase_representations() -> void:
	var json_path: String = "res://examples/showcase/representations/showcase.json"
	var mermaid_path: String = "res://examples/showcase/representations/showcase.mmd"
	var plantuml_path: String = "res://examples/showcase/representations/showcase.puml"
	for path in [json_path, mermaid_path, plantuml_path]:
		_check(FileAccess.file_exists(path), "Showcase representation is missing: %s" % path)
	if not FileAccess.file_exists(json_path):
		return

	var json_text: String = FileAccess.get_file_as_string(json_path)
	var parsed = JSON.parse_string(json_text)
	_check(parsed is Dictionary, "Showcase JSON should parse as a dictionary.")
	if parsed is Dictionary:
		_check(
			(
				_find_node(parsed, "res://examples/showcase/actors/player_actor.gd").get("name", "")
				== "ShowcasePlayerActor"
			),
			"Showcase JSON should contain the player actor."
		)
	var mermaid_text: String = FileAccess.get_file_as_string(mermaid_path)
	_check(
		mermaid_text.begins_with("classDiagram") and mermaid_text.contains("ShowcasePlayerActor"),
		"Showcase Mermaid output should contain a class diagram and player actor."
	)
	var plantuml_text: String = FileAccess.get_file_as_string(plantuml_path)
	_check(
		(
			plantuml_text.contains("@startuml")
			and plantuml_text.contains("ShowcasePlayerActor")
			and plantuml_text.contains("@enduml")
		),
		"Showcase PlantUML output should contain valid markers and the player actor."
	)


func _test_exporters() -> void:
	if _snapshot.is_empty():
		_failures.append("Exporter test has no snapshot.")
		return
	var service = _export_service_script.new()
	var json_result = service.export_to_string("json", _snapshot)
	var mermaid_result = service.export_to_string("mermaid", _snapshot)
	var plantuml_result = service.export_to_string("plantuml", _snapshot)
	_check(
		json_result["ok"] and str(json_result["text"]).contains("schema_version"),
		"JSON export should contain the schema."
	)
	_check(
		mermaid_result["ok"] and str(mermaid_result["text"]).begins_with("classDiagram"),
		"Mermaid export should be a class diagram."
	)
	_check(
		plantuml_result["ok"] and str(plantuml_result["text"]).contains("@startuml"),
		"PlantUML export should contain start/end markers."
	)
	_check(
		(
			str(mermaid_result["text"]).contains("+child_method")
			and not str(mermaid_result["text"]).contains("+child_method()")
		),
		"Compact exports should show method names without full signatures."
	)
	var full_snapshot: Dictionary = _snapshot.duplicate(true)
	full_snapshot["metadata"]["options"]["show_method_signatures"] = true
	full_snapshot["metadata"]["options"]["show_signal_signatures"] = true
	full_snapshot["metadata"]["options"]["show_property_types"] = true
	var full_mermaid = service.export_to_string("mermaid", full_snapshot)
	_check(
		full_mermaid["ok"] and str(full_mermaid["text"]).contains("+child_method()"),
		"Full-signature exports should include method argument lists."
	)
	_check(
		str(mermaid_result["text"]).contains(" type"),
		"Diagram exports should distinguish type-annotation dependencies."
	)
	var member_snapshot: Dictionary = _showcase_snapshot.duplicate(true)
	member_snapshot["metadata"]["options"]["show_member_dependency_edges"] = true
	var member_mermaid = service.export_to_string("mermaid", member_snapshot)
	var member_plantuml = service.export_to_string("plantuml", member_snapshot)
	_check(
		(
			member_plantuml["ok"]
			and str(member_plantuml["text"]).contains("::attack_power ..>")
			and str(member_plantuml["text"]).contains("::calculate_damage : uses")
		),
		"PlantUML should emit exact member-to-member dependency endpoints."
	)
	_check(
		(
			member_mermaid["ok"]
			and str(member_mermaid["text"]).contains("attack_power() to calculate_damage() uses")
		),
		"Mermaid class diagrams should preserve member specificity in the relationship label."
	)
	var scoped_snapshot: Dictionary = _snapshot.duplicate(true)
	if not scoped_snapshot.get("nodes", []).is_empty():
		(scoped_snapshot["nodes"][0] as Dictionary)["scope_role"] = "context"
		var scoped_mermaid = service.export_to_string("mermaid", scoped_snapshot)
		var scoped_plantuml = service.export_to_string("plantuml", scoped_snapshot)
		_check(
			scoped_mermaid["ok"] and str(scoped_mermaid["text"]).contains("(context)"),
			"Mermaid exports must label required out-of-scope context without relying on color."
		)
		_check(
			scoped_plantuml["ok"] and str(scoped_plantuml["text"]).contains("<<context>>"),
			"PlantUML exports must label required out-of-scope context without relying on color."
		)
	var first_json = service.export_to_string("json", _snapshot)["text"]
	var second_json = service.export_to_string("json", _snapshot)["text"]
	_check(first_json == second_json, "Export output should be deterministic.")
	_check(
		not service.export_to_string("unsupported", _snapshot)["ok"],
		"Unsupported formats should fail explicitly."
	)
	var file_result = service.export_to_file("json", "user://dependency_inspector_test", _snapshot)
	_check(
		file_result["ok"] and FileAccess.file_exists(file_result["path"]),
		"Staged file export should create the destination."
	)
	var replacement_result = service.export_to_file(
		"json", "user://dependency_inspector_test", _snapshot
	)
	_check(
		replacement_result["ok"] and FileAccess.file_exists(replacement_result["path"]),
		"Staged file export should replace an existing destination."
	)
	var nested_result = service.export_to_file(
		"json", "user://dependency_inspector_nested/one/two/graph", _snapshot
	)
	_check(
		nested_result["ok"] and FileAccess.file_exists(nested_result["path"]),
		"File export should create missing parent directories for configured automation paths."
	)


func _test_quality_contracts() -> void:
	var resource: Resource = ResourceLoader.load(QUALITY_SUITE_PATH)
	if resource == null or not resource is Script:
		_failures.append("Could not load quality contract suite: %s" % QUALITY_SUITE_PATH)
		return
	var suite = (resource as Script).new()
	if suite == null:
		_failures.append("Could not instantiate quality contract suite.")
		return
	_failures.append_array(suite.run(_showcase_snapshot))


func _test_missing_root_failure() -> void:
	var scanner = _scanner_script.new()
	var result = scanner.scan(
		"res://does_not_exist", {"excluded_path_prefixes": PackedStringArray()}
	)
	_check(not result["errors"].is_empty(), "Missing scan roots should report an explicit error.")


func _find_node(snapshot: Dictionary, node_id: String) -> Dictionary:
	for node_value in snapshot.get("nodes", []):
		var node: Dictionary = node_value
		if str(node.get("id", "")) == node_id:
			return node
	return {}


func _has_edge(edges: Array, source: String, target: String, kind: String) -> bool:
	for edge_value in edges:
		var edge: Dictionary = edge_value
		if edge["source"] == source and edge["target"] == target and edge["kind"] == kind:
			return true
	return false


func _detail_has_source_member(
	details: Array, value_key: String, value: String, member_kind: String, member_name: String
) -> bool:
	for detail_value in details:
		var detail: Dictionary = detail_value
		var source_member: Dictionary = detail.get("source_member", {})
		if (
			str(detail.get(value_key, "")) == value
			and str(source_member.get("kind", "")) == member_kind
			and str(source_member.get("name", "")) == member_name
		):
			return true
	return false


func _access_exists(
	accesses: Array,
	target_symbol: String,
	target_kind: String,
	target_name: String,
	source_kind: String,
	source_name: String
) -> bool:
	for access_value in accesses:
		var access: Dictionary = access_value
		var target_member: Dictionary = access.get("target_member", {})
		var source_member: Dictionary = access.get("source_member", {})
		if (
			str(access.get("target_symbol", "")) == target_symbol
			and str(target_member.get("kind", "")) == target_kind
			and str(target_member.get("name", "")) == target_name
			and str(source_member.get("kind", "")) == source_kind
			and str(source_member.get("name", "")) == source_name
		):
			return true
	return false


func _edge_has_member_link(
	edges: Array,
	source: String,
	target: String,
	kind: String,
	source_kind: String,
	source_name: String,
	target_kind: String,
	target_name: String
) -> bool:
	for edge_value in edges:
		var edge: Dictionary = edge_value
		if (
			str(edge.get("source", "")) != source
			or str(edge.get("target", "")) != target
			or str(edge.get("kind", "")) != kind
		):
			continue
		for link_value in edge.get("member_links", []):
			var link: Dictionary = link_value
			var source_member: Dictionary = link.get("source_member", {})
			var target_member: Dictionary = link.get("target_member", {})
			if (
				str(source_member.get("kind", "")) == source_kind
				and str(source_member.get("name", "")) == source_name
				and str(target_member.get("kind", "")) == target_kind
				and str(target_member.get("name", "")) == target_name
			):
				return true
	return false


func _edge_member_link_has_location(
	edges: Array,
	source: String,
	target: String,
	kind: String,
	source_kind: String,
	source_name: String
) -> bool:
	for edge_value in edges:
		var edge: Dictionary = edge_value
		if (
			str(edge.get("source", "")) != source
			or str(edge.get("target", "")) != target
			or str(edge.get("kind", "")) != kind
		):
			continue
		for link_value in edge.get("member_links", []):
			var link: Dictionary = link_value
			var source_member: Dictionary = link.get("source_member", {})
			var location: Dictionary = link.get("source_location", {})
			if (
				str(source_member.get("kind", "")) == source_kind
				and str(source_member.get("name", "")) == source_name
				and int(location.get("line", 0)) > 0
				and int(location.get("column", 0)) > 0
			):
				return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

extends SceneTree

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const SELF_SCAN_ROOT: String = "res://addons/script_dependency_inspector/"

var _failures: Array[String] = []
var _checks: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scanner_script: Script = _load_script(ADDON_ROOT + "core/project_scanner.gd")
	var builder_script: Script = _load_script(ADDON_ROOT + "core/graph_builder.gd")
	var export_service_script: Script = _load_script(ADDON_ROOT + "export/export_service.gd")
	if scanner_script == null or builder_script == null or export_service_script == null:
		_finish()
		return

	var scanner = scanner_script.new()
	var builder = builder_script.new()
	var export_service = export_service_script.new()
	var scan_result: Dictionary = (
		scanner
		. scan(
			SELF_SCAN_ROOT,
			{
				"include_addons": true,
				"use_runtime_reflection": false,
				"excluded_path_prefixes": PackedStringArray(),
			}
		)
	)
	_check(scan_result.get("errors", []).is_empty(), "Self-scan must complete without errors.")
	_check(
		scan_result.get("scripts", []).size() >= 16,
		"Self-scan should include all production scripts."
	)
	if not scan_result.get("errors", []).is_empty():
		_finish()
		return

	for scenario_value in _scenarios():
		var scenario: Dictionary = scenario_value
		var snapshot: Dictionary = builder.build(scan_result, scenario["options"])
		_check(snapshot.get("errors", []).is_empty(), "%s graph build failed." % scenario["name"])
		for include_colors in [false, true]:
			for format_id in ["json", "mermaid", "plantuml"]:
				var result: Dictionary = export_service.export_to_string(
					format_id, snapshot, {"include_colors": include_colors}
				)
				var label: String = (
					"%s/%s/colors=%s" % [scenario["name"], format_id, include_colors]
				)
				_check(
					bool(result.get("ok", false)),
					"%s export failed: %s" % [label, result.get("error", "")]
				)
				if not bool(result.get("ok", false)):
					continue
				var text: String = str(result.get("text", ""))
				match format_id:
					"json":
						_validate_json(text, label)
					"mermaid":
						_validate_mermaid(text, label, include_colors)
					"plantuml":
						_validate_plantuml(text, label, include_colors)
		if str(scenario["name"]) == "all_options_enabled":
			_validate_all_on_regression(export_service, snapshot)

	_validate_file_extensions(export_service, builder.build(scan_result, _all_options()))
	_finish()


func _scenarios() -> Array:
	return [
		{"name": "classes_only", "options": _options({})},
		{
			"name": "compact_members",
			"options":
			_options(
				{"include_methods": true, "include_signals": true, "include_properties": true}
			),
		},
		{
			"name": "full_signatures",
			"options":
			_options(
				{
					"include_methods": true,
					"include_signals": true,
					"include_properties": true,
					"show_method_signatures": true,
					"show_signal_signatures": true,
					"show_property_types": true,
				}
			),
		},
		{
			"name": "literal_dependencies",
			"options": _options({"include_resource_dependencies": true}),
		},
		{
			"name": "type_dependencies",
			"options": _options({"include_type_dependencies": true}),
		},
		{
			"name": "member_dependencies",
			"options":
			_options(
				{
					"include_methods": true,
					"include_member_access_dependencies": true,
					"show_member_dependency_edges": true,
				}
			),
		},
		{
			"name": "native_and_external_bases",
			"options": _options({"include_native_bases": true, "include_external_bases": true}),
		},
		{"name": "all_options_enabled", "options": _all_options()},
	]


func _options(overrides: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"include_native_bases": false,
		"include_external_bases": false,
		"include_methods": false,
		"include_signals": false,
		"include_properties": false,
		"include_resource_dependencies": false,
		"include_type_dependencies": false,
		"include_member_access_dependencies": false,
		"show_member_dependency_edges": false,
		"show_method_signatures": false,
		"show_signal_signatures": false,
		"show_property_types": false,
		"style": _style(),
	}
	for key in overrides:
		result[key] = overrides[key]
	return result


func _all_options() -> Dictionary:
	return _options(
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
			"show_method_signatures": true,
			"show_signal_signatures": true,
			"show_property_types": true,
		}
	)


func _style() -> Dictionary:
	return {
		"user_script_color": "0072b2",
		"addon_script_color": "cc79a7",
		"native_class_color": "6f7682",
		"external_class_color": "e69f00",
	}


func _validate_json(text: String, label: String) -> void:
	var parsed = JSON.parse_string(text)
	_check(parsed is Dictionary, "%s must parse as a JSON object." % label)
	if parsed is Dictionary:
		_check(
			parsed.has("nodes") and parsed.has("edges"),
			"%s must preserve the canonical graph." % label
		)


func _validate_mermaid(text: String, label: String, include_colors: bool) -> void:
	var lines: PackedStringArray = text.split("\n", false)
	_check(
		lines.size() >= 2 and lines[0] == "classDiagram", "%s must begin with classDiagram." % label
	)
	_check(
		lines.size() >= 2 and lines[1].begins_with("direction "),
		"%s must declare diagram direction." % label
	)
	var aliases: Dictionary = {}
	var class_depth: int = 0
	for line_value in lines:
		var line: String = str(line_value).strip_edges()
		if line.begins_with("class C_") and line.contains("["):
			var alias: String = line.trim_prefix("class ").get_slice("[", 0)
			aliases[alias] = true
			class_depth += 1
		elif line == "}":
			class_depth -= 1
		elif line.begins_with("+"):
			_check(
				not line.contains("{"),
				"%s contains an unsafe Mermaid member opening brace: %s" % [label, line]
			)
			_check(
				not line.contains("}"),
				"%s contains an unsafe Mermaid member closing brace: %s" % [label, line]
			)
			_check(
				not line.contains(" = "),
				"%s leaked a GDScript default expression: %s" % [label, line]
			)
		elif line.contains(" --|> ") or line.contains(" ..> "):
			var tokens: PackedStringArray = line.split(" ", false)
			_check(tokens.size() >= 3, "%s contains a malformed relation: %s" % [label, line])
			if tokens.size() >= 3:
				_check(
					aliases.has(tokens[0]),
					"%s relation source is undeclared: %s" % [label, tokens[0]]
				)
				_check(
					aliases.has(tokens[2]),
					"%s relation target is undeclared: %s" % [label, tokens[2]]
				)
	_check(class_depth == 0, "%s has unbalanced class member blocks." % label)
	_check(
		text.contains("classDef ") == include_colors,
		"%s color directives do not match export options." % label
	)


func _validate_plantuml(text: String, label: String, include_colors: bool) -> void:
	var lines: PackedStringArray = text.split("\n", false)
	_check(
		not lines.is_empty() and lines[0] == "@startuml", "%s must begin with @startuml." % label
	)
	_check(
		not lines.is_empty() and lines[lines.size() - 1] == "@enduml",
		"%s must end with @enduml." % label
	)
	var aliases: Dictionary = {}
	var class_depth: int = 0
	for line_value in lines:
		var line: String = str(line_value).strip_edges()
		if line.begins_with("class ") and line.contains(" as C_"):
			var alias_part: String = line.get_slice(" as ", 1)
			var alias: String = alias_part.get_slice(" ", 0)
			aliases[alias] = true
			class_depth += 1
		elif line == "}":
			class_depth -= 1
		elif line.begins_with("+"):
			_check(
				not line.contains(" = "),
				"%s leaked a GDScript default expression: %s" % [label, line]
			)
		elif line.contains(" --|> ") or line.contains(" ..> "):
			var source: String = line.get_slice(" ", 0).get_slice("::", 0)
			var relation_tokens: PackedStringArray = line.split(" ", false)
			var target: String = (
				relation_tokens[2].get_slice("::", 0) if relation_tokens.size() >= 3 else ""
			)
			_check(aliases.has(source), "%s relation source is undeclared: %s" % [label, source])
			_check(aliases.has(target), "%s relation target is undeclared: %s" % [label, target])
	_check(class_depth == 0, "%s has unbalanced class member blocks." % label)
	var colored_class_count: int = 0
	for line_value in lines:
		var line: String = str(line_value).strip_edges()
		if line.begins_with("class ") and line.contains(" #"):
			colored_class_count += 1
	_check(
		(colored_class_count > 0) == include_colors,
		"%s class colors do not match export options." % label
	)


func _validate_all_on_regression(export_service, snapshot: Dictionary) -> void:
	var mermaid: Dictionary = export_service.export_to_string(
		"mermaid", snapshot, {"include_colors": true}
	)
	var plantuml: Dictionary = export_service.export_to_string(
		"plantuml", snapshot, {"include_colors": true}
	)
	var expected_mermaid: String = "+export_text(_snapshot: Dictionary, _options: Dictionary) String"
	var expected_plantuml: String = "+export_text(_snapshot: Dictionary, _options: Dictionary) : String"
	_check(
		str(mermaid.get("text", "")).contains(expected_mermaid),
		"All-on Mermaid export must retain typed parameters while omitting dictionary defaults."
	)
	_check(
		str(plantuml.get("text", "")).contains(expected_plantuml),
		"All-on PlantUML export must retain typed parameters while omitting dictionary defaults."
	)
	_check(
		not str(mermaid.get("text", "")).contains("Dictionary = {}"),
		"Mermaid regression: dictionary defaults must not terminate class blocks."
	)
	_check(
		not str(plantuml.get("text", "")).contains("Dictionary = {}"),
		"PlantUML regression: dictionary defaults must not terminate class blocks."
	)


func _validate_file_extensions(export_service, snapshot: Dictionary) -> void:
	for format_id in ["json", "mermaid", "plantuml"]:
		var extension: String = str(export_service.extension_for(format_id))
		var result: Dictionary = export_service.export_to_file(
			format_id,
			"user://script_dependency_inspector_export_matrix.gd",
			snapshot,
			{"include_colors": true}
		)
		_check(bool(result.get("ok", false)), "%s file export failed." % format_id)
		if bool(result.get("ok", false)):
			var path: String = str(result.get("path", ""))
			_check(
				path.ends_with("." + extension),
				"%s file export used the wrong extension: %s" % [format_id, path]
			)
			_check(
				not path.contains(".gd."),
				"%s export appended to an unsafe source extension: %s" % [format_id, path]
			)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _load_script(path: String) -> Script:
	if not FileAccess.file_exists(path):
		_failures.append("Missing required test dependency: %s" % path)
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource == null or not resource is Script:
		_failures.append("Could not load required test dependency: %s" % path)
		return null
	return resource as Script


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Export matrix passed: %s checks across JSON, Mermaid, and PlantUML." % _checks)
		quit(0)
		return
	push_error("Export matrix failed: %s issue(s), %s checks." % [_failures.size(), _checks])
	for failure in _failures:
		push_error("- %s" % failure)
	quit(1)

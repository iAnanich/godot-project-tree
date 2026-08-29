@tool
extends RefCounted

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const ANALYZER_SCRIPT_PATH: String = ADDON_ROOT + "core/gdscript_analyzer.gd"
const SCENE_USAGE_SCANNER_SCRIPT_PATH: String = ADDON_ROOT + "core/scene_usage_scanner.gd"
const COMPAT_SCRIPT_PATH: String = ADDON_ROOT + "core/compat.gd"

var logger: RefCounted
var _analyzer
var _scene_usage_scanner
var _compat_script: Script
var _dependency_errors: Array[String] = []


func _init() -> void:
	var analyzer_script = _load_required_script(ANALYZER_SCRIPT_PATH, "source analyzer")
	var scene_usage_scanner_script = _load_required_script(
		SCENE_USAGE_SCANNER_SCRIPT_PATH, "scene usage scanner"
	)
	_compat_script = _load_required_script(COMPAT_SCRIPT_PATH, "compatibility shim")
	if analyzer_script != null:
		_analyzer = analyzer_script.new()
		if _analyzer == null:
			_record_dependency_error(
				"Could not instantiate source analyzer script: %s" % ANALYZER_SCRIPT_PATH
			)
	if scene_usage_scanner_script != null:
		_scene_usage_scanner = scene_usage_scanner_script.new()
		if _scene_usage_scanner == null:
			_record_dependency_error(
				"Could not instantiate scene usage scanner: %s" % SCENE_USAGE_SCANNER_SCRIPT_PATH
			)


## Returns failures encountered while loading required scanner dependencies.
func initialization_errors() -> Array[String]:
	return _dependency_errors.duplicate()


## Validates and normalizes a project-local directory before it is accepted as
## a user-visible analysis scope. FileDialog may return either a res:// path or
## an absolute filesystem path; absolute paths are localized only when they are
## inside the current project.
func validate_root(root_path: String) -> Dictionary:
	var normalization: Dictionary = _normalize_scan_root(root_path)
	var normalized: String = str(normalization.get("root", ""))
	var error: String = str(normalization.get("error", ""))
	if (
		error.is_empty()
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(normalized))
	):
		error = "Scan root does not exist: %s" % normalized
	return {"ok": error.is_empty(), "root": normalized, "error": error}


## Recursively scans GDScript files under root_path and resolves each script's
## direct base using source declarations, the project global-class registry,
## and ClassDB. It does not load analyzed project scripts as Script resources.
func scan(root_path: String = "res://", options: Dictionary = {}) -> Dictionary:
	var resolved_options = _with_defaults(options)
	var root_validation: Dictionary = validate_root(root_path)
	var normalized_root: String = str(root_validation.get("root", ""))
	var result = {
		"root_path": normalized_root,
		"scripts": [],
		"scene_usages": [],
		"warnings": [],
		"errors": _dependency_errors.duplicate(),
		"diagnostics": [],
		"engine_version": _engine_version_string(),
	}
	var root_error: String = str(root_validation.get("error", ""))
	if not root_error.is_empty():
		result["errors"].append(root_error)
		(
			result["diagnostics"]
			. append(
				{
					"severity": "error",
					"code": "invalid_scan_root",
					"message": root_error,
					"context": {"root": root_path},
				}
			)
		)
		_log_error(root_error, {"root": root_path, "code": "invalid_scan_root"})
		_finalize_diagnostics(result)
		return result
	if not result["errors"].is_empty():
		_log_error(
			"Project scan cannot start because required plugin scripts are unavailable.",
			{"errors": result["errors"]}
		)
		_finalize_diagnostics(result)
		return result

	var files_result = _collect_project_files(normalized_root, resolved_options)
	result["warnings"].append_array(files_result["warnings"])
	result["errors"].append_array(files_result["errors"])
	if not result["errors"].is_empty():
		_log_error(
			"Project scan could not enumerate its root.",
			{"root": root_path, "errors": result["errors"]}
		)
		_finalize_diagnostics(result)
		return result

	var records: Array = []
	var path_index = {}
	var class_index = {}
	var global_classes = _global_class_index()
	var autoload_index: Dictionary = _autoload_index()

	for script_path_value in files_result["script_files"]:
		var script_path = str(script_path_value)
		var source_result = _read_text_file(
			script_path, int(resolved_options["maximum_script_bytes"])
		)
		if not source_result["ok"]:
			var read_warning = (
				"Could not read script %s: %s" % [script_path, source_result["error"]]
			)
			result["warnings"].append(read_warning)
			_log_warning(read_warning)
			continue

		var analysis: Dictionary = _analyzer.analyze(source_result["text"], script_path)
		result["warnings"].append_array(analysis.get("warnings", []))

		var display_name = str(analysis["class_name"])
		if display_name.is_empty():
			display_name = script_path.get_file().get_basename()

		var autoload: Dictionary = autoload_index.get(script_path.simplify_path(), {}).duplicate(
			true
		)
		var record = {
			"id": script_path,
			"path": script_path,
			"name": display_name,
			"class_name": str(analysis["class_name"]),
			"is_addon": script_path.begins_with("res://addons/"),
			"autoload": autoload,
			"analysis": analysis,
			"reflection": {},
			"direct_base": {"kind": "none", "value": "", "display": ""},
		}
		records.append(record)
		path_index[script_path] = record
		if not str(record["class_name"]).is_empty():
			var registered_name = str(record["class_name"])
			if class_index.has(registered_name):
				result["warnings"].append(
					(
						"Duplicate class_name '%s' in %s and %s."
						% [registered_name, class_index[registered_name]["path"], script_path]
					)
				)
			else:
				class_index[registered_name] = record

	for record_value in records:
		var record: Dictionary = record_value
		record["direct_base"] = _resolve_direct_base(
			record, path_index, class_index, global_classes
		)

	records.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return str(left["path"]) < str(right["path"])
	)
	result["scripts"] = records
	if resolved_options["include_scene_usages"] and _scene_usage_scanner != null:
		var scene_result: Dictionary = _scene_usage_scanner.call(
			"scan",
			files_result.get("scene_files", []),
			int(resolved_options["maximum_scene_bytes"])
		)
		result["scene_usages"] = scene_result.get("usages", [])
		result["warnings"].append_array(scene_result.get("warnings", []))
	_log_info(
		"Project scan completed.",
		{"root": root_path, "scripts": records.size(), "warnings": result["warnings"].size()}
	)
	_finalize_diagnostics(result)
	return result


func _finalize_diagnostics(result: Dictionary) -> void:
	var diagnostics: Array = result.get("diagnostics", [])
	var known_messages: Dictionary = {}
	for diagnostic_value in diagnostics:
		if diagnostic_value is Dictionary:
			known_messages[str((diagnostic_value as Dictionary).get("message", ""))] = true
	for message_value in result.get("warnings", []):
		var message = str(message_value)
		if not known_messages.has(message):
			(
				diagnostics
				. append(
					{
						"severity": "warning",
						"code": "scan_warning",
						"message": message,
						"context": {},
					}
				)
			)
	for message_value in result.get("errors", []):
		var message = str(message_value)
		if not known_messages.has(message):
			(
				diagnostics
				. append(
					{
						"severity": "error",
						"code": "scan_error",
						"message": message,
						"context": {},
					}
				)
			)
	result["diagnostics"] = diagnostics


func _normalize_scan_root(root_path: String) -> Dictionary:
	var stripped: String = root_path.strip_edges()
	if stripped.is_empty():
		return {"root": "", "error": "Scan root is empty; expected a project folder."}
	var normalized_separators: String = stripped.replace("\\", "/")
	for segment in normalized_separators.split("/", false):
		if segment == "..":
			return {
				"root": "",
				"error": "Scan root must not contain parent traversal segments: %s" % root_path,
			}

	var normalized: String = normalized_separators.simplify_path()
	if normalized.is_absolute_path():
		normalized = ProjectSettings.localize_path(normalized).replace("\\", "/").simplify_path()
	var error: String = _validate_scan_root(root_path, normalized)
	return {"root": normalized, "error": error}


func _validate_scan_root(original_root: String, normalized_root: String) -> String:
	if normalized_root != "res://" and not normalized_root.begins_with("res://"):
		return "Scan root must be inside the current project (res://): %s" % original_root
	return ""


func _with_defaults(options: Dictionary) -> Dictionary:
	var defaults = {
		"include_addons": true,
		"follow_symbolic_links": false,
		"maximum_scanned_files": 10000,
		"maximum_scanned_directories": 20000,
		"maximum_script_bytes": 4194304,
		"maximum_scene_bytes": 8388608,
		"include_scene_usages": true,
		"excluded_path_prefixes":
		PackedStringArray(["res://.godot/", "res://addons/script_dependency_inspector/"]),
	}
	for key in options:
		defaults[key] = options[key]
	return defaults


func _collect_project_files(root_path: String, options: Dictionary) -> Dictionary:
	var output = {"script_files": [], "scene_files": [], "warnings": [], "errors": []}
	var normalized_root = root_path.simplify_path()
	var absolute_root = ProjectSettings.globalize_path(normalized_root)
	if not DirAccess.dir_exists_absolute(absolute_root):
		output["errors"].append("Scan root does not exist: %s" % normalized_root)
		return output
	var pending: Array = [normalized_root]
	var visited = {}
	var maximum_files = maxi(1, int(options["maximum_scanned_files"]))
	var maximum_directories = maxi(1, int(options["maximum_scanned_directories"]))
	var scanned_directories = 0
	var accepted_files = 0

	while not pending.is_empty():
		var current_path = str(pending.pop_back()).simplify_path()
		if visited.has(current_path):
			continue
		visited[current_path] = true
		if _is_excluded(current_path, options):
			continue

		scanned_directories += 1
		if scanned_directories > maximum_directories:
			output["warnings"].append(
				"Scan stopped at maximum_scanned_directories=%s." % maximum_directories
			)
			break

		var directory = DirAccess.open(current_path)
		if directory == null:
			_record_directory_failure(
				output, current_path, normalized_root, "Cannot open directory: %s" % current_path
			)
			continue
		var begin_error = directory.list_dir_begin()
		if begin_error != OK:
			_record_directory_failure(
				output,
				current_path,
				normalized_root,
				"Cannot enumerate directory: %s (error %s)" % [current_path, begin_error]
			)
			continue

		var entry = directory.get_next()
		while not entry.is_empty():
			if entry != "." and entry != "..":
				var entry_path = current_path.path_join(entry).simplify_path()
				if directory.is_link(entry) and not bool(options["follow_symbolic_links"]):
					output["warnings"].append("Skipped symbolic link: %s" % entry_path)
					entry = directory.get_next()
					continue
				if directory.current_is_dir():
					if not _is_excluded(entry_path + "/", options):
						pending.append(entry_path)
				elif not _is_excluded(entry_path, options):
					var extension = entry_path.get_extension().to_lower()
					if extension == "gd":
						if options["include_addons"] or not entry_path.begins_with("res://addons/"):
							output["script_files"].append(entry_path)
							accepted_files += 1
					elif extension == "tscn" and bool(options["include_scene_usages"]):
						if options["include_addons"] or not entry_path.begins_with("res://addons/"):
							output["scene_files"].append(entry_path)
							accepted_files += 1
					if accepted_files >= maximum_files:
						output["warnings"].append(
							"Scan stopped at maximum_scanned_files=%s." % maximum_files
						)
						directory.list_dir_end()
						output["script_files"].sort()
						output["scene_files"].sort()
						return output
			entry = directory.get_next()
		directory.list_dir_end()

	output["script_files"].sort()
	output["scene_files"].sort()
	return output


func _record_directory_failure(
	output: Dictionary, path: String, root_path: String, message: String
) -> void:
	if path == root_path:
		output["errors"].append(message)
	else:
		output["warnings"].append(message)


func _is_excluded(path: String, options: Dictionary) -> bool:
	var normalized = path.simplify_path().trim_suffix("/")
	for prefix_value in options["excluded_path_prefixes"]:
		var normalized_prefix = str(prefix_value).simplify_path().trim_suffix("/")
		if normalized == normalized_prefix or normalized.begins_with(normalized_prefix + "/"):
			return true
	return false


func _read_text_file(path: String, maximum_bytes: int) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "text": "", "error": FileAccess.get_open_error()}
	var length = file.get_length()
	if length > maximum_bytes:
		file.close()
		return {
			"ok": false,
			"text": "",
			"error": "file is %s bytes; limit is %s" % [length, maximum_bytes]
		}
	var text = file.get_as_text()
	file.close()
	return {"ok": true, "text": text, "error": OK}


func _global_class_index() -> Dictionary:
	var index = {}
	if not ProjectSettings.has_method("get_global_class_list"):
		return index
	for entry_value in ProjectSettings.get_global_class_list():
		var entry: Dictionary = entry_value
		var registered_name = str(entry.get("class", ""))
		if not registered_name.is_empty():
			index[registered_name] = entry.duplicate(true)
	return index


func _resolve_direct_base(
	record: Dictionary, path_index: Dictionary, class_index: Dictionary, global_classes: Dictionary
) -> Dictionary:
	var analysis: Dictionary = record["analysis"]
	var resolved: Dictionary = {}
	var parsed_base: Dictionary = analysis["extends"]
	match str(parsed_base.get("kind", "none")):
		"path":
			resolved = _resolve_path_base(
				str(parsed_base["value"]), str(record["path"]), path_index, global_classes
			)
		"symbol":
			resolved = _resolve_symbol_base(
				str(parsed_base["value"]), path_index, class_index, global_classes
			)
		"unresolved":
			resolved = {
				"kind": "unresolved",
				"value": str(parsed_base["value"]),
				"display": str(parsed_base["value"]),
			}

	if resolved.is_empty():
		resolved = {"kind": "native", "value": "RefCounted", "display": "RefCounted"}
	return resolved


func _resolve_symbol_base(
	symbol: String, path_index: Dictionary, class_index: Dictionary, global_classes: Dictionary
) -> Dictionary:
	var resolved: Dictionary
	if class_index.has(symbol):
		resolved = {
			"kind": "script",
			"value": str(class_index[symbol]["path"]),
			"display": symbol,
		}
	elif global_classes.has(symbol):
		var global_entry: Dictionary = global_classes[symbol]
		var global_path = str(global_entry.get("path", ""))
		if path_index.has(global_path):
			resolved = {"kind": "script", "value": global_path, "display": symbol}
		else:
			resolved = {
				"kind": "external_script",
				"value": global_path if not global_path.is_empty() else symbol,
				"display": symbol,
				"native_base": str(global_entry.get("base", "")),
			}
	elif ClassDB.class_exists(symbol):
		resolved = {"kind": "native", "value": symbol, "display": symbol}
	else:
		resolved = {
			"kind": "unresolved",
			"value": symbol,
			"display": symbol,
			"native_base": "",
		}
	return resolved


func _resolve_path_base(
	base_path: String, owner_path: String, path_index: Dictionary, global_classes: Dictionary
) -> Dictionary:
	var normalized = _normalize_dependency_path(base_path, owner_path)
	if path_index.has(normalized):
		return {
			"kind": "script", "value": normalized, "display": str(path_index[normalized]["name"])
		}
	var display = normalized.get_file().get_basename()
	for registered_name in global_classes:
		var entry: Dictionary = global_classes[registered_name]
		if str(entry.get("path", "")) == normalized:
			return {
				"kind": "external_script",
				"value": normalized,
				"display": str(registered_name),
				"native_base": str(entry.get("base", "")),
			}
	return {"kind": "external_script", "value": normalized, "display": display, "native_base": ""}


func _normalize_dependency_path(dependency_path: String, owner_path: String) -> String:
	var value = dependency_path.strip_edges()
	if value.begins_with("res://") or value.begins_with("user://"):
		return value.simplify_path()
	return owner_path.get_base_dir().path_join(value).simplify_path()


func _load_required_script(path: String, role: String) -> Script:
	if not FileAccess.file_exists(path):
		_record_dependency_error("Missing %s script: %s" % [role, path])
		return null
	var resource = ResourceLoader.load(path)
	if resource == null or not resource is Script:
		_record_dependency_error("Could not load %s script: %s" % [role, path])
		return null
	return resource as Script


func _record_dependency_error(message: String) -> void:
	if not _dependency_errors.has(message):
		_dependency_errors.append(message)
	push_error(message)


func _autoload_index() -> Dictionary:
	var index: Dictionary = {}
	for property_value in ProjectSettings.get_property_list():
		if not property_value is Dictionary:
			continue
		var property: Dictionary = property_value
		var setting_name = str(property.get("name", ""))
		if not setting_name.begins_with("autoload/"):
			continue
		var configured_value = str(ProjectSettings.get_setting(setting_name, ""))
		var singleton = configured_value.begins_with("*")
		var configured_path = configured_value.trim_prefix("*").simplify_path()
		if configured_path.is_empty():
			continue
		index[configured_path] = {
			"name": setting_name.trim_prefix("autoload/"),
			"singleton": singleton,
		}
	return index


func _engine_version_string() -> String:
	if _compat_script != null:
		return str(_compat_script.call("engine_version_string"))
	var info = Engine.get_version_info()
	if info.has("string"):
		return str(info["string"])
	return "%s.%s.%s" % [info.get("major", 4), info.get("minor", 0), info.get("patch", 0)]


func _log_info(message: String, context: Dictionary = {}) -> void:
	if logger != null and logger.has_method("info"):
		logger.call("info", message, context)


func _log_warning(message: String, context: Dictionary = {}) -> void:
	if logger != null and logger.has_method("warning"):
		logger.call("warning", message, context)


func _log_error(message: String, context: Dictionary = {}) -> void:
	if logger != null and logger.has_method("error"):
		logger.call("error", message, context)

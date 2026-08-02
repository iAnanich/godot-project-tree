@tool
extends RefCounted

const ADDON_ROOT: String = "res://addons/script_dependency_inspector/"
const EXPORTER_BASE_SCRIPT_PATH: String = ADDON_ROOT + "export/exporter.gd"
const SNAPSHOT_VALIDATOR_SCRIPT_PATH: String = ADDON_ROOT + "core/snapshot_validator.gd"
const JSON_EXPORTER_SCRIPT_PATH: String = ADDON_ROOT + "export/json_exporter.gd"
const MERMAID_EXPORTER_SCRIPT_PATH: String = ADDON_ROOT + "export/mermaid_exporter.gd"
const PLANTUML_EXPORTER_SCRIPT_PATH: String = ADDON_ROOT + "export/plantuml_exporter.gd"

var logger: RefCounted
var _exporters: Dictionary = {}
var _validator
var _initialization_errors: Array[String] = []


func _init() -> void:
	if not _validate_required_script(EXPORTER_BASE_SCRIPT_PATH, "exporter base"):
		return
	var validator_script: Script = _load_required_script(
		SNAPSHOT_VALIDATOR_SCRIPT_PATH, "snapshot validator"
	)
	if validator_script != null:
		_validator = validator_script.new()
		if _validator == null:
			_record_initialization_error(
				"Could not instantiate snapshot validator script: %s" % SNAPSHOT_VALIDATOR_SCRIPT_PATH
			)
	_register_exporter_script(JSON_EXPORTER_SCRIPT_PATH, "JSON")
	_register_exporter_script(MERMAID_EXPORTER_SCRIPT_PATH, "Mermaid")
	_register_exporter_script(PLANTUML_EXPORTER_SCRIPT_PATH, "PlantUML")


## Returns failures encountered while loading built-in exporter scripts.
func initialization_errors() -> Array[String]:
	return _initialization_errors.duplicate()


func _validate_required_script(path: String, display_name: String) -> bool:
	return _load_required_script(path, display_name) != null


func _load_required_script(path: String, display_name: String) -> Script:
	if not FileAccess.file_exists(path):
		_record_initialization_error("Missing %s script: %s" % [display_name, path])
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource == null or not resource is Script:
		_record_initialization_error("Could not load %s script: %s" % [display_name, path])
		return null
	return resource as Script


func _register_exporter_script(path: String, display_name: String) -> void:
	var exporter_script: Script = _load_required_script(path, "%s exporter" % display_name)
	if exporter_script == null:
		return
	var exporter = exporter_script.new()
	if exporter == null:
		_record_initialization_error(
			"Could not instantiate %s exporter script: %s" % [display_name, path]
		)
		return
	register_exporter(exporter)


func _record_initialization_error(message: String) -> void:
	if not _initialization_errors.has(message):
		_initialization_errors.append(message)
	push_error(message)


## Registers an exporter implementing the documented exporter contract.
## Invalid or duplicate registrations are rejected without replacing a valid exporter.
func register_exporter(exporter) -> bool:
	var validation: Dictionary = _validate_exporter_contract(exporter)
	if not validation.get("ok", false):
		_log_error(
			str(validation.get("error", "Invalid dependency graph exporter registration.")),
			{
				"code": str(validation.get("code", "invalid_exporter")),
				"context": validation.get("context", {}),
			}
		)
		return false
	var format_id: String = str(validation["format_id"])
	if _exporters.has(format_id):
		_log_error(
			"Exporter format is already registered: %s" % format_id,
			{"code": "duplicate_exporter", "format": format_id}
		)
		return false
	_exporters[format_id] = exporter
	return true


func _validate_exporter_contract(exporter) -> Dictionary:
	if exporter == null:
		return _exporter_validation_failure("invalid_exporter", "Exporter instance is null.")
	for method_name in ["format_id", "display_name", "file_extension", "capabilities", "export_text"]:
		if not exporter.has_method(method_name):
			return _exporter_validation_failure(
				"missing_exporter_method",
				"Exporter is missing required method: %s" % method_name,
				{"method": method_name}
			)
	var raw_format_id: String = str(exporter.call("format_id")).strip_edges()
	var display_name: String = str(exporter.call("display_name")).strip_edges()
	var extension: String = str(exporter.call("file_extension")).strip_edges()
	var capabilities_value = exporter.call("capabilities")
	if raw_format_id.is_empty() or raw_format_id != raw_format_id.to_lower():
		return _exporter_validation_failure(
			"invalid_exporter_id",
			"Exporter format_id must be non-empty lowercase text.",
			{"format_id": raw_format_id}
		)
	if display_name.is_empty():
		return _exporter_validation_failure(
			"invalid_exporter_name", "Exporter display_name must not be empty."
		)
	if extension.is_empty() or extension.begins_with(".") or extension.contains("/") or extension.contains("\\"):
		return _exporter_validation_failure(
			"invalid_exporter_extension",
			"Exporter file_extension must omit the period and path separators.",
			{"extension": extension}
		)
	if not capabilities_value is Dictionary:
		return _exporter_validation_failure(
			"invalid_exporter_capabilities", "Exporter capabilities must be a dictionary."
		)
	var capabilities: Dictionary = capabilities_value
	for capability in _required_capabilities():
		if not capabilities.has(capability) or not capabilities[capability] is bool:
			return _exporter_validation_failure(
				"invalid_exporter_capability",
				"Exporter capability '%s' must be declared as a boolean." % capability,
				{"capability": capability}
			)
	return {
		"ok": true,
		"code": "ok",
		"format_id": raw_format_id,
		"display_name": display_name,
		"extension": extension,
		"capabilities": capabilities.duplicate(true),
	}


func _required_capabilities() -> Array[String]:
	return [
		"colors",
		"class_members",
		"structured_member_links",
		"exact_member_endpoints",
		"member_relation_labels",
	]


func _exporter_validation_failure(
	code: String, message: String, context: Dictionary = {}
) -> Dictionary:
	return {
		"ok": false,
		"code": code,
		"error": message,
		"context": context.duplicate(true),
	}


## Returns sorted descriptors for UI format selection and capability discovery.
func format_descriptors() -> Array:
	var result: Array = []
	var ids: Array = _exporters.keys()
	ids.sort()
	for format_id_value in ids:
		var exporter = _exporters[format_id_value]
		result.append(
			{
				"id": str(format_id_value),
				"name": str(exporter.call("display_name")),
				"extension": str(exporter.call("file_extension")),
				"capabilities": (exporter.call("capabilities") as Dictionary).duplicate(true),
			}
		)
	return result


## Returns the declared capabilities for format_id, or an empty dictionary.
func capabilities_for(format_id: String) -> Dictionary:
	if not _exporters.has(format_id):
		return {}
	var value = _exporters[format_id].call("capabilities")
	return value.duplicate(true) if value is Dictionary else {}


## Returns the exporter extension, or txt for an unknown format.
func extension_for(format_id: String) -> String:
	if not _exporters.has(format_id):
		return "txt"
	return str(_exporters[format_id].call("file_extension"))


## Validates and serializes a graph without writing it.
func export_to_string(
	format_id: String, snapshot: Dictionary, options: Dictionary = {}
) -> Dictionary:
	if not _exporters.has(format_id):
		return _failure(
			"unsupported_format", "Unsupported export format: %s" % format_id, "", {"format": format_id}
		)
	var validation: Dictionary = _validate_snapshot(snapshot)
	if not validation.get("ok", false):
		return _failure(
			"invalid_snapshot",
			"Dependency snapshot is invalid and was not exported.",
			"",
			{"validation_errors": validation.get("errors", [])}
		)
	var text: String = str(_exporters[format_id].call("export_text", snapshot, options))
	if text.is_empty():
		return _failure(
			"empty_export_output",
			"Exporter '%s' produced empty output for a valid snapshot." % format_id,
			"",
			{"format": format_id}
		)
	return {
		"ok": true,
		"code": "ok",
		"error": "",
		"text": text,
		"warnings": validation.get("warnings", []),
	}


## Writes through a same-directory temporary file. Existing destinations are
## moved to a backup until commit succeeds, so a failed replacement is restored.
func export_to_file(
	format_id: String, destination: String, snapshot: Dictionary, options: Dictionary = {}
) -> Dictionary:
	if destination.strip_edges().is_empty():
		return _failure("empty_destination", "Export destination is empty.", destination)
	var serialization: Dictionary = export_to_string(format_id, snapshot, options)
	if not serialization.get("ok", false):
		return serialization

	var path: String = _ensure_extension(destination, extension_for(format_id))
	var directory_result: Dictionary = _ensure_parent_directory(path)
	if not directory_result.get("ok", false):
		return directory_result
	var operation_id: String = "%s_%s" % [get_instance_id(), Time.get_ticks_usec()]
	var temporary_path: String = path + ".sdi_%s.tmp" % operation_id
	var backup_path: String = path + ".sdi_%s.bak" % operation_id

	var write_result: Dictionary = _write_temporary_file(
		temporary_path, str(serialization["text"]), path
	)
	if not write_result.get("ok", false):
		return write_result

	var had_existing: bool = FileAccess.file_exists(path)
	var stage_result: Dictionary = _stage_existing_destination(path, backup_path, temporary_path)
	if not stage_result.get("ok", false):
		return stage_result

	var commit_result: Dictionary = _commit_temporary_file(
		temporary_path, path, backup_path, had_existing
	)
	if not commit_result.get("ok", false):
		return commit_result

	_remove_if_present(backup_path)
	_log_info("Dependency graph exported.", {"format": format_id, "path": path})
	return {"ok": true, "code": "ok", "error": "", "path": path}


func _validate_snapshot(snapshot: Dictionary) -> Dictionary:
	if _validator == null or not _validator.has_method("validate"):
		return {
			"ok": false,
			"errors": [
				{
					"code": "validator_unavailable",
					"message": "Snapshot validator is unavailable.",
					"context": {},
				}
			],
			"warnings": [],
		}
	return _validator.call("validate", snapshot)


func _ensure_parent_directory(path: String) -> Dictionary:
	var directory: String = path.get_base_dir()
	if directory.is_empty():
		return {"ok": true, "code": "ok"}
	var absolute_directory: String = directory
	if directory.begins_with("res://") or directory.begins_with("user://"):
		absolute_directory = ProjectSettings.globalize_path(directory)
	if DirAccess.dir_exists_absolute(absolute_directory):
		return {"ok": true, "code": "ok"}
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_directory)
	if error != OK:
		return _failure(
			"destination_directory_failed",
			"Cannot create export directory: %s (error %s)" % [directory, error],
			path
		)
	return {"ok": true, "code": "ok"}


func _write_temporary_file(temporary_path: String, text: String, destination: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return _failure(
			"temporary_open_failed",
			"Cannot open export destination: %s (error %s)" % [temporary_path, FileAccess.get_open_error()],
			destination
		)
	file.store_string(text)
	file.flush()
	file.close()
	return {"ok": true, "code": "ok"}


func _stage_existing_destination(
	path: String, backup_path: String, temporary_path: String
) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "code": "ok"}
	var backup_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(backup_path)
	)
	if backup_error == OK:
		return {"ok": true, "code": "ok"}
	_remove_if_present(temporary_path)
	return _failure(
		"backup_stage_failed",
		"Cannot stage existing export for replacement: %s (error %s)" % [path, backup_error],
		path
	)


func _commit_temporary_file(
	temporary_path: String, path: String, backup_path: String, had_existing: bool
) -> Dictionary:
	var commit_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(path)
	)
	if commit_error == OK:
		return {"ok": true, "code": "ok"}

	_remove_if_present(temporary_path)
	if not had_existing:
		return _failure(
			"commit_failed", "Cannot commit export: %s (error %s)" % [path, commit_error], path
		)

	var restore_error: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(path)
	)
	if restore_error == OK:
		return _failure(
			"commit_failed_restored",
			"Cannot commit export: %s (error %s); previous file was restored." % [path, commit_error],
			path
		)
	return _failure(
		"commit_and_restore_failed",
		"Export commit failed (%s) and backup restoration also failed (%s): %s" % [commit_error, restore_error, backup_path],
		path,
		{"backup_path": backup_path, "commit_error": commit_error, "restore_error": restore_error}
	)


func _ensure_extension(path: String, extension: String) -> String:
	var expected: String = "." + extension.to_lower()
	if path.to_lower().ends_with(expected):
		return path
	var current_extension: String = path.get_extension()
	if current_extension.is_empty():
		return path + expected
	return path.left(path.length() - current_extension.length() - 1) + expected


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _failure(
	code: String, message: String, path: String = "", context: Dictionary = {}
) -> Dictionary:
	var log_context: Dictionary = context.duplicate(true)
	if not path.is_empty():
		log_context["path"] = path
	log_context["code"] = code
	_log_error(message, log_context)
	return {
		"ok": false,
		"code": code,
		"error": message,
		"path": path,
		"context": context.duplicate(true),
	}


func _log_info(message: String, context: Dictionary = {}) -> void:
	if logger != null and logger.has_method("info"):
		logger.call("info", message, context)


func _log_error(message: String, context: Dictionary = {}) -> void:
	if logger != null and logger.has_method("error"):
		logger.call("error", message, context)

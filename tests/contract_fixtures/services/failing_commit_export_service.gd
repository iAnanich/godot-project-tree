extends "res://addons/script_dependency_inspector/export/export_service.gd"

var _fail_next_commit: bool = true


func _rename_absolute(source_path: String, destination_path: String) -> Error:
	if _fail_next_commit and source_path.contains(".sdi_") and source_path.ends_with(".tmp"):
		_fail_next_commit = false
		return ERR_CANT_CREATE
	return super._rename_absolute(source_path, destination_path)

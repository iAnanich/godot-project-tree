extends RefCounted

static var marker_written: bool = _write_marker()

static func _write_marker() -> bool:
	var marker_path: String = "user://sdi_static_analysis_execution_marker.txt"
	var file: FileAccess = FileAccess.open(marker_path, FileAccess.WRITE)
	if file != null:
		file.store_string("executed")
		file.close()
	return true

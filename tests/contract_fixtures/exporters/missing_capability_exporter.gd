extends RefCounted

func format_id() -> String:
	return "missing_capability"

func display_name() -> String:
	return "Missing capability"

func file_extension() -> String:
	return "txt"

func capabilities() -> Dictionary:
	return {"colors": false}

func export_text(_snapshot: Dictionary, _options: Dictionary = {}) -> String:
	return "not registered"

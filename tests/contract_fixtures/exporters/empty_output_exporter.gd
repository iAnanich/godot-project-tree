extends RefCounted


func format_id() -> String:
	return "empty"


func display_name() -> String:
	return "Empty output"


func file_extension() -> String:
	return "txt"


func capabilities() -> Dictionary:
	return {
		"colors": false,
		"class_members": false,
		"structured_member_links": false,
		"exact_member_endpoints": false,
		"member_relation_labels": false,
	}


func export_text(_snapshot: Dictionary, _options: Dictionary = {}) -> String:
	return ""

extends RefCounted


## Runs the reusable behavioral contract for a dependency-graph exporter.
## Third-party exporters can execute the same checks before registration.
func validate(exporter, snapshot: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if exporter == null:
		failures.append("Exporter instance is null.")
		return failures
	for method_name in ["format_id", "display_name", "file_extension", "capabilities", "export_text"]:
		if not exporter.has_method(method_name):
			failures.append("Exporter is missing required method: %s" % method_name)
	if not failures.is_empty():
		return failures
	var format_id: String = str(exporter.call("format_id"))
	var display_name: String = str(exporter.call("display_name"))
	var extension: String = str(exporter.call("file_extension"))
	var capabilities_value = exporter.call("capabilities")
	if format_id.strip_edges().is_empty() or format_id != format_id.to_lower():
		failures.append("Exporter format_id must be non-empty lowercase text.")
	if display_name.strip_edges().is_empty():
		failures.append("Exporter display_name must not be empty.")
	if (
		extension.strip_edges().is_empty()
		or extension.begins_with(".")
		or extension.contains("/")
		or extension.contains("\\")
	):
		failures.append("Exporter file_extension must omit periods and path separators.")
	if not capabilities_value is Dictionary:
		failures.append("Exporter capabilities must be a dictionary.")
	else:
		for capability in ["colors", "class_members", "structured_member_links", "exact_member_endpoints", "member_relation_labels"]:
			if not (capabilities_value as Dictionary).has(capability):
				failures.append("Exporter capability declaration is missing: %s" % capability)
			elif not (capabilities_value as Dictionary)[capability] is bool:
				failures.append("Exporter capability must be boolean: %s" % capability)
	var before: Dictionary = snapshot.duplicate(true)
	var first: String = str(exporter.call("export_text", snapshot, {}))
	var second: String = str(exporter.call("export_text", snapshot, {}))
	if first.is_empty():
		failures.append("Exporter output must not be empty for a valid snapshot.")
	if first != second:
		failures.append("Exporter output must be deterministic for equivalent input.")
	if snapshot != before:
		failures.append("Exporter must not mutate the canonical snapshot.")
	return failures

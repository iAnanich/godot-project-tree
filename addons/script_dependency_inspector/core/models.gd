@tool
extends RefCounted

const SCHEMA_VERSION := 1


## Creates the canonical, dictionary-based graph snapshot.
static func new_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"metadata": {},
		"nodes": [],
		"edges": [],
		"warnings": [],
		"errors": [],
		"diagnostics": [],
	}


## Returns a graph node by stable ID, or an empty dictionary.
static func find_node(snapshot: Dictionary, node_id: String) -> Dictionary:
	for node_value in snapshot.get("nodes", []):
		var node: Dictionary = node_value
		if str(node.get("id", "")) == node_id:
			return node
	return {}


## Deep-copies a snapshot for safe serialization or external consumption.
static func serializable_copy(snapshot: Dictionary) -> Dictionary:
	return snapshot.duplicate(true)

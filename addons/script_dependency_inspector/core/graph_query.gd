@tool
extends RefCounted

## Pure graph queries used by the editor presentation. These methods do not
## mutate the canonical snapshot.


func descendant_counts(snapshot: Dictionary) -> Dictionary:
	var children_by_parent: Dictionary = _children_by_parent(snapshot)
	var counts: Dictionary = {}
	for node_value in snapshot.get("nodes", []):
		if not node_value is Dictionary:
			continue
		var node_id: String = str((node_value as Dictionary).get("id", ""))
		var direct: Array = children_by_parent.get(node_id, [])
		var descendants: Array = _descendants(node_id, children_by_parent)
		counts[node_id] = {"direct": direct.size(), "transitive": descendants.size()}
	return counts


## Returns the selected node plus its ancestor chain and optional descendants.
func relationship_focus_ids(
	snapshot: Dictionary, node_id: String, include_descendants: bool = false
) -> Dictionary:
	var related: Dictionary = {}
	if node_id.is_empty():
		return related
	related[node_id] = true
	var parent_by_child: Dictionary = _parent_by_child(snapshot)
	var current: String = node_id
	var visited: Dictionary = {}
	while parent_by_child.has(current) and not visited.has(current):
		visited[current] = true
		current = str(parent_by_child[current])
		if not current.is_empty():
			related[current] = true
	if include_descendants:
		for descendant_value in _descendants(node_id, _children_by_parent(snapshot)):
			related[str(descendant_value)] = true
	return related


## Returns a bounded presentation neighborhood around a selected node.
func neighborhood_ids(
	snapshot: Dictionary, node_id: String, include_descendants: bool = false
) -> Dictionary:
	var kept: Dictionary = relationship_focus_ids(snapshot, node_id, include_descendants)
	if node_id.is_empty():
		return kept
	for edge_value in snapshot.get("edges", []):
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		# Inheritance is handled by relationship_focus_ids so the descendants
		# option remains authoritative. Neighborhood expansion adds only direct
		# non-inheritance dependency neighbors.
		if str(edge.get("kind", "")) == "extends":
			continue
		var source: String = str(edge.get("source", ""))
		var target: String = str(edge.get("target", ""))
		if source == node_id:
			kept[target] = true
		elif target == node_id:
			kept[source] = true
	# A direct dependency target remains understandable with its ancestry.
	var parent_by_child: Dictionary = _parent_by_child(snapshot)
	for kept_id_value in kept.keys():
		var current: String = str(kept_id_value)
		var visited: Dictionary = {}
		while parent_by_child.has(current) and not visited.has(current):
			visited[current] = true
			current = str(parent_by_child[current])
			if not current.is_empty():
				kept[current] = true
	return kept


func _parent_by_child(snapshot: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	for edge_value in snapshot.get("edges", []):
		if (
			edge_value is Dictionary
			and str((edge_value as Dictionary).get("kind", "")) == "extends"
		):
			index[str((edge_value as Dictionary).get("source", ""))] = str(
				(edge_value as Dictionary).get("target", "")
			)
	return index


func _children_by_parent(snapshot: Dictionary) -> Dictionary:
	var index: Dictionary = {}
	for edge_value in snapshot.get("edges", []):
		if not edge_value is Dictionary:
			continue
		var edge: Dictionary = edge_value
		if str(edge.get("kind", "")) != "extends":
			continue
		var parent: String = str(edge.get("target", ""))
		var children: Array = index.get(parent, [])
		var child: String = str(edge.get("source", ""))
		if not children.has(child):
			children.append(child)
			children.sort()
		index[parent] = children
	return index


func _descendants(node_id: String, children_by_parent: Dictionary) -> Array:
	var result: Array = []
	var pending: Array = (children_by_parent.get(node_id, []) as Array).duplicate()
	var visited: Dictionary = {}
	while not pending.is_empty():
		var current: String = str(pending.pop_front())
		if current.is_empty() or visited.has(current):
			continue
		visited[current] = true
		result.append(current)
		for child_value in children_by_parent.get(current, []):
			pending.append(str(child_value))
	result.sort()
	return result

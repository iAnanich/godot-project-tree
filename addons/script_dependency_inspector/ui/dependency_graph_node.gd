@tool
extends GraphNode

@export var minimum_node_width: float = 230.0
@export var maximum_node_width: float = 420.0
@export var compact_native_width: float = 150.0
@export var inheritance_port_color: Color = Color("d8dee9")
@export var dependency_port_color: Color = Color("e5c07b")
@export var type_dependency_port_color: Color = Color("56b6c2")

@onready var metadata_content: VBoxContainer = %MetadataContent
@onready var member_scroll: ScrollContainer = %MemberScroll
@onready var member_content: VBoxContainer = %MemberContent

var _layout_size: Vector2 = Vector2(230.0, 37.0)
var _dynamic_rows: Array[Control] = []
var _member_ports: Dictionary = {}
var _next_member_port_index: int = 3
var _next_direct_slot_index: int = 4


## Rebuilds this graph node from canonical graph-node data.
## Display options affect only presentation; canonical member data is preserved.
func configure(
	node_data: Dictionary, style: Dictionary, display_options: Dictionary = {}
) -> void:
	var full_name = str(node_data.get("name", "Unnamed"))
	var kind = str(node_data.get("kind", "external"))
	var path = str(node_data.get("path", ""))
	title = _truncate(full_name, int(style.get("graph_title_character_limit", 48)))
	tooltip_text = ""
	_set_titlebar_tooltip(full_name, path, str(node_data.get("inheritance_family", "other")))
	minimum_node_width = float(style.get("graph_node_width", minimum_node_width))
	maximum_node_width = maxf(
		minimum_node_width, float(style.get("graph_node_max_width", maximum_node_width))
	)
	compact_native_width = float(style.get("native_node_width", compact_native_width))
	inheritance_port_color = Color(
		str(style.get("inheritance_edge_color", inheritance_port_color.to_html(false)))
	)
	dependency_port_color = Color(
		str(style.get("dependency_edge_color", dependency_port_color.to_html(false)))
	)
	type_dependency_port_color = Color(
		str(style.get("type_dependency_edge_color", type_dependency_port_color.to_html(false)))
	)

	_clear_container(metadata_content)
	_clear_container(member_content)
	_clear_dynamic_rows()
	_member_ports.clear()
	_next_member_port_index = 3
	_next_direct_slot_index = 4

	var compact_native = kind == "native"
	metadata_content.visible = not compact_native
	member_scroll.visible = false
	member_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	member_scroll.custom_minimum_size.y = 0.0
	var longest_text = title.length()
	var member_height = 0.0
	if not compact_native:
		longest_text = maxi(longest_text, _add_metadata(node_data, style))
		var descriptors = _member_descriptors(node_data, style, display_options)
		for descriptor_value in descriptors:
			var descriptor: Dictionary = descriptor_value
			longest_text = maxi(longest_text, int(descriptor.get("longest", 0)))
		if not descriptors.is_empty():
			var member_count = 0
			for descriptor_value in descriptors:
				if not bool((descriptor_value as Dictionary).get("heading", false)):
					member_count += 1
			var natural_member_height = float(descriptors.size() * 22 + member_count + 6)
			var maximum_member_height = float(style.get("graph_max_member_height", 520.0))
			if natural_member_height <= maximum_member_height:
				for descriptor_value in descriptors:
					_add_direct_descriptor(descriptor_value, style, display_options)
				member_height = natural_member_height
			else:
				member_scroll.visible = true
				member_scroll.custom_minimum_size.y = maximum_member_height
				member_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
				for descriptor_value in descriptors:
					_add_scrolled_descriptor(descriptor_value)
				member_height = maximum_member_height

	var width = _estimated_width(kind, longest_text, style)
	custom_minimum_size.x = width
	var base_height = 37.0 if compact_native else 65.0
	_layout_size = Vector2(width, base_height + member_height)

	_apply_kind_and_family_style(kind, str(node_data.get("inheritance_family", "other")), style)
	set_slot(0, true, 0, inheritance_port_color, true, 0, inheritance_port_color)
	set_slot(1, true, 1, dependency_port_color, true, 1, dependency_port_color)
	set_slot(2, true, 2, type_dependency_port_color, true, 2, type_dependency_port_color)


## Returns the deterministic size used by the dock layout before container sorting completes.
func layout_size() -> Vector2:
	return _layout_size


## Returns the GraphNode port index for a visible member, or fallback_port.
## Very large nodes use a scroll container and intentionally fall back to the
## class-level port because GraphNode cannot expose ports on scrolled grandchildren.
func port_for_member(member_value, edge_kind: String, fallback_port: int) -> int:
	if not member_value is Dictionary:
		return fallback_port
	var member: Dictionary = member_value
	var key = _member_key(str(member.get("kind", "")), str(member.get("name", "")))
	if not _member_ports.has(key):
		return fallback_port
	var relation_ports: Dictionary = _member_ports[key]
	return int(relation_ports.get(edge_kind, fallback_port))


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _clear_dynamic_rows() -> void:
	for row in _dynamic_rows:
		if is_instance_valid(row):
			if row.get_parent() == self:
				remove_child(row)
			row.queue_free()
	_dynamic_rows.clear()


func _add_metadata(node_data: Dictionary, style: Dictionary) -> int:
	var path = str(node_data.get("path", ""))
	var kind = str(node_data.get("kind", "external")).capitalize()
	var family = _family_display_name(str(node_data.get("inheritance_family", "other")))
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var summary = kind
	if not family.is_empty():
		summary += " · " + family
	var summary_label = _new_compact_label(
		summary, Color(str(style.get("metadata_color", "abb2bf")))
	)
	summary_label.tooltip_text = "%s; inheritance family: %s" % [kind, family]
	row.add_child(summary_label)
	if not path.is_empty():
		var path_button = Button.new()
		path_button.text = "…"
		path_button.flat = true
		path_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		path_button.custom_minimum_size.x = 26.0
		path_button.tooltip_text = "Script path:\n%s\n\nPress to copy." % path
		path_button.pressed.connect(
			func() -> void:
				DisplayServer.clipboard_set(path)
		)
		row.add_child(path_button)
	metadata_content.add_child(row)
	return summary.length() + (5 if not path.is_empty() else 0)


func _member_descriptors(
	node_data: Dictionary, style: Dictionary, display_options: Dictionary
) -> Array:
	var descriptors: Array = []
	_append_member_descriptors(
		descriptors,
		"Properties",
		node_data.get("properties", []),
		"property",
		style,
		display_options
	)
	_append_member_descriptors(
		descriptors, "Signals", node_data.get("signals", []), "signal", style, display_options
	)
	_append_member_descriptors(
		descriptors, "Methods", node_data.get("methods", []), "method", style, display_options
	)
	return descriptors


func _append_member_descriptors(
	descriptors: Array,
	section_name: String,
	members: Array,
	member_kind: String,
	style: Dictionary,
	display_options: Dictionary
) -> void:
	if members.is_empty():
		return
	var color = _member_color(member_kind, style)
	descriptors.append(
		{
			"heading": true,
			"text": section_name,
			"full_text": section_name,
			"color": color.lightened(0.18),
			"longest": section_name.length(),
		}
	)
	var maximum = maxi(1, int(style.get("graph_max_members_per_section", 50)))
	var displayed = mini(members.size(), maximum)
	for index in range(displayed):
		var member: Dictionary = members[index]
		var full_text = _member_text(member, member_kind, display_options)
		descriptors.append(
			{
				"heading": false,
				"text": _truncate(
					full_text, int(style.get("graph_member_character_limit", 120))
				),
				"full_text": full_text,
				"color": color,
				"member": {"kind": member_kind, "name": str(member.get("name", ""))},
				"longest": full_text.length(),
			}
		)
	if displayed < members.size():
		var remaining = members.size() - displayed
		var overflow_text = "… %s more" % remaining
		descriptors.append(
			{
				"heading": true,
				"text": overflow_text,
				"full_text": "%s additional %s not displayed" % [
					remaining, section_name.to_lower()
				],
				"color": color.darkened(0.12),
				"longest": overflow_text.length(),
			}
		)


func _add_direct_descriptor(
	descriptor_value, _style: Dictionary, display_options: Dictionary
) -> void:
	var descriptor: Dictionary = descriptor_value
	var label = _new_compact_label(
		str(descriptor.get("text", "")), descriptor.get("color", Color.WHITE)
	)
	label.tooltip_text = str(descriptor.get("full_text", descriptor.get("text", "")))
	if bool(descriptor.get("heading", false)):
		label.add_theme_font_size_override("font_size", 13)
	var label_slot_index = _next_direct_slot_index
	_next_direct_slot_index += 1
	add_child(label)
	_dynamic_rows.append(label)
	if bool(descriptor.get("heading", false)):
		return
	var member: Dictionary = descriptor.get("member", {})
	var key = _member_key(str(member.get("kind", "")), str(member.get("name", "")))
	var requested_kinds: Array = ["uses", "type_uses"]
	if display_options.has("member_port_usage"):
		var usage: Dictionary = display_options.get("member_port_usage", {})
		requested_kinds = usage.get(key, [])
	if requested_kinds.is_empty():
		return

	var ports: Dictionary = {}
	for relation_index in range(requested_kinds.size()):
		var relation_kind = str(requested_kinds[relation_index])
		if relation_kind not in ["uses", "type_uses"]:
			continue
		var anchor: Control = label
		var anchor_slot_index = label_slot_index
		if relation_index > 0:
			anchor = Control.new()
			anchor.custom_minimum_size = Vector2(0.0, 1.0)
			anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
			anchor_slot_index = _next_direct_slot_index
			_next_direct_slot_index += 1
			add_child(anchor)
			_dynamic_rows.append(anchor)
		var port_type = 2 if relation_kind == "type_uses" else 1
		var port_color = (
			type_dependency_port_color if relation_kind == "type_uses" else dependency_port_color
		)
		ports[relation_kind] = _next_member_port_index
		set_slot(
			anchor_slot_index,
			true,
			port_type,
			port_color,
			true,
			port_type,
			port_color
		)
		_next_member_port_index += 1
	if not ports.is_empty():
		_member_ports[key] = ports


func _add_scrolled_descriptor(descriptor_value) -> void:
	var descriptor: Dictionary = descriptor_value
	var label = _new_compact_label(
		str(descriptor.get("text", "")), descriptor.get("color", Color.WHITE)
	)
	label.tooltip_text = str(descriptor.get("full_text", descriptor.get("text", "")))
	if bool(descriptor.get("heading", false)):
		label.add_theme_font_size_override("font_size", 13)
	member_content.add_child(label)


func _new_compact_label(text: String, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size = Vector2(0, 18)
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	return label


func _member_text(
	member: Dictionary, member_kind: String, display_options: Dictionary
) -> String:
	match member_kind:
		"property":
			var property_name = str(member.get("name", "property"))
			if not bool(display_options.get("show_property_types", false)):
				return property_name
			var property_type = str(member.get("type", ""))
			return property_name + (": " + property_type if not property_type.is_empty() else "")
		"signal":
			var signal_name = str(member.get("name", "signal"))
			if not bool(display_options.get("show_signal_signatures", false)):
				return signal_name
			return "signal %s(%s)" % [signal_name, member.get("arguments", "")]
		_:
			var method_name = str(member.get("name", "method"))
			if not bool(display_options.get("show_method_signatures", false)):
				return method_name
			var return_type = str(member.get("return_type", ""))
			return (
				"%s(%s)%s"
				% [
					method_name,
					member.get("arguments", ""),
					" -> " + return_type if not return_type.is_empty() else ""
				]
			)


func _member_color(member_kind: String, style: Dictionary) -> Color:
	match member_kind:
		"property":
			return Color(str(style.get("property_color", "98c379")))
		"signal":
			return Color(str(style.get("signal_color", "c678dd")))
		_:
			return Color(str(style.get("method_color", "61afef")))


func _member_key(kind: String, name: String) -> String:
	return kind + ":" + name


func _estimated_width(kind: String, longest_text: int, style: Dictionary) -> float:
	if kind == "native":
		return maxf(compact_native_width, minf(maximum_node_width, float(longest_text * 8 + 34)))
	var estimated = float(longest_text * 7 + 42)
	return clampf(estimated, minimum_node_width, maximum_node_width)


func _set_titlebar_tooltip(full_name: String, path: String, family: String) -> void:
	if not has_method("get_titlebar_hbox"):
		return
	var titlebar = call("get_titlebar_hbox") as Control
	if titlebar == null:
		return
	var text = full_name
	if not path.is_empty():
		text += "\n" + path
	if not family.is_empty() and family != "other":
		text += "\nInheritance family: " + _family_display_name(family)
	titlebar.tooltip_text = text


func _family_display_name(family: String) -> String:
	match family:
		"object":
			return "Object family"
		"ref_counted":
			return "RefCounted family"
		"node":
			return "Node family"
		"node_2d":
			return "Node2D family"
		"node_3d":
			return "Node3D family"
		"control":
			return "Control family"
		_:
			return "Other family"


func _truncate(value: String, maximum_characters: int) -> String:
	if maximum_characters <= 0 or value.length() <= maximum_characters:
		return value
	if maximum_characters <= 1:
		return "…"
	return value.substr(0, maximum_characters - 1) + "…"


func _apply_kind_and_family_style(kind: String, family: String, style: Dictionary) -> void:
	var color_key = "external_class_color"
	match kind:
		"user":
			color_key = "user_script_color"
		"addon":
			color_key = "addon_script_color"
		"native":
			color_key = "native_class_color"
	var base_color = Color(str(style.get(color_key, "65737e")))
	var family_color = _family_color(family, style, base_color.lightened(0.25))
	var panel = StyleBoxFlat.new()
	panel.bg_color = base_color.darkened(0.55)
	panel.border_color = family_color
	panel.set_border_width_all(2)
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = base_color.darkened(0.25)
	title_style.border_color = family_color
	title_style.set_border_width_all(2)
	add_theme_stylebox_override("panel", panel)
	add_theme_stylebox_override("panel_selected", panel)
	add_theme_stylebox_override("titlebar", title_style)
	add_theme_stylebox_override("titlebar_selected", title_style)


func _family_color(family: String, style: Dictionary, fallback: Color) -> Color:
	var key = "other_family_color"
	match family:
		"object":
			key = "object_family_color"
		"ref_counted":
			key = "ref_counted_family_color"
		"node":
			key = "node_family_color"
		"node_2d":
			key = "node_2d_family_color"
		"node_3d":
			key = "node_3d_family_color"
		"control":
			key = "control_family_color"
	if not style.has(key):
		return fallback
	return Color(str(style[key]))

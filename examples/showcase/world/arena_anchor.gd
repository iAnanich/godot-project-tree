class_name ShowcaseArenaAnchor3D
extends Node3D

## Node3D-family example used by the showcase representation.
@export var anchor_id: StringName = &"arena_origin"


func world_transform() -> Transform3D:
	return global_transform

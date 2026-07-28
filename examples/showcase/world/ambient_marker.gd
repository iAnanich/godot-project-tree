extends Node2D

## Unnamed script: the graph should display the filename `ambient_marker`.
@export var marker_radius: float = 24.0


func marker_position() -> Vector2:
	return global_position

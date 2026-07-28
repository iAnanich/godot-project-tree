class_name FixtureBase
extends Node

signal base_changed(value: int)

@export var speed: float = 2.0


func base_method(value: int) -> String:
	return str(value)

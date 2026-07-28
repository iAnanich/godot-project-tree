class_name ShowcaseEnemyActor
extends "res://examples/showcase/actors/base_actor.gd"

## Path-based inheritance plus a literal load dependency.
@export var aggression: float = 0.5
var weapon_profile_script: Script = load("res://examples/showcase/data/weapon_profile.gd")


func choose_action() -> String:
	return "heavy_attack" if aggression >= 0.75 else "guard"


func create_default_profile() -> Resource:
	return weapon_profile_script.new()

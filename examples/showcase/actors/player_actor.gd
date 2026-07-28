class_name ShowcasePlayerActor
extends ShowcaseBaseActor

## class_name inheritance plus a literal preload dependency.
var damage_service_script: Script = preload("res://examples/showcase/services/damage_service.gd")


func request_primary_attack() -> void:
	request_action("primary_attack")


func preview_damage() -> int:
	var service = damage_service_script.new()
	return service.calculate_damage(weapon_profile)

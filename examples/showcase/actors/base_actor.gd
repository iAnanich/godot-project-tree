class_name ShowcaseBaseActor
extends ShowcaseCombatEntity

## User script inheriting from a class supplied by another add-on.
signal action_requested(action_name: String)

@export var actor_label: String = "Actor"
@export var weapon_profile: ShowcaseWeaponProfile
var last_action: String = ""


func request_action(action_name: String) -> void:
	last_action = action_name
	action_requested.emit(action_name)


func attack_power(critical: bool = false) -> int:
	return ShowcaseDamageService.calculate_damage(weapon_profile, critical)


class RuntimeState:
	var action_count: int = 0
	var last_target_path: NodePath

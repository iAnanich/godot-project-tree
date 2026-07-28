class_name ShowcaseWeaponProfile
extends Resource

## Resource class used by actors and services.
@export var display_name: String = "Training Sword"
@export_range(0, 1000, 1) var base_damage: int = 12
@export_range(0.0, 5.0, 0.05) var critical_multiplier: float = 1.5

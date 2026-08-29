class_name MediaWeaponData
extends Resource

## Typed resource used by character and service examples.
@export var display_name: String = "Training Blade"
@export_range(0, 250, 1) var base_damage: int = 12
@export_range(0.0, 4.0, 0.05) var critical_multiplier: float = 1.5

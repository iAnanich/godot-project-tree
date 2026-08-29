extends RefCounted


func consume() -> int:
	var helper_script = preload(
		"res://tests/contract_fixtures/hidden_member_scope/feature/helper.gd"
	)
	return helper_script.make()

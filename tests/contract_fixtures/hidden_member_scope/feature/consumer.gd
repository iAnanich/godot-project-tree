extends RefCounted


func consume() -> int:
	var HelperScript = preload(
		"res://tests/contract_fixtures/hidden_member_scope/feature/helper.gd"
	)
	return HelperScript.make()

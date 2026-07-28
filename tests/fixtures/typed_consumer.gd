class_name FixtureTypedConsumer
extends RefCounted

var helper: FixtureHelper


func resolve(items: Array[FixtureBase]) -> FixtureHelper:
	return helper if not items.is_empty() else null

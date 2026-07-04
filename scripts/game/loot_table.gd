class_name LootTable

## Rolls gear drops for a cleared delve room. Every room drops one
## item; deeper rooms increasingly drop a second. Draws from the same
## id registry the save system uses, so everything lootable persists.

static func roll_room_loot(room: int) -> Array:
	var drops := [_random_gear()]
	if randf() < 0.15 + room * 0.05:
		drops.append(_random_gear())
	return drops

static func _random_gear() -> GearDefinition:
	var ids = RosterSave.GEAR_PATHS.keys()
	return load(RosterSave.GEAR_PATHS[ids.pick_random()]).duplicate()

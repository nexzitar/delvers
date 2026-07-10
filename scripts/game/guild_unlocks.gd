class_name GuildUnlocks

## The Restoration of the Guild: meta progression as unlocks, never
## raw power. The first victory raises the banner and grants the first
## companion for free — after that, the guild grows by spending what
## the delves bring home.

const RESTORATION := "restoration"

## Purchasable unlocks, shown in the camp's Guild panel in order.
const UNLOCKS := [
	{
		"id": "second_skill_slot",
		"title": "Training Grounds",
		"flavor": "Drill a second technique into every delver.",
		"costs": {"gel": 6, "ash_wood": 4, "corrosion_core": 2},
	},
	{
		"id": "third_delver",
		"title": "Another Voice at the Fire",
		"flavor": "Word of the raised banner spreads. A third delver answers.",
		"costs": {"iron_scrap": 6, "leather": 4, "royal_jelly": 1},
	},
]

## Names for delvers who answer the fire, in arrival order.
const COMPANION_NAMES := ["Wren", "Bram", "Kessa", "Tolli"]
## Which body model each companion wears (default_delver's is male).
const COMPANION_MODELS := {
	"Wren": "res://resources/models/delver_female.glb",
	"Kessa": "res://resources/models/delver_female.glb",
}

static func unlocked(roster) -> bool:
	return roster.adventures_completed >= 1

static func is_purchased(roster, unlock_id: String) -> bool:
	return roster.purchased_unlocks.has(unlock_id)

static func can_afford(roster, unlock: Dictionary) -> bool:
	for material_id in unlock.costs:
		if roster.material_stash.get(material_id, 0) < unlock.costs[material_id]:
			return false
	return true

static func purchase(roster, unlock_id: String) -> bool:
	if not unlocked(roster) or is_purchased(roster, unlock_id):
		return false
	var unlock = null
	for entry in UNLOCKS:
		if entry.id == unlock_id:
			unlock = entry
	if unlock == null or not can_afford(roster, unlock):
		return false
	for material_id in unlock.costs:
		roster.material_stash[material_id] -= unlock.costs[material_id]
		if roster.material_stash[material_id] <= 0:
			roster.material_stash.erase(material_id)
	roster.purchased_unlocks.append(unlock_id)
	_apply(roster, unlock_id)
	if roster.autosave:
		RosterSave.save(roster)
	return true

static func _apply(roster, unlock_id: String):
	match unlock_id:
		"second_skill_slot":
			roster.bonus_skill_slots = 2
		"third_delver":
			roster.recruit_hero(
				["starter_sword", "starter_shield", "starter_helmet",
					"starter_armor"]
			)

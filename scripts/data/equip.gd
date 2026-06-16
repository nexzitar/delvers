class_name Equip

## Equip POSITIONS (where an item physically sits). Distinct from
## GearDefinition.Slot, which is the item's CATEGORY. Rings and trinkets
## are the only categories with two positions.
enum Position {
	HEAD, NECK, SHOULDER, BACK, CHEST, WRIST, HANDS,
	WAIST, LEGS, FEET, RING_1, RING_2, TRINKET_1, TRINKET_2,
	MAIN_HAND, OFF_HAND,
}

## Display columns for Layout A (top to bottom).
const COLUMN_LEFT := [
	Position.HEAD, Position.NECK, Position.SHOULDER, Position.BACK,
	Position.CHEST, Position.WRIST, Position.HANDS,
]
const COLUMN_RIGHT := [
	Position.WAIST, Position.LEGS, Position.FEET, Position.RING_1,
	Position.RING_2, Position.TRINKET_1, Position.TRINKET_2,
]
const WEAPON_ROW := [Position.MAIN_HAND, Position.OFF_HAND]

const ALL := [
	Position.HEAD, Position.NECK, Position.SHOULDER, Position.BACK,
	Position.CHEST, Position.WRIST, Position.HANDS, Position.WAIST,
	Position.LEGS, Position.FEET, Position.RING_1, Position.RING_2,
	Position.TRINKET_1, Position.TRINKET_2, Position.MAIN_HAND,
	Position.OFF_HAND,
]

const LABELS := {
	Position.HEAD: "Head", Position.NECK: "Neck", Position.SHOULDER: "Shoulder",
	Position.BACK: "Back", Position.CHEST: "Chest", Position.WRIST: "Wrist",
	Position.HANDS: "Hands", Position.WAIST: "Waist", Position.LEGS: "Legs",
	Position.FEET: "Feet", Position.RING_1: "Ring", Position.RING_2: "Ring",
	Position.TRINKET_1: "Trinket", Position.TRINKET_2: "Trinket",
	Position.MAIN_HAND: "Main Hand", Position.OFF_HAND: "Off Hand",
}

static func label(pos: int) -> String:
	return LABELS.get(pos, "?")

## The category that lives in a position.
static func category_of(pos: int) -> int:
	match pos:
		Position.RING_1, Position.RING_2:
			return GearDefinition.Slot.RING
		Position.TRINKET_1, Position.TRINKET_2:
			return GearDefinition.Slot.TRINKET
		Position.HEAD: return GearDefinition.Slot.HEAD
		Position.NECK: return GearDefinition.Slot.NECK
		Position.SHOULDER: return GearDefinition.Slot.SHOULDER
		Position.BACK: return GearDefinition.Slot.BACK
		Position.CHEST: return GearDefinition.Slot.CHEST
		Position.WRIST: return GearDefinition.Slot.WRIST
		Position.HANDS: return GearDefinition.Slot.HANDS
		Position.WAIST: return GearDefinition.Slot.WAIST
		Position.LEGS: return GearDefinition.Slot.LEGS
		Position.FEET: return GearDefinition.Slot.FEET
		Position.MAIN_HAND: return GearDefinition.Slot.MAIN_HAND
		Position.OFF_HAND: return GearDefinition.Slot.OFF_HAND
	# -1 sentinel: an unrecognized position is misuse. Returning HEAD (0) would
	# silently resolve to a real category; -1 errors visibly at the call site.
	return -1

## Positions an item of this category can occupy (before weapon rules).
static func positions_for(category: int) -> Array:
	match category:
		GearDefinition.Slot.RING:
			return [Position.RING_1, Position.RING_2]
		GearDefinition.Slot.TRINKET:
			return [Position.TRINKET_1, Position.TRINKET_2]
	for pos in ALL:
		if category_of(pos) == category:
			return [pos]
	return []

## Positions an actual gear item accepts, applying the dual-wield rule:
## a one-handed weapon may also go in the off hand.
static func accepted_positions(gear: GearDefinition) -> Array:
	# positions_for already returns a fresh array, so appending here never
	# mutates the shared constants.
	var positions = positions_for(gear.slot)
	if gear.slot == GearDefinition.Slot.MAIN_HAND \
			and gear.weapon_type == GearDefinition.WeaponType.ONE_HANDED:
		positions.append(Position.OFF_HAND)
	return positions

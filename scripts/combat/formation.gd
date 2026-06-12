class_name Formation

enum Row {
	FRONT,
	BACK
}

enum Slot {
	FRONT_TOP,
	FRONT_CENTER,
	FRONT_BOTTOM,
	BACK_TOP,
	BACK_CENTER,
	BACK_BOTTOM
}

const SLOT_NODE_NAMES = {
	Slot.FRONT_TOP: "FrontTop",
	Slot.FRONT_CENTER: "FrontCenter",
	Slot.FRONT_BOTTOM: "FrontBottom",
	Slot.BACK_TOP: "BackTop",
	Slot.BACK_CENTER: "BackCenter",
	Slot.BACK_BOTTOM: "BackBottom"
}

# Units fill the center of a row first, then spread outwards.
const FRONT_FILL_ORDER = [
	Slot.FRONT_CENTER, Slot.FRONT_TOP, Slot.FRONT_BOTTOM
]
const BACK_FILL_ORDER = [
	Slot.BACK_CENTER, Slot.BACK_TOP, Slot.BACK_BOTTOM
]

static func row_of(slot: int) -> Row:
	if slot <= Slot.FRONT_BOTTOM:
		return Row.FRONT
	return Row.BACK

## Slots to try when placing a unit, best match first. The preferred
## row fills up before spilling over into the other row.
static func fill_order(preferred_row: Row) -> Array:
	if preferred_row == Row.FRONT:
		return FRONT_FILL_ORDER + BACK_FILL_ORDER
	return BACK_FILL_ORDER + FRONT_FILL_ORDER

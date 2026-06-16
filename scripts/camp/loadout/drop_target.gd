extends Panel
class_name DropTarget

## A slot or bin that accepts dragged loadout icons. All policy lives
## on the screen; this just forwards the questions to it.

var screen              # LoadoutScreen
var target_kind := ""   # "equip:MAIN_HAND", "skill_slot", "gear_stash"

func _can_drop_data(_at_position, data):
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return screen.can_accept(target_kind, data)

func _drop_data(_at_position, data):
	screen.accept_drop(target_kind, data)

## When the player is carrying an item (click-to-carry), a click here
## tries to place it.
func _gui_input(event):
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if screen and screen.is_carrying():
			screen.place_on(target_kind)
			accept_event()

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

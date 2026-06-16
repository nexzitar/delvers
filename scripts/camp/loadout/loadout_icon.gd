extends TextureRect
class_name LoadoutIcon

## A draggable gear/skill icon in the loadout screen. Reports hover to
## the screen for tooltips and produces drag data the slots understand.

var screen            # LoadoutScreen that owns this icon
var kind := ""        # "gear" or "skill"
var res: Resource     # GearDefinition or SkillDefinition
var origin := ""      # "stash", "catalog", "equipped", "skill_slot"
var draggable := true

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture = _icon_texture()
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)

func _on_enter():
	if screen:
		screen.show_tooltip(kind, res)

func _on_exit():
	if screen:
		screen.hide_tooltip()

## A plain click (no drag) picks the item up onto the cursor, or places
## a carried item here. Drags consume the release, so this only fires on
## genuine clicks.
func _gui_input(event):
	if event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if screen and screen.has_method("on_icon_clicked"):
			screen.on_icon_clicked(self)
			accept_event()

func _get_drag_data(_at_position):

	if not draggable or res == null:
		return null

	if screen:
		screen.hide_tooltip()

	var ghost = TextureRect.new()
	ghost.texture = _icon_texture()
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.size = Vector2(72, 72)
	ghost.position = Vector2(-36, -36)
	ghost.modulate.a = 0.85

	var holder = Control.new()
	holder.add_child(ghost)
	set_drag_preview(holder)

	return {"kind": kind, "res": res, "origin": origin}

## When this icon fills a slot, a drop landing on it should be handled
## by the slot underneath (Godot doesn't bubble drops to parents on its
## own), so an occupied slot can swap its item without unequipping first.
func _can_drop_data(at_position, data):
	var parent = get_parent()
	if parent and parent.has_method("_can_drop_data"):
		return parent._can_drop_data(at_position, data)
	return false

func _drop_data(at_position, data):
	var parent = get_parent()
	if parent and parent.has_method("_drop_data"):
		parent._drop_data(at_position, data)

func _icon_texture() -> Texture2D:
	if res is GearDefinition:
		return res.icon if res.icon else res.texture
	if res is SkillDefinition:
		return res.icon
	return null

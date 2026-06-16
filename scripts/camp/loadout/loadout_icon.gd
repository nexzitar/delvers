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

func _icon_texture() -> Texture2D:
	if res is GearDefinition:
		return res.icon if res.icon else res.texture
	if res is SkillDefinition:
		return res.icon
	return null

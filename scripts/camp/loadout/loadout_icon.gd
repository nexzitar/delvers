extends Control
class_name LoadoutIcon

## Draggable gear/skill icon with a quality-colored frame.

var screen            # LoadoutScreen that owns this icon
var kind := ""        # "gear" or "skill"
var res: Resource     # GearDefinition or SkillDefinition
var origin := ""      # "stash", "catalog", "equipped:<pos>", "skill:<n>"
var draggable := true

var _frame: Panel
var _icon: TextureRect

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame = Panel.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_theme_stylebox_override("panel", _quality_frame())
	add_child(_frame)

	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 4
	_icon.offset_top = 4
	_icon.offset_right = -4
	_icon.offset_bottom = -4
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture = _icon_texture()
	_frame.add_child(_icon)

	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)

func _quality_frame() -> StyleBoxFlat:
	if kind == "twohand" and res is GearDefinition:
		return ItemQuality.frame_style(res.quality)
	if res is GearDefinition:
		return ItemQuality.frame_style(res.quality)
	if res is SkillDefinition:
		return ItemQuality.frame_style(res.quality)
	return ItemQuality.frame_style(ItemQuality.Tier.COMMON)

func _on_enter():
	if screen:
		screen.show_tooltip(kind, res)

func _on_exit():
	if screen:
		screen.hide_tooltip()

func _gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if screen and screen.has_method("on_icon_right_clicked"):
				screen.on_icon_right_clicked(self)
				accept_event()
			return
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
	ghost.size = Vector2(48, 48)
	ghost.position = Vector2(-24, -24)
	ghost.modulate.a = 0.85
	var holder = Control.new()
	holder.add_child(ghost)
	set_drag_preview(holder)
	return {"kind": kind, "res": res, "origin": origin}

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

func display_texture() -> Texture2D:
	return _icon_texture()

extends CanvasLayer
class_name DelvePanel

## End-of-room / end-of-delve overlay: a title, the loot on display,
## and one or two choices. Used for "Room cleared — delve deeper?" and
## for the final spoils summary.

signal primary_pressed
signal secondary_pressed

const FONT = preload("res://art/fonts/Herculanum.ttf")

const GOLD = Color(0.85, 0.72, 0.42)
const DIM = Color(0.62, 0.58, 0.5)

func setup(
		title_text: String,
		subtitle_text: String,
		loot: Array,
		primary_text: String,
		secondary_text := "",
):
	layer = 12

	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.55)
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim_bg)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.06, 0.94)
	style.border_color = Color(0.35, 0.28, 0.16, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -235
	panel.offset_bottom = 235
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	box.add_child(_label(title_text, 46, GOLD))
	box.add_child(_label(subtitle_text, 20, DIM))

	if not loot.is_empty():
		box.add_child(_label("Loot", 22, GOLD))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		box.add_child(row)
		for gear in loot:
			row.add_child(_loot_entry(gear))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)

	buttons.add_child(_button(primary_text, func(): primary_pressed.emit()))
	if secondary_text != "":
		buttons.add_child(_button(secondary_text, func(): secondary_pressed.emit()))

	UiSounds.wire_buttons(self)

func _loot_entry(gear) -> Control:
	var entry := VBoxContainer.new()
	entry.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = gear.icon if gear.icon else gear.texture
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	entry.add_child(icon)
	var name_label := _label(
		gear.gear_name, 14, ItemQuality.color(gear.quality)
	)
	name_label.custom_minimum_size = Vector2(96, 0)
	entry.add_child(name_label)
	return entry

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", GOLD)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))
	button.custom_minimum_size = Vector2(220, 52)
	button.pressed.connect(on_pressed)
	return button

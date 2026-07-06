class_name DungeonPicker
extends CanvasLayer

## Choose the delve: one row per dungeon the guild holds a map for.
## Locked rows show what's missing — a map someone below still guards.

signal chosen(dungeon_id: String)
signal closed

const FONT = preload("res://art/fonts/Herculanum.ttf")
const GOLD := Color(0.85, 0.72, 0.42)
const PARCHMENT := Color(0.85, 0.8, 0.7)
const DIM := Color(0.55, 0.52, 0.46)

func _ready():
	layer = 15
	var dim_bg := ColorRect.new()
	dim_bg.color = Color(0, 0, 0, 0.55)
	dim_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim_bg)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.07, 0.97)
	style.border_color = Color(0.35, 0.28, 0.16)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -340
	panel.offset_right = 340
	panel.offset_top = -200
	panel.offset_bottom = 200
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Choose the Delve"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	for dungeon_id in RosterSave.DUNGEON_PATHS:
		box.add_child(_dungeon_row(dungeon_id))

	var close := Button.new()
	close.text = "X"
	close.add_theme_font_override("font", FONT)
	close.add_theme_font_size_override("font_size", 22)
	close.anchor_left = 0.5
	close.anchor_right = 0.5
	close.anchor_top = 0.5
	close.anchor_bottom = 0.5
	close.offset_left = 292
	close.offset_right = 332
	close.offset_top = -194
	close.offset_bottom = -156
	close.pressed.connect(func():
		closed.emit()
		queue_free())
	add_child(close)

func _dungeon_row(dungeon_id: String) -> Control:
	var unlocked = PlayerRoster.unlocked_dungeons.has(dungeon_id)
	var dungeon = load(RosterSave.DUNGEON_PATHS[dungeon_id])

	var panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.1, 0.9)
	style.border_color = Color(0.28, 0.24, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label = Label.new()
	name_label.text = dungeon.dungeon_name if unlocked else "?????"
	name_label.add_theme_font_override("font", FONT)
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", PARCHMENT if unlocked else DIM)
	info.add_child(name_label)
	var flavor = Label.new()
	flavor.text = dungeon.flavor if unlocked \
		else "Marked on no map you carry."
	flavor.add_theme_font_size_override("font_size", 14)
	flavor.add_theme_color_override("font_color", DIM)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(flavor)

	if unlocked:
		var go = Button.new()
		go.text = "Delve"
		go.add_theme_font_override("font", FONT)
		go.add_theme_font_size_override("font_size", 20)
		go.custom_minimum_size = Vector2(110, 46)
		go.pressed.connect(func():
			UiSounds.click()
			chosen.emit(dungeon_id)
			queue_free())
		row.add_child(go)
	return panel

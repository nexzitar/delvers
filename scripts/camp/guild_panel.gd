class_name GuildPanel
extends CanvasLayer

## The Restoration of the Guild: milestone story beats and material-
## funded unlocks. Locked until the banner flies.

signal closed
signal roster_grew

const FONT = preload("res://art/fonts/Herculanum.ttf")
const GOLD := Color(0.85, 0.72, 0.42)
const PARCHMENT := Color(0.85, 0.8, 0.7)
const DIM := Color(0.55, 0.52, 0.46)
const LOCKED := Color(0.6, 0.35, 0.3)

var _box: VBoxContainer

func _ready():
	layer = 15
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

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
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -270
	panel.offset_bottom = 270
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.custom_minimum_size = Vector2(660, 0)
	_box.add_theme_constant_override("separation", 12)
	scroll.add_child(_box)

	_fill()

	var close := Button.new()
	close.text = "X"
	close.add_theme_font_override("font", FONT)
	close.add_theme_font_size_override("font_size", 24)
	close.anchor_left = 0.5
	close.anchor_right = 0.5
	close.anchor_top = 0.5
	close.anchor_bottom = 0.5
	close.offset_left = 310
	close.offset_right = 352
	close.offset_top = -264
	close.offset_bottom = -224
	close.pressed.connect(func():
		closed.emit()
		queue_free())
	add_child(close)

func _fill():
	for child in _box.get_children():
		child.queue_free()

	_box.add_child(_label("The Guild", 34, GOLD, true))

	if not GuildUnlocks.unlocked(PlayerRoster):
		_box.add_child(_label(
			"The banner still lies where it fell.", 20, LOCKED, true
		))
		_box.add_child(_label(
			"The guild must first prove itself — conquer the Darkwood.",
			16, DIM, true
		))
		return

	# The milestone beat, remembered.
	var restoration = PanelContainer.new()
	restoration.add_theme_stylebox_override("panel", _row_style(true))
	var restoration_box = VBoxContainer.new()
	restoration.add_child(restoration_box)
	restoration_box.add_child(_label("The Restoration of the Guild", 22, GOLD))
	restoration_box.add_child(_label(
		"The banner flies again. A stranger saw it and stayed. "
		+ "You're not alone anymore.", 15, PARCHMENT
	))
	_box.add_child(restoration)

	for unlock in GuildUnlocks.UNLOCKS:
		_box.add_child(_unlock_row(unlock))

func _unlock_row(unlock: Dictionary) -> Control:
	var purchased = GuildUnlocks.is_purchased(PlayerRoster, unlock.id)
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _row_style(purchased))

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(_label(unlock.title, 22, GOLD if purchased else PARCHMENT))
	info.add_child(_label(unlock.flavor, 15, DIM))
	if not purchased:
		for material_id in unlock.costs:
			var material = load(RosterSave.MATERIAL_PATHS[material_id])
			var have = PlayerRoster.material_stash.get(material_id, 0)
			var need = unlock.costs[material_id]
			info.add_child(_label(
				"%s %d/%d  -  %s" % [
					material.material_name, have, need,
					LootTable.material_owner(material_id),
				],
				14, PARCHMENT if have >= need else LOCKED
			))

	if purchased:
		row.add_child(_label("Restored", 20, GOLD))
	else:
		var buy = Button.new()
		buy.text = "Restore"
		buy.add_theme_font_override("font", FONT)
		buy.add_theme_font_size_override("font_size", 18)
		buy.custom_minimum_size = Vector2(110, 44)
		buy.disabled = not GuildUnlocks.can_afford(PlayerRoster, unlock)
		buy.pressed.connect(func():
			var before = PlayerRoster.heroes.size()
			if GuildUnlocks.purchase(PlayerRoster, unlock.id):
				UiSounds.click()
				_fill()
				if PlayerRoster.heroes.size() > before:
					roster_grew.emit())
		row.add_child(buy)
	return panel

func _row_style(bright: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.1, 0.9)
	style.border_color = GOLD if bright else Color(0.28, 0.24, 0.18)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	return style

func _label(text: String, size: int, color: Color, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

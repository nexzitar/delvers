extends PanelContainer
class_name BattleSidebar

## Side panel listing one team's units (portrait, name, health and
## mana) with a WoW-style damage meter at the bottom.

const FONT = preload("res://art/fonts/Herculanum.ttf")

const NAME_COLOR = Color(0.84, 0.72, 0.45)
const HP_FILL = Color(0.33, 0.6, 0.24)
const MANA_FILL = Color(0.23, 0.42, 0.78)
const BAR_BG = Color(0.07, 0.07, 0.09, 0.9)
const DEAD_TINT = Color(0.45, 0.38, 0.38, 0.8)

## Classic damage-meter row colors, assigned by join order.
const METER_COLORS = [
	Color(0.78, 0.61, 0.43),
	Color(0.25, 0.78, 0.92),
	Color(1.0, 0.96, 0.41),
	Color(0.53, 0.53, 0.93),
	Color(0.67, 0.83, 0.45),
	Color(1.0, 0.49, 0.04)
]

@export var title := "Delvers"

var unit_rows := {}
var meter_rows := {}
var damage_totals := {}
var encounter_time := 0.0

var unit_list: VBoxContainer
var meter_list: VBoxContainer

func _ready():

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.06, 0.82)
	style.border_color = Color(0.35, 0.28, 0.16, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	root.add_child(_make_label(title, 22, NAME_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	unit_list = VBoxContainer.new()
	unit_list.add_theme_constant_override("separation", 8)
	root.add_child(unit_list)

	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	root.add_child(_make_label("Damage", 18, NAME_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	meter_list = VBoxContainer.new()
	meter_list.add_theme_constant_override("separation", 4)
	root.add_child(meter_list)

func has_unit(entity_id) -> bool:
	return unit_rows.has(entity_id)

func add_unit(event):

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var portrait = TextureRect.new()
	portrait.texture = event.template.portrait
	portrait.custom_minimum_size = Vector2(44, 44)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	info.add_child(_make_label(event.entity_name, 15, NAME_COLOR))

	var hp = _make_stat_bar(HP_FILL, 16, 12)
	info.add_child(hp.bar)

	var mana = _make_stat_bar(MANA_FILL, 12, 10)
	info.add_child(mana.bar)

	unit_list.add_child(row)

	unit_rows[event.entity_id] = {
		"row": row,
		"hp_bar": hp.bar, "hp_text": hp.text,
		"mana_bar": mana.bar, "mana_text": mana.text
	}

	set_health(event.entity_id, event.current_health, event.max_health)
	set_mana(event.entity_id, event.current_mana, event.max_mana)

	_add_meter_row(event.entity_id, event.entity_name)

func set_health(entity_id, current, max_value):

	var row = unit_rows[entity_id]
	row.hp_bar.max_value = max_value
	row.hp_bar.value = current
	row.hp_text.text = "%d/%d" % [current, max_value]

func set_mana(entity_id, current, max_value):

	var row = unit_rows[entity_id]
	row.mana_bar.max_value = max(max_value, 1)
	row.mana_bar.value = current
	row.mana_text.text = "%d/%d" % [current, max_value]

func mark_dead(entity_id):

	set_health(entity_id, 0, unit_rows[entity_id].hp_bar.max_value)
	unit_rows[entity_id].row.modulate = DEAD_TINT

func add_damage(entity_id, amount, sim_time):

	damage_totals[entity_id] = damage_totals.get(entity_id, 0) + amount
	encounter_time = max(encounter_time, sim_time)
	_refresh_meter()

func _add_meter_row(entity_id, entity_name):

	var color = METER_COLORS[meter_rows.size() % METER_COLORS.size()]

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = 0.0

	var bg = StyleBoxFlat.new()
	bg.bg_color = BAR_BG
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)

	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)

	var name_label = _make_label(entity_name, 12, Color.WHITE)
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.offset_left = 5
	name_label.offset_right = -60
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(name_label)

	var value_label = _make_label("", 12, Color.WHITE)
	value_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	value_label.offset_right = -5
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(value_label)

	meter_list.add_child(bar)
	meter_rows[entity_id] = {"bar": bar, "value": value_label}

func _refresh_meter():

	var top = 1
	for total in damage_totals.values():
		top = max(top, total)

	# Sort rows by damage done, biggest on top, like the classics.
	var order = damage_totals.keys()
	order.sort_custom(
		func(a, b): return damage_totals[a] > damage_totals[b]
	)

	for i in order.size():
		var entity_id = order[i]
		var row = meter_rows[entity_id]
		var total = damage_totals[entity_id]
		var dps = total / max(encounter_time, 0.1)

		row.bar.value = float(total) / top
		row.value.text = "%d (%.1f)" % [total, dps]
		meter_list.move_child(row.bar, i)

func _make_label(text, size, color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:

	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = align
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

## Builds a stat bar with a centered value label; returns both.
func _make_stat_bar(fill_color, height, font_size := 11):

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.show_percentage = false

	var bg = StyleBoxFlat.new()
	bg.bg_color = BAR_BG
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)

	var fill = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)

	var text = _make_label("", font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(text)

	return {"bar": bar, "text": text}

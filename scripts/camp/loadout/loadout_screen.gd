extends CanvasLayer
class_name LoadoutScreen

## Modal hero outfitting screen. Opens over the camp: a character
## panel on the left (name, live paper-doll, equipment + skill slots),
## available skills and gear on the right, and a tooltip pinned to the
## bottom-right corner.

signal hero_changed(hero_index: int)

const ICON = preload("res://scripts/camp/loadout/loadout_icon.gd")
const DROP = preload("res://scripts/camp/loadout/drop_target.gd")

const FONT = preload("res://art/fonts/Herculanum.ttf")

const SLOT_ORDER = [
	GearDefinition.Slot.HEAD,
	GearDefinition.Slot.CHEST,
	GearDefinition.Slot.MAIN_HAND,
	GearDefinition.Slot.OFF_HAND,
]

const SLOT_LABELS = {
	GearDefinition.Slot.HEAD: "Head",
	GearDefinition.Slot.CHEST: "Chest",
	GearDefinition.Slot.MAIN_HAND: "Main Hand",
	GearDefinition.Slot.OFF_HAND: "Off Hand",
}

const GOLD = Color(0.85, 0.7, 0.28)
const PARCHMENT = Color(0.88, 0.82, 0.68)
const DIM = Color(0.62, 0.56, 0.44)

var hero_index := -1

# Rebuilt containers kept around for refresh().
var _name_edit: LineEdit
var _role_label: Label
var _equip_slots := {}        # slot enum -> DropTarget panel
var _skill_slot: DropTarget
var _gear_grid: GridContainer
var _preview_holder: Control
var _tooltip_panel: Panel
var _tooltip_box: VBoxContainer

func _ready():
	layer = 12
	visible = false
	_build()

func open(index: int):
	hero_index = index
	visible = true
	refresh()

func close():
	visible = false
	hero_index = -1

# --- Construction ----------------------------------------------------

func _build():

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	_build_left_panel()
	_build_skills_panel()
	_build_gear_panel()
	_build_tooltip()
	_build_close_button()

func _panel(l, t, r, b, ax, ay, az, aw) -> Panel:
	var p = Panel.new()
	p.add_theme_stylebox_override("panel", _panel_style())
	p.anchor_left = ax
	p.anchor_top = ay
	p.anchor_right = az
	p.anchor_bottom = aw
	p.offset_left = l
	p.offset_top = t
	p.offset_right = r
	p.offset_bottom = b
	add_child(p)
	return p

func _panel_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.09, 0.07, 0.95)
	s.border_color = Color(0.45, 0.32, 0.16)
	s.set_border_width_all(3)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(14)
	return s

func _slot_style() -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.05, 0.04, 0.9)
	s.border_color = Color(0.38, 0.27, 0.14)
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	return s

func _title(text) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _build_left_panel():

	var panel = _panel(40, 50, 600, -40, 0, 0, 0, 1)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	vbox.add_child(_title("Hero"))

	_name_edit = LineEdit.new()
	_name_edit.add_theme_font_override("font", FONT)
	_name_edit.add_theme_font_size_override("font_size", 26)
	_name_edit.add_theme_color_override("font_color", PARCHMENT)
	_name_edit.add_theme_stylebox_override("normal", _slot_style())
	_name_edit.add_theme_stylebox_override("focus", _panel_style())
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(0, 44)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.focus_exited.connect(func(): _on_name_submitted(_name_edit.text))
	vbox.add_child(_name_edit)

	# Live paper-doll preview.
	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(0, 300)
	_preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_preview_holder)

	_role_label = Label.new()
	_role_label.add_theme_font_override("font", FONT)
	_role_label.add_theme_font_size_override("font_size", 22)
	_role_label.add_theme_color_override("font_color", PARCHMENT)
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_role_label)

	vbox.add_child(_title("Equipment"))

	var equip_row = HBoxContainer.new()
	equip_row.add_theme_constant_override("separation", 14)
	equip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(equip_row)

	for slot in SLOT_ORDER:
		equip_row.add_child(_build_equip_slot(slot))

	vbox.add_child(_title("Skill"))

	var skill_row = HBoxContainer.new()
	skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(skill_row)
	skill_row.add_child(_build_skill_slot())

func _slot_cell(label_text) -> VBoxContainer:
	var cell = VBoxContainer.new()
	cell.add_theme_constant_override("separation", 4)
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var caption = Label.new()
	caption.text = label_text
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", DIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cell.add_child(caption)
	return cell

func _make_slot(target_kind) -> DropTarget:
	var slot = DROP.new()
	slot.screen = self
	slot.target_kind = target_kind
	slot.add_theme_stylebox_override("panel", _slot_style())
	slot.custom_minimum_size = Vector2(86, 86)
	return slot

func _build_equip_slot(slot_enum) -> VBoxContainer:
	var cell = _slot_cell(SLOT_LABELS[slot_enum])
	var slot = _make_slot("equip:%d" % slot_enum)
	_equip_slots[slot_enum] = slot
	cell.add_child(slot)
	return cell

func _build_skill_slot() -> VBoxContainer:
	var cell = _slot_cell("Attack")
	_skill_slot = _make_slot("skill_slot")
	cell.add_child(_skill_slot)
	return cell

func _build_skills_panel():
	var panel = _panel(-480, 50, -40, 330, 1, 0, 1, 0)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	vbox.add_child(_title("Available Skills"))

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	for skill in PlayerRoster.skill_catalog:
		grid.add_child(_make_icon("skill", skill, "catalog"))

func _build_gear_panel():
	var panel = _panel(-480, 350, -40, 612, 1, 0, 1, 0)
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var header = HBoxContainer.new()
	vbox.add_child(header)
	header.add_child(_title("Stash"))

	# The stash panel doubles as the unequip target.
	var bin = DROP.new()
	bin.screen = self
	bin.target_kind = "gear_stash"
	bin.add_theme_stylebox_override("panel", _slot_style())
	bin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(bin)

	_gear_grid = GridContainer.new()
	_gear_grid.columns = 4
	_gear_grid.add_theme_constant_override("h_separation", 10)
	_gear_grid.add_theme_constant_override("v_separation", 10)
	_gear_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gear_grid.offset_left = 10
	_gear_grid.offset_top = 10
	bin.add_child(_gear_grid)

func _build_tooltip():
	_tooltip_panel = _panel(-480, -300, -40, -40, 1, 1, 1, 1)
	_tooltip_panel.visible = false
	_tooltip_box = VBoxContainer.new()
	_tooltip_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tooltip_box.add_theme_constant_override("separation", 6)
	_tooltip_panel.add_child(_tooltip_box)

func _build_close_button():
	var btn = Button.new()
	btn.text = "X"
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", PARCHMENT)
	btn.anchor_left = 1
	btn.anchor_right = 1
	btn.offset_left = -52
	btn.offset_top = 8
	btn.offset_right = -12
	btn.offset_bottom = 44
	btn.pressed.connect(close)
	add_child(btn)

func _make_icon(kind, res, origin) -> LoadoutIcon:
	var icon = ICON.new()
	icon.screen = self
	icon.kind = kind
	icon.res = res
	icon.origin = origin
	icon.custom_minimum_size = Vector2(78, 78)
	return icon

# --- Refresh ---------------------------------------------------------

func refresh():
	if hero_index < 0:
		return

	var hero = PlayerRoster.heroes[hero_index]

	_name_edit.text = hero.hero_name
	_role_label.text = _role_text()

	for slot_enum in SLOT_ORDER:
		_fill_equip_slot(slot_enum)

	_fill_skill_slot()
	_fill_gear_grid()
	_update_preview()

func _role_text() -> String:
	var ranged = PlayerRoster.is_ranged(hero_index)
	var style = "Ranged" if ranged else "Melee"
	var row = "Back row" if ranged else "Front row"
	return "%s  -  %s" % [style, row]

func _clear(node):
	for child in node.get_children():
		child.queue_free()

func _fill_equip_slot(slot_enum):
	var slot = _equip_slots[slot_enum]
	_clear(slot)
	var item = PlayerRoster.equipped_item(hero_index, slot_enum)
	if item == null:
		return
	var icon = _make_icon("gear", item, "equipped")
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	slot.add_child(icon)

func _fill_skill_slot():
	_clear(_skill_slot)
	var skill = PlayerRoster.attack_skill(hero_index)
	if skill == null:
		return
	var icon = _make_icon("skill", skill, "skill_slot")
	icon.draggable = false
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_top = 6
	icon.offset_right = -6
	icon.offset_bottom = -6
	_skill_slot.add_child(icon)

func _fill_gear_grid():
	_clear(_gear_grid)
	for gear in PlayerRoster.gear_stash:
		_gear_grid.add_child(_make_icon("gear", gear, "stash"))

func _update_preview():
	_clear(_preview_holder)

	var hero = PlayerRoster.heroes[hero_index]

	var vp = SubViewport.new()
	vp.size = Vector2i(320, 340)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var container = SubViewportContainer.new()
	container.stretch = false
	# Centered horizontally in the panel, regardless of its width.
	container.anchor_left = 0.5
	container.anchor_right = 0.5
	container.offset_left = -160
	container.offset_right = 160
	container.offset_top = 0
	container.offset_bottom = 340
	container.add_child(vp)
	_preview_holder.add_child(container)

	var actor = hero.actor_scene.instantiate()
	actor.position = Vector2(160, 312)
	actor.scale = Vector2(1.25, 1.25)
	vp.add_child(actor)
	actor.equip_gear(hero.starting_gear)

# --- Drag-and-drop policy --------------------------------------------

func can_accept(target_kind, data) -> bool:

	if target_kind == "skill_slot":
		return data.kind == "skill"

	if target_kind == "gear_stash":
		return data.kind == "gear" and data.origin == "equipped"

	if target_kind.begins_with("equip:"):
		if data.kind != "gear":
			return false
		var slot_enum = int(target_kind.split(":")[1])
		if data.res.slot != slot_enum:
			return false
		if data.origin != "stash":
			return false
		# Can't strap an off-hand on over a bow or two-hander.
		if slot_enum == GearDefinition.Slot.OFF_HAND:
			var main = PlayerRoster.equipped_item(
				hero_index, GearDefinition.Slot.MAIN_HAND
			)
			if main and main.weapon_type in [
				GearDefinition.WeaponType.TWO_HANDED,
				GearDefinition.WeaponType.BOW,
			]:
				return false
		return true

	return false

func accept_drop(target_kind, data):

	if target_kind == "skill_slot":
		PlayerRoster.set_attack_skill(hero_index, data.res)
	elif target_kind == "gear_stash":
		PlayerRoster.unequip_gear(hero_index, data.res.slot)
	elif target_kind.begins_with("equip:"):
		PlayerRoster.equip_gear(hero_index, data.res)

	hide_tooltip()
	refresh()
	hero_changed.emit(hero_index)

# --- Tooltip ---------------------------------------------------------

func show_tooltip(kind, res):
	if res == null:
		return

	_clear(_tooltip_box)

	if kind == "gear":
		_tooltip_gear(res)
	elif kind == "skill":
		_tooltip_skill(res)

	_tooltip_panel.visible = true

func hide_tooltip():
	if _tooltip_panel:
		_tooltip_panel.visible = false

func _tip_line(text, color := PARCHMENT, size := 20):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_box.add_child(l)

func _divider():
	var sep = HSeparator.new()
	_tooltip_box.add_child(sep)

func _tooltip_gear(gear: GearDefinition):
	_tip_line(gear.gear_name, GOLD, 26)
	_tip_line(_gear_subtitle(gear), DIM, 17)

	if gear.attack_bonus != 0:
		_tip_line("+%d Attack" % gear.attack_bonus)
	if gear.health_bonus != 0:
		_tip_line("+%d Health" % gear.health_bonus)

	_divider()

	var equipped = PlayerRoster.equipped_item(hero_index, gear.slot)
	if equipped:
		_tip_line("Equipped (%s):" % SLOT_LABELS[gear.slot], DIM, 16)
		_tip_line("%s   %s" % [equipped.gear_name, _stat_summary(equipped)], PARCHMENT, 18)
	else:
		_tip_line("%s slot: empty" % SLOT_LABELS[gear.slot], DIM, 16)

func _gear_subtitle(gear: GearDefinition) -> String:
	var slot_name = SLOT_LABELS[gear.slot]
	match gear.weapon_type:
		GearDefinition.WeaponType.ONE_HANDED:
			return "%s - One-handed" % slot_name
		GearDefinition.WeaponType.TWO_HANDED:
			return "%s - Two-handed" % slot_name
		GearDefinition.WeaponType.BOW:
			return "%s - Bow (ranged)" % slot_name
	return slot_name

func _stat_summary(gear: GearDefinition) -> String:
	var parts = []
	if gear.attack_bonus != 0:
		parts.append("+%d ATK" % gear.attack_bonus)
	if gear.health_bonus != 0:
		parts.append("+%d HP" % gear.health_bonus)
	return ", ".join(parts) if not parts.is_empty() else "no bonuses"

func _tooltip_skill(skill: SkillDefinition):
	_tip_line(skill.skill_name, GOLD, 26)
	var ranged = skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE
	_tip_line("Ranged attack" if ranged else "Melee attack", DIM, 17)
	_tip_line("Damage: +%d to +%d" % [skill.base_min_damage, skill.base_max_damage])
	_tip_line("Sets the hero to the %s row" % ("back" if ranged else "front"), DIM, 16)

	_divider()

	var current = PlayerRoster.attack_skill(hero_index)
	if current:
		_tip_line("Current attack:", DIM, 16)
		_tip_line(current.skill_name, PARCHMENT, 18)

# --- Input -----------------------------------------------------------

func _on_dim_input(event):
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func _on_name_submitted(text):
	PlayerRoster.rename_hero(hero_index, text)
	_name_edit.text = PlayerRoster.heroes[hero_index].hero_name
	_name_edit.release_focus()
	hero_changed.emit(hero_index)

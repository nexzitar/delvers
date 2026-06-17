extends CanvasLayer
class_name LoadoutScreen

## Modal hero outfitting screen. Opens over the camp: a character
## panel on the left (name, live paper-doll, equipment + skill slots),
## available skills and gear on the right, and a tooltip pinned to the
## bottom-right corner.

signal hero_changed(hero_index: int)
signal closed

const ICON = preload("res://scripts/camp/loadout/loadout_icon.gd")
const DROP = preload("res://scripts/camp/loadout/drop_target.gd")

const FONT = preload("res://art/fonts/Herculanum.ttf")

const EMPTY_ICONS := {
	GearDefinition.Slot.HEAD: preload("res://art/ui/slots/empty_head.png"),
	GearDefinition.Slot.NECK: preload("res://art/ui/slots/empty_neck.png"),
	GearDefinition.Slot.SHOULDER: preload("res://art/ui/slots/empty_shoulder.png"),
	GearDefinition.Slot.BACK: preload("res://art/ui/slots/empty_back.png"),
	GearDefinition.Slot.CHEST: preload("res://art/ui/slots/empty_chest.png"),
	GearDefinition.Slot.WRIST: preload("res://art/ui/slots/empty_wrist.png"),
	GearDefinition.Slot.HANDS: preload("res://art/ui/slots/empty_hands.png"),
	GearDefinition.Slot.WAIST: preload("res://art/ui/slots/empty_waist.png"),
	GearDefinition.Slot.LEGS: preload("res://art/ui/slots/empty_legs.png"),
	GearDefinition.Slot.FEET: preload("res://art/ui/slots/empty_feet.png"),
	GearDefinition.Slot.RING: preload("res://art/ui/slots/empty_ring.png"),
	GearDefinition.Slot.TRINKET: preload("res://art/ui/slots/empty_trinket.png"),
	GearDefinition.Slot.MAIN_HAND: preload("res://art/ui/slots/empty_main_hand.png"),
	GearDefinition.Slot.OFF_HAND: preload("res://art/ui/slots/empty_off_hand.png"),
}
const EMPTY_SKILL := preload("res://art/ui/slots/empty_skill.png")
const SKILL_SLOTS := 6
const SLOT_SIZE := 50
const STASH_ICON_SIZE := 42
const STASH_COLUMNS := 10
## hero_actor body sprite is 906×389 at scale 0.23; gear extends past the body bounds.
const PREVIEW_BODY_WIDTH := 906.0 * 0.23
const PREVIEW_BODY_HEIGHT := 389.0 * 0.23
const PREVIEW_VIEWPORT_W := 128
const PREVIEW_VIEWPORT_H := int(PREVIEW_BODY_WIDTH) + 24

const GOLD = Color(0.85, 0.7, 0.28)
const PARCHMENT = Color(0.88, 0.82, 0.68)
const DIM = Color(0.62, 0.56, 0.44)

var hero_index := -1

# Rebuilt containers kept around for refresh().
var _name_edit: LineEdit
var _role_label: Label
var _equip_slots := {}        # Equip.Position -> DropTarget panel
var _skill_slots := []        # the SKILL_SLOTS skill DropTarget panels
var _gear_grid: GridContainer
var _preview_holder: Control
var _tooltip_panel: Panel
var _tooltip_left: VBoxContainer
var _tooltip_right: VBoxContainer
var _tooltip_compare_panel: Panel
var _tooltip_compare_box: VBoxContainer

# Click-to-carry: an alternative to dragging. Click an icon to pick it
# up onto the cursor, then click a slot or the hero panel to place it.
var _carried = null           # drag-style data dict, or null
var _carry_visual: Control    # icon following the cursor while carrying
var _carry_source             # LoadoutIcon picked up (dimmed while carried)

func _ready():
	layer = 12
	visible = false
	_build()

func open(index: int):
	hero_index = index
	visible = true
	refresh()

func close():
	cancel_carry()
	visible = false
	hero_index = -1
	closed.emit()

# --- Construction ----------------------------------------------------

func _build():

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)

	_build_left_panel()
	_build_right_tabs()
	_build_tooltip()
	_build_close_button()

func _place(ctrl, l, t, r, b, ax, ay, az, aw):
	ctrl.anchor_left = ax
	ctrl.anchor_top = ay
	ctrl.anchor_right = az
	ctrl.anchor_bottom = aw
	ctrl.offset_left = l
	ctrl.offset_top = t
	ctrl.offset_right = r
	ctrl.offset_bottom = b
	add_child(ctrl)
	return ctrl

func _panel(l, t, r, b, ax, ay, az, aw) -> Panel:
	var p = Panel.new()
	p.add_theme_stylebox_override("panel", _panel_style())
	return _place(p, l, t, r, b, ax, ay, az, aw)

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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _build_left_panel():
	var panel = DROP.new()
	panel.screen = self
	panel.target_kind = "auto"
	panel.add_theme_stylebox_override("panel", _panel_style())
	_place(panel, 40, 50, 640, -40, 0, 0, 0, 1)

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	vbox.add_child(_title("Hero"))

	_name_edit = LineEdit.new()
	_name_edit.add_theme_font_override("font", FONT)
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.add_theme_color_override("font_color", PARCHMENT)
	_name_edit.add_theme_stylebox_override("normal", _slot_style())
	_name_edit.add_theme_stylebox_override("focus", _panel_style())
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(0, 40)
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.focus_exited.connect(func(): _on_name_submitted(_name_edit.text))
	vbox.add_child(_name_edit)

	# Columns flanking the preview.
	var mid = HBoxContainer.new()
	mid.add_theme_constant_override("separation", 10)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(mid)

	mid.add_child(_build_slot_column(Equip.COLUMN_LEFT))

	_preview_holder = Control.new()
	_preview_holder.custom_minimum_size = Vector2(PREVIEW_VIEWPORT_W, PREVIEW_VIEWPORT_H)
	_preview_holder.clip_contents = false
	_preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_preview_holder)

	mid.add_child(_build_slot_column(Equip.COLUMN_RIGHT))

	_role_label = Label.new()
	_role_label.add_theme_font_override("font", FONT)
	_role_label.add_theme_font_size_override("font_size", 20)
	_role_label.add_theme_color_override("font_color", PARCHMENT)
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_role_label)

	# Weapon row.
	var weapons = HBoxContainer.new()
	weapons.alignment = BoxContainer.ALIGNMENT_CENTER
	weapons.add_theme_constant_override("separation", 14)
	weapons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(weapons)
	for pos in Equip.WEAPON_ROW:
		weapons.add_child(_build_equip_slot(pos))

	# Skill row (6 slots; only slot 0 is active for now).
	vbox.add_child(_title("Skills"))
	var skills = HBoxContainer.new()
	skills.alignment = BoxContainer.ALIGNMENT_CENTER
	skills.add_theme_constant_override("separation", 8)
	skills.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(skills)
	_skill_slots.clear()
	for i in range(SKILL_SLOTS):
		var slot = _make_slot("skill_view")  # read-only: rejects drops
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		_skill_slots.append(slot)
		skills.add_child(slot)

func _build_slot_column(positions: Array) -> VBoxContainer:
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pos in positions:
		col.add_child(_build_equip_slot(pos))
	return col

func _make_slot(target_kind) -> DropTarget:
	var slot = DROP.new()
	slot.screen = self
	slot.target_kind = target_kind
	slot.add_theme_stylebox_override("panel", _slot_style())
	slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	return slot

func _build_equip_slot(position: int) -> Control:
	var slot = _make_slot("equip:%d" % position)
	_equip_slots[position] = slot
	return slot

func _build_right_tabs():
	var tabs = TabContainer.new()
	tabs.add_theme_font_override("font", FONT)
	_place(tabs, -580, 50, -40, -40, 1, 0, 1, 1)

	# Gear tab: the stash grid in a scroll.
	var gear_tab = ScrollContainer.new()
	gear_tab.name = "Gear"
	gear_tab.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(gear_tab)
	var bin = DROP.new()
	bin.screen = self
	bin.target_kind = "gear_stash"
	bin.add_theme_stylebox_override("panel", _slot_style())
	bin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gear_tab.add_child(bin)
	_gear_grid = GridContainer.new()
	_gear_grid.columns = STASH_COLUMNS
	_gear_grid.add_theme_constant_override("h_separation", 6)
	_gear_grid.add_theme_constant_override("v_separation", 6)
	_gear_grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gear_grid.offset_left = 12
	_gear_grid.offset_top = 12
	_gear_grid.offset_right = -12
	_gear_grid.offset_bottom = -12
	bin.add_child(_gear_grid)

	# Skills tab: the known catalog (sparse for now).
	var skills_tab = ScrollContainer.new()
	skills_tab.name = "Skills"
	tabs.add_child(skills_tab)
	var skill_box = VBoxContainer.new()
	skill_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skills_tab.add_child(skill_box)
	var note = Label.new()
	note.text = "Active skills coming soon. Your attack follows your weapon."
	note.add_theme_color_override("font_color", DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_box.add_child(note)
	var grid = GridContainer.new()
	grid.columns = 4
	skill_box.add_child(grid)
	for skill in PlayerRoster.skill_catalog:
		grid.add_child(_make_icon("skill", skill, "catalog"))

func _build_tooltip():
	_tooltip_compare_panel = _panel(660, -270, -520, -40, 0, 1, 1, 1)
	_tooltip_compare_panel.visible = false
	_tooltip_compare_box = VBoxContainer.new()
	_tooltip_compare_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tooltip_compare_box.offset_left = 14
	_tooltip_compare_box.offset_top = 12
	_tooltip_compare_box.offset_right = -14
	_tooltip_compare_box.offset_bottom = -12
	_tooltip_compare_box.add_theme_constant_override("separation", 6)
	_tooltip_compare_panel.add_child(_tooltip_compare_box)

	_tooltip_panel = _panel(-580, -270, -40, -40, 1, 1, 1, 1)
	_tooltip_panel.visible = false

	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_tooltip_panel.add_child(margin)

	var cols = HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 18)
	margin.add_child(cols)

	_tooltip_left = VBoxContainer.new()
	_tooltip_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_left.custom_minimum_size = Vector2(200, 0)
	_tooltip_left.add_theme_constant_override("separation", 6)
	cols.add_child(_tooltip_left)

	_tooltip_right = VBoxContainer.new()
	_tooltip_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_right.custom_minimum_size = Vector2(180, 0)
	_tooltip_right.add_theme_constant_override("separation", 6)
	cols.add_child(_tooltip_right)

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
	icon.custom_minimum_size = Vector2(STASH_ICON_SIZE, STASH_ICON_SIZE)
	return icon

# --- Refresh ---------------------------------------------------------

func refresh():
	if hero_index < 0:
		return
	var hero = PlayerRoster.heroes[hero_index]
	_name_edit.text = hero.hero_name
	_role_label.text = _role_text()
	for pos in _equip_slots.keys():
		_fill_equip_slot(pos)
	_fill_skill_slots()
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

func _inset_icon(slot, icon):
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 3
	icon.offset_top = 3
	icon.offset_right = -3
	icon.offset_bottom = -3
	slot.add_child(icon)

func _fill_equip_slot(position: int):
	var slot = _equip_slots[position]
	_clear(slot)
	var item = PlayerRoster.equipped_item(hero_index, position)
	if item:
		_inset_icon(slot, _make_icon("gear", item, "equipped:%d" % position))
		return
	# Two-handed ghost in the off hand.
	if position == Equip.Position.OFF_HAND and _offhand_blocked():
		var main = PlayerRoster.equipped_item(hero_index, Equip.Position.MAIN_HAND)
		var ghost = _make_icon("twohand", main, "twohand")
		ghost.draggable = false
		ghost.modulate.a = 0.32
		_inset_icon(slot, ghost)
		return
	# Empty-slot silhouette.
	var hint = TextureRect.new()
	hint.texture = EMPTY_ICONS[Equip.category_of(position)]
	hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hint.modulate.a = 0.35
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inset_icon(slot, hint)

func _fill_skill_slots():
	var hero = PlayerRoster.heroes[hero_index]
	var skill = PlayerRoster.attack_skill(hero_index)
	for i in range(_skill_slots.size()):
		var slot = _skill_slots[i]
		_clear(slot)
		if i == 0 and skill:
			var icon = _make_icon("skill", skill, "skill_view")
			icon.draggable = false
			_inset_icon(slot, icon)
		elif i > 0 and i - 1 < hero.bonus_skills.size() \
				and hero.bonus_skills[i - 1] != null:
			var bonus = hero.bonus_skills[i - 1]
			var icon = _make_icon("skill", bonus, "skill:%d" % i)
			_inset_icon(slot, icon)
		else:
			var hint = TextureRect.new()
			hint.texture = EMPTY_SKILL
			hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hint.modulate.a = 0.3
			hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_inset_icon(slot, hint)

func _fill_gear_grid():
	_clear(_gear_grid)
	for gear in PlayerRoster.gear_stash:
		_gear_grid.add_child(_make_icon("gear", gear, "stash"))

func _update_preview():
	_clear(_preview_holder)

	var hero = PlayerRoster.heroes[hero_index]

	var vp_w := PREVIEW_VIEWPORT_W
	var vp_h := PREVIEW_VIEWPORT_H

	var vp = SubViewport.new()
	vp.size = Vector2i(vp_w, vp_h)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var actor_y := vp_h * 0.5

	var actor = hero.actor_scene.instantiate()
	actor.position = Vector2(vp_w / 2.0, actor_y)
	actor.scale = Vector2(1.0, 1.0)
	vp.add_child(actor)

	var container = SubViewportContainer.new()
	container.stretch = false
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.clip_contents = false
	container.set_anchors_preset(Control.PRESET_CENTER)
	container.offset_left = -vp_w / 2.0
	container.offset_right = vp_w / 2.0
	container.offset_top = -vp_h / 2.0
	container.offset_bottom = vp_h / 2.0
	container.add_child(vp)
	_preview_holder.add_child(container)
	actor.equip_gear(hero.equipped.values())

# --- Drag-and-drop policy --------------------------------------------

func can_accept(target_kind, data) -> bool:
	if target_kind == "skill_view":
		return false  # skill slots are read-only for now
	if target_kind == "gear_stash":
		return data.kind == "gear" and String(data.origin).begins_with("equipped")
	if target_kind == "auto":
		if data.kind != "gear" or data.origin != "stash":
			return false
		return PlayerRoster.default_position(hero_index, data.res) != -1
	if target_kind.begins_with("equip:"):
		if data.kind != "gear" or data.origin != "stash":
			return false
		var pos = int(target_kind.split(":")[1])
		return PlayerRoster.acceptable_positions(hero_index, data.res).has(pos)
	return false

func _offhand_blocked() -> bool:
	var main = PlayerRoster.equipped_item(hero_index, Equip.Position.MAIN_HAND)
	return main != null and main.weapon_type in [
		GearDefinition.WeaponType.TWO_HANDED, GearDefinition.WeaponType.BOW,
	]

func accept_drop(target_kind, data):
	if target_kind == "gear_stash":
		var pos = int(String(data.origin).split(":")[1])
		PlayerRoster.unequip_gear(hero_index, pos)
	elif target_kind == "auto":
		PlayerRoster.equip_gear(hero_index, data.res)
	elif target_kind.begins_with("equip:"):
		var pos = int(target_kind.split(":")[1])
		PlayerRoster.equip_gear(hero_index, data.res, pos)
	hide_tooltip()
	refresh()
	hero_changed.emit(hero_index)

# --- Tooltip ---------------------------------------------------------

func show_tooltip(kind, res):
	if res == null:
		return

	_clear_tooltips()

	if kind == "gear":
		_tooltip_gear(res)
	elif kind == "skill":
		_tooltip_skill(res)
	elif kind == "twohand":
		_tooltip_twohand(res)

	_tooltip_panel.visible = true
	_tooltip_compare_panel.visible = _tooltip_compare_box.get_child_count() > 0

func hide_tooltip():
	if _tooltip_panel:
		_tooltip_panel.visible = false
	if _tooltip_compare_panel:
		_tooltip_compare_panel.visible = false

func _clear_tooltips():
	_clear(_tooltip_left)
	_clear(_tooltip_right)
	_clear(_tooltip_compare_box)

func _tip_line(text, color := PARCHMENT, size := 20, column := 0):
	var box = _tooltip_left if column == 0 else _tooltip_right
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(l)

func _tip_cmp(text, color := PARCHMENT, size := 20):
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_compare_box.add_child(l)

func _divider(column := 0):
	var box = _tooltip_left if column == 0 else _tooltip_right
	box.add_child(HSeparator.new())

func _cmp_divider():
	_tooltip_compare_box.add_child(HSeparator.new())

func _tooltip_gear(gear: GearDefinition):
	_tip_line(gear.gear_name, ItemQuality.color(gear.quality), 26, 0)
	_tip_line(ItemQuality.tier_name(gear.quality), ItemQuality.color(gear.quality), 16, 0)
	_tip_line(_gear_subtitle(gear), DIM, 17, 0)

	var is_weapon := gear.attack_speed > 0.0 \
		or gear.weapon_type != GearDefinition.WeaponType.NONE
	if is_weapon:
		_tip_line("%d - %d Damage" % [
			gear.effective_damage_min(), gear.effective_damage_max()], PARCHMENT, 18, 0)
		if gear.attack_speed > 0.0:
			_tip_line("Speed: %.1fs" % gear.attack_speed, PARCHMENT, 18, 0)
			_tip_line("~%.1f DPS (avg)" % gear.weapon_dps(), DIM, 15, 0)
	elif gear.attack_bonus != 0:
		_tip_line("+%d Attack" % gear.attack_bonus, PARCHMENT, 18, 0)

	if gear.health_bonus != 0:
		_tip_line("+%d Health" % gear.health_bonus, PARCHMENT, 18, 1)

	_tip_line("Item level %d" % gear.item_level(), DIM, 16, 1)

	_fill_gear_compare(gear)

func _fill_gear_compare(gear: GearDefinition):
	if gear.slot == GearDefinition.Slot.MAIN_HAND \
			or gear.weapon_type == GearDefinition.WeaponType.ONE_HANDED \
			or gear.weapon_type == GearDefinition.WeaponType.TWO_HANDED \
			or gear.weapon_type == GearDefinition.WeaponType.BOW:
		_tip_cmp("Equipped weapons", GOLD, 22)
		var main = PlayerRoster.equipped_item(hero_index, Equip.Position.MAIN_HAND)
		_tip_cmp_line("Main hand", main)
		if _offhand_blocked():
			_tip_cmp("Off hand occupied (two-handed)", DIM, 16)
		else:
			var off = PlayerRoster.equipped_item(hero_index, Equip.Position.OFF_HAND)
			_tip_cmp_line("Off hand", off, off and off.attack_speed > 0.0)
	else:
		var equipped = _first_equipped_of_category(gear.slot)
		_tip_cmp("Equipped (%s)" % _category_label(gear.slot), GOLD, 22)
		if equipped:
			_tip_cmp_line("Currently", equipped)
		else:
			_tip_cmp("Slot is empty", DIM, 16)

func _tip_cmp_line(label: String, item: GearDefinition, is_weapon := false):
	if item == null:
		_tip_cmp("%s: empty" % label, DIM, 17)
		return
	var extra := ""
	if is_weapon:
		extra = "  (50% dmg)"
	_tip_cmp("%s: %s" % [label, item.gear_name], PARCHMENT, 18)
	_tip_cmp("  %s%s" % [_stat_summary(item), extra], DIM, 15)

func _first_equipped_of_category(category: int) -> GearDefinition:
	for pos in Equip.positions_for(category):
		var item = PlayerRoster.equipped_item(hero_index, pos)
		if item:
			return item
	return null

func _category_label(category: int) -> String:
	for pos in Equip.positions_for(category):
		return Equip.label(pos)
	return "?"

func _gear_subtitle(gear: GearDefinition) -> String:
	var slot_name = _category_label(gear.slot)
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
	if gear.attack_speed > 0.0 \
			or gear.weapon_type != GearDefinition.WeaponType.NONE:
		parts.append("%d-%d DMG" % [
			gear.effective_damage_min(), gear.effective_damage_max()])
	elif gear.attack_bonus != 0:
		parts.append("+%d ATK" % gear.attack_bonus)
	if gear.health_bonus != 0:
		parts.append("+%d HP" % gear.health_bonus)
	return ", ".join(parts) if not parts.is_empty() else "no bonuses"

func _tooltip_twohand(main: GearDefinition):
	_tip_line("Off Hand occupied", GOLD, 26, 0)
	_tip_line("Both hands are busy wielding:", DIM, 17, 0)
	if main:
		_tip_line(main.gear_name, PARCHMENT, 20, 0)
	_tip_line(
		"Swap the two-handed weapon for a one-handed one to free the off hand.",
		DIM, 16, 1)
	if main:
		_tip_cmp("Equipped weapons", GOLD, 22)
		_tip_cmp_line("Main hand", main, true)

func _tooltip_skill(skill: SkillDefinition):
	_tip_line(skill.skill_name, ItemQuality.color(skill.quality), 26, 0)
	_tip_line(ItemQuality.tier_name(skill.quality), ItemQuality.color(skill.quality), 16, 0)
	var ranged = skill.delivery_type == SkillDefinition.DeliveryType.PROJECTILE
	_tip_line("Ranged attack" if ranged else "Melee attack", DIM, 17, 0)
	_tip_line("Damage: +%d to +%d" % [
		skill.base_min_damage, skill.base_max_damage], PARCHMENT, 18, 0)
	_tip_line("Sets the hero to the %s row" % (
		"back" if ranged else "front"), DIM, 16, 1)

	var current = PlayerRoster.attack_skill(hero_index)
	if current:
		_tip_line("Current attack:", DIM, 16, 1)
		_tip_line(current.skill_name, PARCHMENT, 18, 1)

# --- Click-to-carry --------------------------------------------------

func is_carrying() -> bool:
	return _carried != null

func _process(_delta):
	if _carry_visual and is_instance_valid(_carry_visual):
		var m = _carry_visual.get_global_mouse_position()
		_carry_visual.global_position = m - _carry_visual.size * 0.5

func _input(event):
	if _carried == null:
		return
	# Right-click or Escape puts the carried item back down.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		cancel_carry()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_carry()
		get_viewport().set_input_as_handled()

## Called by an icon when it's clicked (not dragged).
func on_icon_clicked(icon):
	if _carried != null:
		if icon == _carry_source:
			cancel_carry()
			return
		var target = _ancestor_target_kind(icon)
		if target != "":
			place_on(target)
		return
	if icon.draggable and icon.res != null:
		begin_carry(icon)

## Right-click: equip from stash/catalog, unequip from worn slots.
func on_icon_right_clicked(icon):
	if icon.kind == "gear":
		if icon.origin == "stash":
			var data = {"kind": "gear", "res": icon.res, "origin": "stash"}
			if can_accept("auto", data):
				accept_drop("auto", data)
		elif String(icon.origin).begins_with("equipped:"):
			var pos = int(String(icon.origin).split(":")[1])
			PlayerRoster.unequip_gear(hero_index, pos)
			hide_tooltip()
			refresh()
			hero_changed.emit(hero_index)
	elif icon.kind == "skill":
		if icon.origin == "catalog":
			var slot = PlayerRoster.first_empty_bonus_skill_slot(hero_index)
			if slot != -1:
				PlayerRoster.equip_bonus_skill(hero_index, icon.res, slot)
				hide_tooltip()
				refresh()
				hero_changed.emit(hero_index)
		elif String(icon.origin).begins_with("skill:"):
			var slot = int(String(icon.origin).split(":")[1])
			if slot > 0:
				PlayerRoster.unequip_bonus_skill(hero_index, slot)
				hide_tooltip()
				refresh()
				hero_changed.emit(hero_index)

func begin_carry(icon):
	_carried = {"kind": icon.kind, "res": icon.res, "origin": icon.origin}
	_carry_source = icon
	icon.modulate.a = 0.35
	hide_tooltip()

	var v = TextureRect.new()
	var tex: Texture2D = icon.display_texture() if icon.has_method("display_texture") else icon.texture
	v.texture = tex
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.size = Vector2(48, 48)
	v.modulate.a = 0.9
	# Must not eat the click that places it.
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_carry_visual = v
	_process(0.0)

## Try to place the carried item onto a target. Keeps carrying on a
## rejected target so the player can aim at another one.
func place_on(target_kind) -> bool:
	if _carried == null:
		return false
	if not can_accept(target_kind, _carried):
		return false
	var data = _carried
	_clear_carry()
	accept_drop(target_kind, data)
	return true

func cancel_carry():
	if _carry_source and is_instance_valid(_carry_source):
		_carry_source.modulate.a = 1.0
	_clear_carry()

func _clear_carry():
	if _carry_visual and is_instance_valid(_carry_visual):
		_carry_visual.queue_free()
	_carry_visual = null
	_carried = null
	_carry_source = null

func _ancestor_target_kind(node) -> String:
	var n = node.get_parent()
	while n:
		if n is DropTarget:
			return n.target_kind
		n = n.get_parent()
	return ""

# --- Input -----------------------------------------------------------

func _on_dim_input(event):
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		# A click on the backdrop drops a carried item; otherwise closes.
		if _carried != null:
			cancel_carry()
		else:
			close()

func _on_name_submitted(text):
	PlayerRoster.rename_hero(hero_index, text)
	_name_edit.text = PlayerRoster.heroes[hero_index].hero_name
	_name_edit.release_focus()
	hero_changed.emit(hero_index)

extends Node

## Opens the camp, pops the loadout screen for a hero, and screenshots
## it (plus a hover state) for verification.

var out_dir := ProjectSettings.globalize_path("res://docs/screenshots")

func _ready():
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _snap(name):
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])

func _run():
	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	await get_tree().create_timer(0.8).timeout

	# Hover the melee hero so the outline + nameplate show.
	camp.stage._set_hover(0, true)
	await _snap("camp_hover")
	camp.stage._set_hover(0, false)

	# Open the loadout for the melee hero.
	camp.loadout.open(0)
	await get_tree().create_timer(0.5).timeout
	await _snap("loadout_open")

	# Show a tooltip for the bow in the stash.
	camp.loadout.show_tooltip("gear", PlayerRoster.BOW)
	await _snap("loadout_tooltip")

	# Drive a real drop through the screen: equip the stash bow on the
	# melee hero. The preview should swap to a bow and the role flip.
	var bow = null
	for g in PlayerRoster.gear_stash:
		if g.weapon_type == GearDefinition.WeaponType.BOW:
			bow = g
			break
	camp.loadout.hide_tooltip()

	# Drop the bow directly on the OCCUPIED main-hand slot's icon, the
	# way a real drag lands. The icon should forward to its slot and
	# swap sword -> bow without unequipping first.
	var slot = camp.loadout._equip_slots[GearDefinition.Slot.MAIN_HAND]
	var equipped_icon = slot.get_child(0)
	var data = {"kind": "gear", "res": bow, "origin": "stash"}
	print("occupied slot can_drop=%s" % equipped_icon._can_drop_data(Vector2.ZERO, data))
	equipped_icon._drop_data(Vector2.ZERO, data)
	await get_tree().create_timer(0.4).timeout
	print("after drop on occupied slot: ranged=%s" % PlayerRoster.is_ranged(0))

	# Bow is two-handed: the off-hand should now show a dimmed ghost.
	var off = camp.loadout._equip_slots[GearDefinition.Slot.OFF_HAND]
	var ghost = off.get_child(0) if off.get_child_count() > 0 else null
	print("offhand ghost present=%s alpha=%s" % [
		ghost != null,
		(ghost.modulate.a if ghost else -1.0),
	])
	await _snap("loadout_equipped_bow")

	# Auto-drop: drop a stash one-handed sword anywhere on the hero panel
	# (not a specific slot) and it should equip + flip back to melee.
	var sword = null
	for g in PlayerRoster.gear_stash:
		if g.slot == GearDefinition.Slot.MAIN_HAND \
				and g.weapon_type == GearDefinition.WeaponType.ONE_HANDED:
			sword = g
			break
	var sdata = {"kind": "gear", "res": sword, "origin": "stash"}
	print("auto can_accept sword=%s" % camp.loadout.can_accept("auto", sdata))
	camp.loadout.accept_drop("auto", sdata)
	await get_tree().create_timer(0.4).timeout
	print("after auto-drop sword: ranged=%s" % PlayerRoster.is_ranged(0))

	get_tree().quit()

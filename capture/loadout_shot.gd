extends Node

## Opens the camp, pops the loadout screen for a hero, and screenshots
## it (plus hover, tooltip, carry, bow, and dual-wield states) for verification.

var out_dir := ProjectSettings.globalize_path("res://docs/screenshots")

func _ready():
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _snap(name):
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])

func _stash_one_handed() -> GearDefinition:
	for g in PlayerRoster.gear_stash:
		if g.weapon_type == GearDefinition.WeaponType.ONE_HANDED:
			return g
	return null

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

	# Tooltip on a weapon (damage range + compare panel).
	camp.loadout.show_tooltip("gear", PlayerRoster.SWORD)
	await _snap("loadout_tooltip")

	# Click-to-carry: pick up a stash item and let it ride the cursor.
	camp.loadout.hide_tooltip()
	var carry_icon = camp.loadout._gear_grid.get_child(0)
	camp.loadout.on_icon_clicked(carry_icon)
	get_viewport().warp_mouse(Vector2(280, 500))
	await get_tree().process_frame
	await _snap("loadout_carry")
	camp.loadout.cancel_carry()

	# Equip the stash bow on the occupied main-hand slot (swap sword -> bow).
	var bow = null
	for g in PlayerRoster.gear_stash:
		if g.weapon_type == GearDefinition.WeaponType.BOW:
			bow = g
			break
	camp.loadout.hide_tooltip()

	camp.loadout.accept_drop("equip:%d" % Equip.Position.MAIN_HAND, {
		"kind": "gear", "res": bow, "origin": "stash",
	})
	await get_tree().create_timer(0.4).timeout

	var off = camp.loadout._equip_slots[Equip.Position.OFF_HAND]
	var ghost = off.get_child(0) if off.get_child_count() > 0 else null
	print("offhand ghost present=%s alpha=%s" % [
		ghost != null,
		(ghost.modulate.a if ghost else -1.0),
	])
	await _snap("loadout_equipped_bow")

	# Auto-drop a one-handed sword back to melee.
	var sword = _stash_one_handed()
	var sdata = {"kind": "gear", "res": sword, "origin": "stash"}
	camp.loadout.accept_drop("auto", sdata)
	await get_tree().create_timer(0.4).timeout

	# Dual-wield: equip another 1H weapon in the off hand.
	var off_weapon = _stash_one_handed()
	if off_weapon:
		camp.loadout.accept_drop("equip:%d" % Equip.Position.OFF_HAND, {
			"kind": "gear", "res": off_weapon, "origin": "stash",
		})
		await get_tree().create_timer(0.4).timeout
		camp.loadout.show_tooltip("gear", PlayerRoster.equipped_item(0, Equip.Position.MAIN_HAND))
		await _snap("loadout_dualwield")

	get_tree().quit()

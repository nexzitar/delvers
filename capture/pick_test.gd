extends Node

## Verifies the camp's hero hit-testing: a hero's own box center should
## resolve to that hero, a far-away point to nobody, and the hover
## highlight + selection signal should toggle correctly.

func _ready():
	_run()

func _run():
	var camp = load("res://scenes/camp/camp.tscn").instantiate()
	add_child(camp)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout

	var stage = camp.stage
	var failures = 0

	# Each seated hero's center should hit itself; nowhere else.
	for hero_index in stage._seated:
		var center = stage._seated[hero_index].center
		var hit = stage.hit_test(center)
		failures += _check(hit == hero_index,
			"center of hero %d resolves to %d" % [hero_index, hit])

	failures += _check(stage.hit_test(Vector2(-5000, -5000)) == -1,
		"far point resolves to nobody")

	# Hover highlight toggles the nameplate.
	var rec0 = stage._seated[0]
	stage._set_hover(0, true)
	failures += _check(rec0.plate.visible, "hover shows nameplate")
	stage._set_hover(0, false)
	failures += _check(not rec0.plate.visible, "unhover hides nameplate")

	# Selecting a hero opens the loadout and pauses picking.
	var got = {"i": -1}
	stage.hero_selected.connect(func(i): got.i = i)
	stage.hero_selected.emit(0)
	camp._on_hero_selected(0)
	await get_tree().process_frame
	failures += _check(camp.loadout.visible, "loadout opens on select")
	failures += _check(not stage._picking_enabled, "picking paused while open")

	# Closing resumes picking.
	camp.loadout.close()
	await get_tree().process_frame
	failures += _check(stage._picking_enabled, "picking resumes on close")

	print("ALL CHECKS PASSED" if failures == 0 else "FAILURES: %d" % failures)
	get_tree().quit()

func _check(cond, label):
	print(("  ok  - " if cond else "  FAIL - ") + label)
	return 0 if cond else 1

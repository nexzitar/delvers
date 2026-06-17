extends Node

## Renders each unit's actor scene against a transparent background and
## saves an alpha-trimmed PNG for the README cast gallery.

var out_dir := ProjectSettings.globalize_path("res://docs/screenshots")

func _ready():
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _run():

	for i in PlayerRoster.heroes.size():
		var template = PlayerRoster.heroes[i]
		var actor = template.actor_scene.instantiate()
		var names = ["hero_default_delver", "hero_default_delver_archer"]
		var file = names[i] if i < names.size() else template.hero_id
		var equipped = template.equipped
		await _shoot(actor, file, equipped)

	await _shoot(
		load("res://scenes/theater/actors/slime_actor.tscn").instantiate(),
		"enemy_green_slime", []
	)
	await _shoot(
		load("res://scenes/theater/actors/goblin_archer_actor.tscn").instantiate(),
		"enemy_goblin_archer", []
	)

	get_tree().quit()

func _shoot(actor, file, loadout):

	var viewport = SubViewport.new()
	viewport.size = Vector2i(700, 700)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	actor.position = Vector2(350, 480)
	viewport.add_child(actor)
	if loadout is Dictionary and not loadout.is_empty():
		actor.equip_gear(loadout)
	elif loadout is Array and not loadout.is_empty():
		actor.equip_gear(loadout)

	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var img = viewport.get_texture().get_image()
	var rect = img.get_used_rect()
	img = img.get_region(rect)
	img.save_png("%s/%s.png" % [out_dir, file])
	print("saved %s %s" % [file, rect])

	viewport.queue_free()

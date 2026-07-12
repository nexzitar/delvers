extends Node
## Renders the portrait strip: Garrick, warrior, chief, slime.
func _ready():
	var layer := CanvasLayer.new()
	add_child(layer)
	var row := HBoxContainer.new()
	row.position = Vector2(100, 100)
	row.add_theme_constant_override("separation", 20)
	layer.add_child(row)
	PlayerRoster.autosave = false
	var hero = PlayerRoster.heroes[0]
	var subjects = []
	subjects.append(await Portrait3D.for_hero(hero.equipped, self,
		hero.model_scene.resource_path))
	for eid in ["goblin_warrior", "goblin_chief", "green_slime"]:
		var t = load("res://resources/enemies/%s.tres" % eid)
		subjects.append(await Portrait3D.for_enemy(t, self))
	for tex in subjects:
		var r := TextureRect.new()
		r.texture = tex
		r.custom_minimum_size = Vector2(200, 200)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(r)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		ProjectSettings.globalize_path("res://capture/proto3d/renders/portrait_probe.png"))
	print("PORTRAIT PROBE DONE")
	get_tree().quit()

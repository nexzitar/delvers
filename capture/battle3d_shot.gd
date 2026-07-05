extends Node

## Snapshots the live 3D battle theater (real sim + replay) at a few
## points into capture/proto3d/renders/ for visual verification.

var out_dir := ProjectSettings.globalize_path("res://capture/proto3d/renders")

func _ready():
	DirAccess.make_dir_recursive_absolute(out_dir)
	PlayerRoster.unlocked_dungeons = ["darkwood", "spider_nest"]
	PlayerRoster.start_delve("spider_nest")
	PlayerRoster.delve_room = 5
	PlayerRoster.heroes[0].equipped = {
		Equip.Position.MAIN_HAND: LootTable.materialize("starter_sword", 12, 2, "virulent"),
		Equip.Position.OFF_HAND: LootTable.materialize("starter_shield", 12, 2),
		Equip.Position.HEAD: LootTable.materialize("starter_helmet", 12, 1),
		Equip.Position.CHEST: LootTable.materialize("starter_armor", 12, 1),
	}
	PlayerRoster._sync_role(PlayerRoster.heroes[0])
	PlayerRoster.equip_bonus_skill(0, load("res://resources/skills/heal.tres"), 1)
	var scene = load("res://scenes/theater/battle_theater_3d.tscn").instantiate()
	add_child(scene)
	_run()

func _snap(file_name):
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, file_name])

func _run():
	await get_tree().create_timer(2.0).timeout
	await _snap("battle3d_early")
	await get_tree().create_timer(4.0).timeout
	await _snap("battle3d_mid")
	await get_tree().create_timer(6.0).timeout
	await _snap("battle3d_late")
	get_tree().quit()

class_name Portrait3D

## Renders unit portraits straight from the 3D rigs, so the side panels
## always match what's on the field (loadout changes included). Results
## are cached per appearance; rendering takes one frame, so callers get
## the texture via await.

const SlimeRig = preload("res://scripts/theater3d/slime_rig.gd")

const SIZE := Vector2i(96, 96)

static var _cache := {}

## Portrait for a SPAWN event (hero loadout or enemy template).
static func from_spawn(event, host: Node) -> Texture2D:
	if event.team == CombatEntity.Team.HERO:
		return await for_hero(event.equipped, host)
	return await for_enemy(event.template, host)

static func for_hero(equipped: Dictionary, host: Node) -> Texture2D:
	var ids := []
	for pos in equipped:
		ids.append("%s:%s" % [pos, equipped[pos].gear_id])
	ids.sort()
	var key = "hero|" + ",".join(ids)
	if _cache.has(key):
		return _cache[key]
	var rig = ActorFactory3D.build_hero(equipped)
	return await _render(key, rig, host)

static func for_enemy(template, host: Node) -> Texture2D:
	var key = "enemy|" + template.enemy_id
	if _cache.has(key):
		return _cache[key]
	var rig = ActorFactory3D.build_enemy(template)
	return await _render(key, rig, host)

static func _render(key: String, rig: Node3D, host: Node) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35, -30, 0)
	key_light.light_energy = 1.2
	vp.add_child(key_light)

	var camera := Camera3D.new()
	camera.fov = 30
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.85
	camera.environment = env
	vp.add_child(camera)

	vp.add_child(rig)
	# Bust framing for humanoids, whole-blob framing for slimes.
	if rig is SlimeRig:
		camera.position = Vector3(0, 0.42, 1.35) * maxf(rig.scale.y, 1.0)
		camera.look_at(Vector3(0, 0.26 * rig.scale.y, 0))
	else:
		var head_y = 0.9 * rig.scale.y
		camera.position = Vector3(0, head_y + 0.06, 0.98 * rig.scale.y)
		camera.look_at(Vector3(0, head_y, 0))

	host.add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image = vp.get_texture().get_image()
	vp.queue_free()

	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

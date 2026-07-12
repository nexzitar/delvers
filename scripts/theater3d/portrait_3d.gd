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
		return await for_hero(event.equipped, host, event.model_path)
	return await for_enemy(event.template, host)

static func for_hero(equipped: Dictionary, host: Node, model_path := "") -> Texture2D:
	var ids := []
	for pos in equipped:
		ids.append("%s:%s" % [pos, equipped[pos].gear_id])
	ids.sort()
	var key = "hero|%s|%s" % [model_path, ",".join(ids)]
	if _cache.has(key):
		return _cache[key]
	var rig = ActorFactory3D.build_hero(equipped, model_path)
	if rig is AnimatedActor:
		rig.pose_idle(0.2)
	return await _render(key, rig, host)

static func for_enemy(template, host: Node) -> Texture2D:
	var key = "enemy|" + template.enemy_id
	if _cache.has(key):
		return _cache[key]
	var rig: Node3D
	if template.model_scene != null:
		var path: String = template.model_scene.resource_path
		var config = ActorFactory3D.MODEL_CONFIGS.get(path, {}).duplicate(true)
		rig = AnimatedActor.new(load(path), config)
		rig.pose_idle(0.2)
	else:
		rig = ActorFactory3D.build_enemy(template)
	return await _render(key, rig, host)

## Union of all mesh AABBs in rig-parent space (rig sits at the origin,
## so this is also camera space for the portrait viewport).
static func _rig_aabb(rig: Node3D) -> AABB:
	var merged := AABB()
	var first := true
	var stack := [[rig, Transform3D()]]
	while not stack.is_empty():
		var entry = stack.pop_back()
		var n = entry[0]
		var xf: Transform3D = entry[1]
		if n is Node3D:
			xf = xf * n.transform
		if n is MeshInstance3D:
			var b: AABB = xf * n.get_aabb()
			merged = b if first else merged.merge(b)
			first = false
		for c in n.get_children():
			stack.append([c, xf])
	return merged

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

	if rig.get_parent() == null:
		vp.add_child(rig)
	# Bust framing for humanoids, whole-blob framing for slimes.
	if rig is SlimeRig:
		camera.position = Vector3(0, 0.42, 1.35) * maxf(rig.scale.y, 1.0)
		camera.look_at_from_position(
			camera.position, Vector3(0, 0.26 * rig.scale.y, 0)
		)
	elif rig is AnimatedActor:
		# Chibi models carry huge heads: aim at the face, a third of
		# a head below the crown. Mesh AABBs are local to nodes with
		# their own scales, so accumulate transforms down from the rig.
		var box := _rig_aabb(rig)
		var h := box.end.y
		# Distance follows the smaller extent: wide-headed goblins need
		# the full height back-off, tall narrow delvers sit closer.
		var face_y = h * 0.75
		camera.position = Vector3(0, face_y + 0.05, minf(h, box.size.x) * 1.15)
		camera.look_at_from_position(camera.position, Vector3(0, face_y, 0))
	else:
		var head_y = 0.9 * rig.scale.y
		camera.position = Vector3(0, head_y + 0.06, 0.98 * rig.scale.y)
		camera.look_at_from_position(camera.position, Vector3(0, head_y, 0))

	host.add_child(vp)
	if OS.has_environment("PORTRAIT_DEBUG"):
		print("PORTRAIT %s box=%s cam=%s" % [key, _rig_aabb(rig), camera.position])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image = vp.get_texture().get_image()
	vp.queue_free()

	var texture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture

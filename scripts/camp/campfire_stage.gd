extends Node2D
class_name CampfireStage

## Shared backdrop for the main menu and the camp scene: the night
## clearing, the smoldering fire, and the party seated around it.
##
## When `interactive` is on (the camp scene), seated heroes can be
## hovered for an outline + nameplate and clicked to open their
## loadout, via the `hero_selected` signal.

signal hero_selected(hero_index: int)

## Distance from an actor's origin (sprite center) down to its feet.
const ACTOR_FOOT_OFFSET = 104.0

const OUTLINE_SHADER = preload("res://art/shaders/sprite_outline.gdshader")
const NAMEPLATE_FONT = preload("res://art/fonts/Herculanum.ttf")

## Slight scale-up for a more intimate framing, pivoting on the fire.
@export var zoom := 1.0
@export var zoom_center := Vector2(820, 620)

## Camp scene turns this on to let the player pick heroes.
@export var interactive := false

@onready var seats_root = $Seats
@onready var campfire = $Seats/Campfire

# hero_index -> {
#   "seat": Marker2D, "actor": Node2D, "plate": Control,
#   "center": Vector2, "half": Vector2  (hit box in seats_root space)
# }
var _seated := {}

## Mouse hover/click hit-testing is done by polling in _process (rather
## than Area2D physics picking), so it works regardless of window focus
## quirks and overlapping Control mouse filters.
var _picking_enabled := true
var _hovered := -1
var _was_pressed := false

func _ready():

	if zoom != 1.0:
		scale = Vector2.ONE * zoom
		position = zoom_center * (1.0 - zoom)

	campfire.intensity = PlayerRoster.fire_intensity()

	_seat_heroes()

func _seat_heroes():

	var seats = []
	for child in seats_root.get_children():
		if child is Marker2D:
			seats.append(child)

	var assignment = _resolve_seating(seats)

	for seat_name in assignment:
		var hero_index = assignment[seat_name]
		var seat = seats_root.get_node(NodePath(seat_name))
		_spawn_seated(seat, hero_index)

## Rebuilds a hero's seated actor in place (e.g. after a loadout change).
func refresh_hero(hero_index: int):
	if not _seated.has(hero_index):
		return
	var record = _seated[hero_index]
	var seat = record.seat
	if is_instance_valid(record.actor):
		record.actor.queue_free()
	if is_instance_valid(record.plate):
		record.plate.queue_free()
	_spawn_seated(seat, hero_index)

func _spawn_seated(seat, hero_index):

	var template = PlayerRoster.heroes[hero_index]

	var actor = template.actor_scene.instantiate()
	seat.add_child(actor)

	# Seats further back are smaller, for a touch of depth.
	var depth = remap(
		clampf(seat.position.y, 520.0, 820.0),
		520.0, 820.0, 0.72, 1.0
	)
	actor.scale = Vector2(depth, depth)

	# Everyone turns toward the fire.
	if seat.position.x > campfire.position.x:
		actor.scale.x = -depth

	# Seat markers sit on the ground line; lift the actor so its
	# feet land on the marker.
	actor.position = Vector2(0, -ACTOR_FOOT_OFFSET * depth)

	actor.equip_gear(template.equipped)

	var plate = null
	if interactive:
		plate = _make_nameplate(template.hero_name, depth)
		seat.add_child(plate)

	# Hit box covering the body, in seats_root-local space.
	var center = seat.position + Vector2(0, -(ACTOR_FOOT_OFFSET + 25) * depth)
	var half = Vector2(48, 125) * depth

	_seated[hero_index] = {
		"seat": seat, "actor": actor, "plate": plate,
		"center": center, "half": half,
	}

func _make_nameplate(text, depth) -> Control:
	var plate = Label.new()
	plate.text = text
	plate.add_theme_font_override("font", NAMEPLATE_FONT)
	plate.add_theme_font_size_override("font_size", int(30 * depth))
	plate.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	plate.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	plate.add_theme_constant_override("outline_size", 8)
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate.size = Vector2(260, 40)
	plate.position = Vector2(-130, -250 * depth)
	plate.visible = false
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate

func _process(_delta):
	if not interactive or not _picking_enabled:
		return

	var hovered = hit_test(seats_root.get_local_mouse_position())

	if hovered != _hovered:
		_set_hover(_hovered, false)
		_set_hover(hovered, true)
		_hovered = hovered

	# Edge-detect a left click on the hovered hero.
	var pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed and not _was_pressed and hovered != -1:
		hero_selected.emit(hovered)
	_was_pressed = pressed

## Returns the hero index whose body box contains the given point
## (in seats_root-local space), or -1. When boxes overlap (adjacent
## seats), the hero whose center is nearest the point wins.
func hit_test(local_pos: Vector2) -> int:
	var best := -1
	var best_dist := INF
	for hero_index in _seated:
		var record = _seated[hero_index]
		var d = local_pos - record.center
		if absf(d.x) <= record.half.x and absf(d.y) <= record.half.y:
			var dist = d.length_squared()
			if dist < best_dist:
				best_dist = dist
				best = hero_index
	return best

func _set_hover(hero_index, on):
	if hero_index == -1 or not _seated.has(hero_index):
		return
	var record = _seated[hero_index]
	_set_outline(record.actor, on)
	if is_instance_valid(record.plate):
		record.plate.visible = on

## Turns hero picking on or off (the camp disables it while the loadout
## modal is open) and clears any active highlight.
func set_picking(enabled):
	_picking_enabled = enabled
	if not enabled:
		clear_hover()

## Clears any active hover highlight (used when a modal takes over).
func clear_hover():
	_set_hover(_hovered, false)
	_hovered = -1

func _set_outline(actor, on):
	if not is_instance_valid(actor):
		return
	var sprites = actor.find_children("*", "Sprite2D", true, false)
	for sprite in sprites:
		if on:
			var mat = ShaderMaterial.new()
			mat.shader = OUTLINE_SHADER
			# Keep the outline ~3px on screen regardless of how much
			# this particular sprite is scaled down.
			var gscale = sprite.global_scale
			var avg = max(0.02, (abs(gscale.x) + abs(gscale.y)) * 0.5)
			mat.set_shader_parameter("outline_width", clampf(3.0 / avg, 1.0, 30.0))
			sprite.material = mat
		else:
			sprite.material = null

func _resolve_seating(seats) -> Dictionary:

	if PlayerRoster.keep_seating:
		PlayerRoster.keep_seating = false
		if _seating_valid(PlayerRoster.saved_seating, seats):
			return PlayerRoster.saved_seating

	seats.shuffle()

	var assignment = {}
	for i in mini(PlayerRoster.heroes.size(), seats.size()):
		assignment[String(seats[i].name)] = i

	PlayerRoster.saved_seating = assignment
	return assignment

func _seating_valid(assignment, seats) -> bool:

	if assignment.size() != mini(PlayerRoster.heroes.size(), seats.size()):
		return false

	var seat_names = seats.map(func(seat): return String(seat.name))
	for seat_name in assignment:
		if not seat_names.has(seat_name):
			return false

	return true

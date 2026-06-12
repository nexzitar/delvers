extends Node2D
class_name CampfireStage

## Shared backdrop for the main menu and the camp scene: the night
## clearing, the smoldering fire, and the party seated around it.

## Distance from an actor's origin (sprite center) down to its feet.
const ACTOR_FOOT_OFFSET = 104.0

## Slight scale-up for a more intimate framing, pivoting on the fire.
@export var zoom := 1.0
@export var zoom_center := Vector2(820, 620)

@onready var seats_root = $Seats
@onready var campfire = $Seats/Campfire

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

	seats.shuffle()

	for i in mini(PlayerRoster.heroes.size(), seats.size()):

		var template = PlayerRoster.heroes[i]
		var seat = seats[i]

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

		actor.equip_gear(template.starting_gear)

extends Node2D
class_name Campfire

## How lively the fire burns: 0.0 is cold ashes with a few embers,
## 1.0 is a healthy glow. Grows with the party's deeds.
@export_range(0.0, 1.0) var intensity := 0.15:
	set(value):
		intensity = value
		_apply_intensity()

@onready var glow = $Glow
@onready var embers = $Embers

# Random start phase so multiple fires never flicker in sync.
var _time := randf() * 100.0

func _ready():
	_apply_intensity()

func _process(delta):
	_time += delta

	# Two unsynced sine waves make an organic flicker.
	var flicker = (
		0.75
		+ 0.18 * sin(_time * 2.3)
		+ 0.12 * sin(_time * 5.7 + 1.3)
	)
	glow.modulate.a = clampf((0.3 + intensity * 0.7) * flicker, 0.0, 1.0)

func _apply_intensity():

	if not is_node_ready():
		return

	embers.amount = int(lerpf(5.0, 40.0, intensity))
	glow.scale = Vector2.ONE * lerpf(1.15, 2.3, intensity)

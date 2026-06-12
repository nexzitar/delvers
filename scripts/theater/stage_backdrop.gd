@tool
extends TextureRect
class_name StageBackdrop

## Backdrops this stage can display; switch with backdrop_index.
@export var backdrops: Array[Texture2D]

@export var backdrop_index: int = 0:
	set(value):
		backdrop_index = value
		_apply_backdrop()

func _ready():
	_apply_backdrop()

func _apply_backdrop():
	if backdrops.is_empty():
		return
	texture = backdrops[clampi(backdrop_index, 0, backdrops.size() - 1)]

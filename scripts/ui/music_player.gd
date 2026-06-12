extends AudioStreamPlayer

## Plays its stream as looping background music on the Music bus.
## Looping itself comes from the wav's import settings.

func _ready():
	bus = &"Music"
	play()

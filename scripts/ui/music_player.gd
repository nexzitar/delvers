extends AudioStreamPlayer

## Plays its stream as looping background music on the Music bus.

func _ready():
	bus = &"Music"
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	play()

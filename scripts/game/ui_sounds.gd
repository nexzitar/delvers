extends Node

## Autoloaded one-shot sound helper for UI feedback and ambience
## stingers. Players are created on demand and freed when done.

const HOVER = preload("res://audio/ui_hover.wav")
const CLICK = preload("res://audio/ui_click.wav")
const CREAK = preload("res://audio/sign_creak.wav")

func hover():
	play(HOVER, "SFX", -10.0)

func click():
	play(CLICK, "SFX", -4.0)

func creak():
	play(CREAK, "Ambience", -14.0, randf_range(0.85, 1.15))

func play(stream, bus := "SFX", volume_db := 0.0, pitch := 1.0):

	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

## Hooks hover/click feedback onto every button under the given node.
func wire_buttons(root):
	for button in root.find_children("*", "Button", true, false):
		button.mouse_entered.connect(hover)
		button.pressed.connect(click)

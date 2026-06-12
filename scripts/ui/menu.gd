extends Control

const CAMP_SCENE = "res://scenes/camp/camp.tscn"

## How far the camp scene zooms in, mirrored here so the Enter
## transition lands exactly on the camp's framing.
const CAMP_ZOOM = 1.12

@onready var stage = $Stage
@onready var hanging_sign = $HangingSign

var _sway_time := randf() * 100.0
var _last_sway_direction := 0
var _transitioning := false

func _ready():
	UiSounds.wire_buttons(self)

func _process(delta):

	_sway_time += delta

	# Two slow sine waves give the sign a lazy, irregular swing.
	var angle = (
		1.7 * sin(_sway_time * 0.8)
		+ 0.5 * sin(_sway_time * 2.1)
	)
	hanging_sign.rotation_degrees = angle

	_maybe_creak(angle)

func _maybe_creak(angle):

	# The rope creaks near the swing's turning points.
	var direction = 1 if angle > hanging_sign.get_meta("prev_angle", 0.0) else -1
	hanging_sign.set_meta("prev_angle", angle)

	if direction != _last_sway_direction:
		_last_sway_direction = direction
		if randf() < 0.4:
			UiSounds.creak()

func _on_enter_pressed():

	if _transitioning:
		return
	_transitioning = true

	# The party keeps their seats through the transition into camp.
	PlayerRoster.keep_seating = true

	var transition = create_tween().set_parallel(true)

	transition.tween_property(
		stage, "scale", Vector2.ONE * CAMP_ZOOM, 1.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	transition.tween_property(
		stage, "position", stage.zoom_center * (1.0 - CAMP_ZOOM), 1.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	transition.tween_property($Logo, "modulate:a", 0.0, 0.7)
	transition.tween_property(hanging_sign, "modulate:a", 0.0, 0.7)
	transition.tween_property($ColorRect, "color:a", 0.0, 0.7)

	await transition.finished

	get_tree().change_scene_to_file(CAMP_SCENE)

func _on_settings_pressed():
	$SettingsPanel.open()

func _on_exit_pressed():
	get_tree().quit()

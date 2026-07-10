class_name OrbitCamera
extends Camera3D

## Editor-style orbit rig: drag to circle the target, wheel to zoom,
## (optionally) middle-drag or shift-drag to pan the target itself.
## Disabled by default so scripted framing stays in charge until a
## scene opts in.

@export var enabled := false
@export var target := Vector3.ZERO
@export var distance := 5.0
@export var yaw := 0.0
@export var pitch := 0.55
@export var min_distance := 1.0
@export var max_distance := 14.0
@export var min_pitch := 0.08
@export var max_pitch := 1.35
## Which mouse button orbits (camp uses RIGHT so clicks stay free).
@export var orbit_button := MOUSE_BUTTON_LEFT
@export var allow_pan := false

var _orbiting := false
var _panning := false

## Adopt whatever framing a script just set, so the first drag
## continues from there instead of snapping.
func adopt_current():
	var offset = position - target
	distance = clampf(offset.length(), min_distance, max_distance)
	yaw = atan2(offset.x, offset.z)
	pitch = clampf(asin(offset.y / maxf(offset.length(), 0.001)), min_pitch, max_pitch)
	_refresh()

func _unhandled_input(event):
	if not enabled:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					distance = clampf(distance * 0.9, min_distance, max_distance)
					_refresh()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					distance = clampf(distance * 1.1, min_distance, max_distance)
					_refresh()
			MOUSE_BUTTON_MIDDLE:
				_panning = event.pressed and allow_pan
			_:
				if event.button_index == orbit_button:
					if allow_pan and event.pressed and event.shift_pressed:
						_panning = true
					else:
						_orbiting = event.pressed
						if not event.pressed:
							_panning = false
	elif event is InputEventMouseMotion:
		if _panning:
			var right = global_basis.x
			var up = global_basis.y
			target += (-right * event.relative.x + up * event.relative.y) \
				* distance * 0.0016
			_refresh()
		elif _orbiting:
			yaw -= event.relative.x * 0.008
			pitch = clampf(pitch + event.relative.y * 0.006, min_pitch, max_pitch)
			_refresh()

func _refresh():
	position = target + Vector3(
		sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)
	) * distance
	look_at(target)

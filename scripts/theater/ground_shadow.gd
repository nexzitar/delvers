extends RefCounted
class_name GroundShadow

## Soft elliptical shadow placed under an actor's feet.

static func make_ellipse(rx: float, ry: float) -> Polygon2D:
	var pts := PackedVector2Array()
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	var shadow = Polygon2D.new()
	shadow.polygon = pts
	shadow.color = Color(0, 0, 0, 0.32)
	return shadow

static func attach_to_actor(actor: Node2D, feet_y: float) -> Polygon2D:
	var rx := feet_y * 0.327
	var ry := feet_y * 0.087
	var shadow := make_ellipse(rx, ry)
	shadow.position = Vector2(0, feet_y + 2)
	shadow.z_index = -1
	actor.add_child(shadow)
	actor.move_child(shadow, 0)
	return shadow

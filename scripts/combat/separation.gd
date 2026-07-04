class_name Separation

const MAX_PUSH := 8.0

static func compute_offset(pos: Vector2, others: Array, radius: float, strength: float) -> Vector2:
	var push = Vector2.ZERO
	for o in others:
		var d = pos - o
		var dist = d.length()
		if dist < radius and dist > 0.01:
			push += d.normalized() * (radius - dist) * strength
	if push.length() > MAX_PUSH:
		push = push.normalized() * MAX_PUSH
	return push

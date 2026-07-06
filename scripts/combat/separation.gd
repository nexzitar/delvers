class_name Separation

const MAX_PUSH := 8.0

## Soft push away from overlapping neighbours. `salt` breaks the tie
## when two bodies occupy the exact same point (the zero vector has no
## direction to normalize) — give each entity a distinct salt so
## perfectly stacked units burst apart instead of freezing merged.
static func compute_offset(pos: Vector2, others: Array, radius: float, strength: float, salt := 0.0) -> Vector2:
	var push = Vector2.ZERO
	for o in others:
		var d = pos - o
		var dist = d.length()
		if dist >= radius:
			continue
		if dist <= 0.01:
			# Dead-center overlap: pick a deterministic direction from
			# the salt so each body leaves along its own bearing.
			d = Vector2.RIGHT.rotated(salt * 2.399963)
			dist = 0.01
		push += d.normalized() * (radius - dist) * strength
	if push.length() > MAX_PUSH:
		push = push.normalized() * MAX_PUSH
	return push

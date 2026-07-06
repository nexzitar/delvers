extends SceneTree

## Generates flat 64x64 skill icons (rounded dark tile + bold symbol)
## for the MVP skills. Run: godot --headless --script this_file.

const SIZE := 64
const C := 32.0

func _init():
	_save(_frost_nova(), "res://art/skills/skill_frost_nova.png")
	_save(_hamstring(), "res://art/skills/skill_hamstring.png")
	_save(_charge(), "res://art/skills/skill_charge.png")
	_save(_heal(), "res://art/skills/skill_heal.png")
	_save(_cleave(), "res://art/skills/skill_cleave.png")
	_save(_whirlwind(), "res://art/skills/skill_whirlwind.png")
	_save(_renew(), "res://art/skills/skill_renew.png")
	_save(_shield_wall(), "res://art/skills/skill_shield_wall.png")
	_save(_thunderclap(), "res://art/skills/skill_thunderclap.png")
	_save(_multishot(), "res://art/skills/skill_multishot.png")
	_save(_piercing_shot(), "res://art/skills/skill_piercing_shot.png")
	_save(_badge_poison(), "res://art/status/status_poison.png")
	_save(_badge_daze(), "res://art/status/status_daze.png")
	_save(_badge_stun(), "res://art/status/status_stun.png")
	_save(_badge_root(), "res://art/status/status_root.png")
	_save(_badge_chill(), "res://art/status/status_chill.png")
	_save(_badge_renew(), "res://art/status/status_renew.png")
	_save(_badge_fortify(), "res://art/status/status_fortify.png")
	print("icons written")
	quit()

func _save(img: Image, path: String):
	img.save_png(ProjectSettings.globalize_path(path))

## Rounded-square tile with a soft vertical gradient and rim.
func _tile(top: Color, bottom: Color, rim: Color) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var dx = maxf(0.0, maxf(10.0 - x, x - (SIZE - 11)))
			var dy = maxf(0.0, maxf(10.0 - y, y - (SIZE - 11)))
			if Vector2(dx, dy).length() > 10.0:
				continue  # transparent corner
			var color = top.lerp(bottom, y / float(SIZE))
			if x < 3 or x > SIZE - 4 or y < 3 or y > SIZE - 4:
				color = rim
			img.set_pixel(x, y, color)
	return img

func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var k = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return (p - (a + ab * k)).length()

func _paint(img: Image, inside: Callable, color: Color):
	for y in SIZE:
		for x in SIZE:
			if img.get_pixel(x, y).a > 0.0 and inside.call(Vector2(x, y)):
				img.set_pixel(x, y, color)

## Frost Nova: six-spoke burst radiating from a bright core.
func _frost_nova() -> Image:
	var img = _tile(Color("1c3350"), Color("11203a"), Color("3b5b86"))
	var spokes := []
	for i in 6:
		var a = TAU * i / 6.0 + 0.26
		spokes.append(Vector2(C, C) + Vector2(cos(a), sin(a)) * 22.0)
	_paint(img, func(p):
		for tip in spokes:
			if _dist_to_segment(p, Vector2(C, C), tip) < 2.6:
				return true
		return false, Color("bfe4ff"))
	_paint(img, func(p): return p.distance_to(Vector2(C, C)) < 6.0, Color("eaf6ff"))
	return img

## Hamstring: a savage diagonal slash with a secondary nick.
func _hamstring() -> Image:
	var img = _tile(Color("47201e"), Color("2c1113"), Color("74403a"))
	_paint(img, func(p):
		return _dist_to_segment(p, Vector2(16, 14), Vector2(50, 52)) < 3.4,
		Color("ff8d78"))
	_paint(img, func(p):
		return _dist_to_segment(p, Vector2(38, 16), Vector2(22, 46)) < 2.0,
		Color("d94f42"))
	return img

## Charge: a heavy forward chevron pair.
func _charge() -> Image:
	var img = _tile(Color("4d3a17"), Color("32240e"), Color("7d6230"))
	var chevron = func(offset: float) -> Callable:
		return func(p):
			var upper = _dist_to_segment(p, Vector2(18 + offset, 16), Vector2(40 + offset, 32))
			var lower = _dist_to_segment(p, Vector2(40 + offset, 32), Vector2(18 + offset, 48))
			return upper < 3.2 or lower < 3.2
	_paint(img, chevron.call(-6.0), Color("caa04a"))
	_paint(img, chevron.call(8.0), Color("ffd769"))
	return img

## Heal: a plump cross on green.
func _heal() -> Image:
	var img = _tile(Color("1f4023"), Color("122a16"), Color("3f7043"))
	_paint(img, func(p):
		return (absf(p.x - C) < 6.0 and absf(p.y - C) < 18.0) \
			or (absf(p.y - C) < 6.0 and absf(p.x - C) < 18.0),
		Color("a8eb9e"))
	return img

## Three parallel slashes carrying through.
func _cleave() -> Image:
	var img = _tile(Color("4a2c20"), Color("2c1810"), Color("7a4a30"))
	for i in 3:
		var off = -12.0 + i * 12.0
		_paint(img, func(p):
			return _dist_to_segment(p,
				Vector2(18 + off, 14), Vector2(34 + off, 50)) < 2.6,
			Color("e8d8c0"))
	return img

## A spun circle of blades.
func _whirlwind() -> Image:
	var img = _tile(Color("3a3426"), Color("241f14"), Color("6a6244"))
	_paint(img, func(p):
		var d = p.distance_to(Vector2(C, C))
		return d > 11.0 and d < 16.0, Color("d8d0b8"))
	for i in 3:
		var a = TAU * i / 3.0
		var tip = Vector2(C, C) + Vector2(cos(a), sin(a)) * 22.0
		var base = Vector2(C, C) + Vector2(cos(a + 0.5), sin(a + 0.5)) * 14.0
		_paint(img, func(p):
			return _dist_to_segment(p, base, tip) < 2.6, Color("e8e0c8"))
	return img

## A sprouting leaf over soft rings: healing that keeps going.
func _renew() -> Image:
	var img = _tile(Color("22381e"), Color("142212"), Color("3e6a38"))
	_paint(img, func(p):
		var d = p.distance_to(Vector2(C, 40))
		return d > 12.0 and d < 15.0 and p.y < 42.0, Color("74b060"))
	_paint(img, func(p):
		return absf(p.x - C) < 2.2 and p.y > 20.0 and p.y < 44.0, Color("a8dc8a"))
	_paint(img, func(p):
		var leaf = p.distance_to(Vector2(C - 7, 22)) < 6.0
		var leaf2 = p.distance_to(Vector2(C + 7, 27)) < 5.0
		return leaf or leaf2, Color("a8dc8a"))
	return img

## Planted shield before a wall.
func _shield_wall() -> Image:
	var img = _tile(Color("33302a"), Color("1e1c18"), Color("5e5844"))
	for row in 2:
		for col in 3:
			_paint(img, func(p):
				var x0 = 10.0 + col * 15.0 + (7.5 if row == 1 else 0.0)
				var y0 = 14.0 + row * 11.0
				return p.x >= x0 and p.x <= x0 + 13.0 \
					and p.y >= y0 and p.y <= y0 + 9.0, Color("6a6152"))
	_paint(img, func(p):
		if p.y < 26.0 or p.y > 52.0:
			return false
		var half = 10.0 if p.y < 40.0 else 10.0 * (1.0 - (p.y - 40.0) / 13.0)
		return absf(p.x - C) < half, Color("d8c684"))
	return img

## A bolt inside a shock ring.
func _thunderclap() -> Image:
	var img = _tile(Color("3a3418"), Color("221e0c"), Color("6a6030"))
	_paint(img, func(p):
		var d = p.distance_to(Vector2(C, C))
		return d > 20.0 and d < 24.0, Color("b0a860"))
	_paint(img, func(p):
		var upper = _dist_to_segment(p, Vector2(36, 12), Vector2(26, 32)) < 2.8
		var lower = _dist_to_segment(p, Vector2(38, 30), Vector2(26, 52)) < 2.8
		var bar = _dist_to_segment(p, Vector2(26, 32), Vector2(38, 30)) < 2.8
		return upper or lower or bar, Color("ffe27a"))
	return img

## Status badges: 32px transparent symbols hovering over heads.
const B := 32

func _badge(paint: Callable) -> Image:
	var img := Image.create(B, B, false, Image.FORMAT_RGBA8)
	for y in B:
		for x in B:
			var color = paint.call(Vector2(x, y))
			if color != null:
				img.set_pixel(x, y, color)
	return img

func _badge_poison() -> Image:
	return _badge(func(p):
		var blob = p.distance_to(Vector2(16, 19)) < 7.0
		var tip = absf(p.x - 16.0) < (p.y - 6.0) * 0.5 and p.y >= 6.0 and p.y < 13.0
		if blob or tip:
			return Color("b464e6")
		return null)

func _badge_daze() -> Image:
	return _badge(func(p):
		var d = p.distance_to(Vector2(16, 16))
		var a = atan2(p.y - 16.0, p.x - 16.0)
		var spiral = absf(d - (4.0 + fposmod(a + PI, TAU) * 1.5)) < 1.8
		if spiral and d < 14.0:
			return Color("f0d05a")
		return null)

func _badge_stun() -> Image:
	return _badge(func(p):
		for i in 5:
			var a = -PI / 2 + TAU * i / 5.0
			var tip = Vector2(16, 16) + Vector2(cos(a), sin(a)) * 11.0
			if _dist_to_segment(p, Vector2(16, 16), tip) < 2.0:
				return Color("ffe27a")
		return null)

func _badge_root() -> Image:
	return _badge(func(p):
		var d = p.distance_to(Vector2(16, 16))
		if (absf(d - 6.0) < 1.2 or absf(d - 11.0) < 1.2) and d < 13.0:
			return Color("e8e4d8")
		for i in 4:
			var a = TAU * i / 8.0
			if _dist_to_segment(p, Vector2(16, 16),
					Vector2(16, 16) + Vector2(cos(a), sin(a)) * 13.0) < 1.2:
				return Color("e8e4d8")
			if _dist_to_segment(p, Vector2(16, 16),
					Vector2(16, 16) - Vector2(cos(a), sin(a)) * 13.0) < 1.2:
				return Color("e8e4d8")
		return null)

func _badge_chill() -> Image:
	return _badge(func(p):
		for i in 3:
			var a = TAU * i / 6.0
			var dir = Vector2(cos(a), sin(a)) * 12.0
			if _dist_to_segment(p, Vector2(16, 16) - dir, Vector2(16, 16) + dir) < 1.6:
				return Color("9ad4ff")
		return null)

func _badge_renew() -> Image:
	return _badge(func(p):
		var v = absf(p.x - 16.0) < 2.4 and absf(p.y - 16.0) < 10.0
		var h = absf(p.y - 16.0) < 2.4 and absf(p.x - 16.0) < 10.0
		if v or h:
			return Color("8adc72")
		return null)

func _badge_fortify() -> Image:
	return _badge(func(p):
		if p.y < 6.0 or p.y > 27.0:
			return null
		var half = 9.0 if p.y < 17.0 else 9.0 * (1.0 - (p.y - 17.0) / 10.0)
		if absf(p.x - 16.0) < half:
			return Color("d8c684")
		return null)

## A fan of three arrows.
func _multishot() -> Image:
	var img = _tile(Color("2c3420"), Color("1a2012"), Color("50663a"))
	for i in 3:
		var a = -PI / 2 + (i - 1) * 0.45
		var dir = Vector2(cos(a), sin(a))
		var base = Vector2(C, 50)
		var tip = base + dir * 34.0
		_paint(img, func(p):
			return _dist_to_segment(p, base, tip) < 2.0, Color("d8ceb0"))
		_paint(img, func(p):
			return p.distance_to(tip) < 3.2, Color("e8e0c8"))
	return img

## One heavy arrow through a plate.
func _piercing_shot() -> Image:
	var img = _tile(Color("34302a"), Color("201e18"), Color("5e5844"))
	_paint(img, func(p):
		return absf(p.x - C) < 9.0 and absf(p.y - C) < 12.0, Color("6a7078"))
	_paint(img, func(p):
		return _dist_to_segment(p, Vector2(10, 44), Vector2(52, 18)) < 2.4,
		Color("ffe27a"))
	_paint(img, func(p):
		return p.distance_to(Vector2(52, 18)) < 4.0, Color("ffe27a"))
	return img

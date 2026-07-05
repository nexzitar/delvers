extends SceneTree

## Generates flat 64x64 affix icons. Run headless with --script.

const SIZE := 64
const C := 32.0

func _init():
	_save(_virulent(), "res://art/affixes/affix_virulent.png")
	_save(_frostforged(), "res://art/affixes/affix_frostforged.png")
	_save(_flaming(), "res://art/affixes/affix_flaming.png")
	_save(_quick(), "res://art/affixes/affix_quick.png")
	_save(_guarding(), "res://art/affixes/affix_guarding.png")
	print("affix icons written")
	quit()

func _save(img: Image, path: String):
	img.save_png(ProjectSettings.globalize_path(path))

func _tile(top: Color, bottom: Color, rim: Color) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var dx = maxf(0.0, maxf(10.0 - x, x - (SIZE - 11)))
			var dy = maxf(0.0, maxf(10.0 - y, y - (SIZE - 11)))
			if Vector2(dx, dy).length() > 10.0:
				continue
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

## Virulent: dripping venom droplets over a sickly field.
func _virulent() -> Image:
	var img = _tile(Color("2c1d3e"), Color("1a1026"), Color("55407a"))
	_paint(img, func(p): return p.distance_to(Vector2(24, 26)) < 8.0, Color("a06fd0"))
	_paint(img, func(p): return p.distance_to(Vector2(42, 38)) < 6.0, Color("8a55c0"))
	_paint(img, func(p):
		return absf(p.x - 24.0) < 2.0 and p.y > 32.0 and p.y < 48.0, Color("a06fd0"))
	_paint(img, func(p):
		return absf(p.x - 42.0) < 1.6 and p.y > 42.0 and p.y < 52.0, Color("8a55c0"))
	return img

## Frostforged: a spiked frost shard.
func _frostforged() -> Image:
	var img = _tile(Color("1b2c44"), Color("101b30"), Color("3b5b86"))
	var spokes := []
	for i in 4:
		var a = TAU * i / 4.0 + 0.79
		spokes.append(Vector2(C, C) + Vector2(cos(a), sin(a)) * 18.0)
	_paint(img, func(p):
		for tip in spokes:
			if _dist_to_segment(p, Vector2(C, C), tip) < 2.4:
				return true
		return false, Color("bfe4ff"))
	_paint(img, func(p): return p.distance_to(Vector2(C, C)) < 5.0, Color("eaf6ff"))
	return img

## Flaming: a licking flame.
func _flaming() -> Image:
	var img = _tile(Color("40200e"), Color("2a1206"), Color("74452a"))
	_paint(img, func(p):
		var flame = p.distance_to(Vector2(C, 40)) < 12.0
		var tip = absf(p.x - C - sin((p.y - 14.0) * 0.35) * 4.0) < (p.y - 12.0) * 0.4 \
			and p.y >= 12.0 and p.y < 30.0
		return flame or tip, Color("ff8f2e"))
	_paint(img, func(p): return p.distance_to(Vector2(C, 42)) < 6.0, Color("ffd23a"))
	return img

## Quick: double wind chevrons.
func _quick() -> Image:
	var img = _tile(Color("2e3a2a"), Color("1c241a"), Color("54704c"))
	for off in [-7.0, 7.0]:
		_paint(img, func(p):
			var upper = _dist_to_segment(p, Vector2(18 + off, 20), Vector2(40 + off, 32))
			var lower = _dist_to_segment(p, Vector2(40 + off, 32), Vector2(18 + off, 44))
			return upper < 2.6 or lower < 2.6, Color("cde8b0"))
	return img

## Guarding: a kite shield silhouette.
func _guarding() -> Image:
	var img = _tile(Color("3a3426"), Color("241f16"), Color("6d6244"))
	_paint(img, func(p):
		if p.y < 16.0 or p.y > 50.0:
			return false
		var half = 13.0 if p.y < 34.0 else 13.0 * (1.0 - (p.y - 34.0) / 17.0)
		return absf(p.x - C) < half, Color("d8c684"))
	_paint(img, func(p):
		return absf(p.x - C) < 1.6 and p.y > 18.0 and p.y < 47.0, Color("a99a5e"))
	return img

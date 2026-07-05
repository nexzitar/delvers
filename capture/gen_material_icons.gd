extends SceneTree

## Generates flat 64x64 material icons (rounded tile + simple symbol).
## Run: godot --headless --script this_file.

const SIZE := 64
const C := 32.0

func _init():
	_save(_droplet(Color("2c4a24"), Color("6fce55")), "res://art/materials/mat_gel.png")
	_save(_droplet(Color("23331c"), Color("9ab944"), true), "res://art/materials/mat_acidic_ooze.png")
	_save(_core(), "res://art/materials/mat_corrosion_core.png")
	_save(_ingot(), "res://art/materials/mat_iron_scrap.png")
	_save(_plank(), "res://art/materials/mat_ash_wood.png")
	_save(_coil(), "res://art/materials/mat_bow_string.png")
	_save(_droplet(Color("32204a"), Color("a06fd0")), "res://art/materials/mat_poison_sac.png")
	_save(_jelly(), "res://art/materials/mat_royal_jelly.png")
	print("material icons written")
	quit()

func _save(img: Image, path: String):
	img.save_png(ProjectSettings.globalize_path(path))

func _tile(top: Color, bottom: Color) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y in SIZE:
		for x in SIZE:
			var dx = maxf(0.0, maxf(10.0 - x, x - (SIZE - 11)))
			var dy = maxf(0.0, maxf(10.0 - y, y - (SIZE - 11)))
			if Vector2(dx, dy).length() > 10.0:
				continue
			var color = top.lerp(bottom, y / float(SIZE))
			if x < 3 or x > SIZE - 4 or y < 3 or y > SIZE - 4:
				color = top.lerp(bottom, 0.5).lightened(0.25)
			img.set_pixel(x, y, color)
	return img

func _paint(img: Image, inside: Callable, color: Color):
	for y in SIZE:
		for x in SIZE:
			if img.get_pixel(x, y).a > 0.0 and inside.call(Vector2(x, y)):
				img.set_pixel(x, y, color)

## Teardrop blob (gel, ooze, poison sac).
func _droplet(bg: Color, tint: Color, drips := false) -> Image:
	var img = _tile(bg.lightened(0.08), bg)
	_paint(img, func(p):
		var blob = p.distance_to(Vector2(C, 36)) < 13.0
		var tip = absf(p.x - C) < (p.y - 16.0) * 0.55 and p.y >= 16.0 and p.y < 26.0
		return blob or tip, tint)
	_paint(img, func(p): return p.distance_to(Vector2(C - 5, 32)) < 3.5,
		tint.lightened(0.4))
	if drips:
		_paint(img, func(p):
			return absf(p.x - 44.0) < 2.0 and p.y > 44.0 and p.y < 54.0, tint)
	return img

## Cracked orange core.
func _core() -> Image:
	var img = _tile(Color("40261a"), Color("2a170e"))
	_paint(img, func(p): return p.distance_to(Vector2(C, C)) < 13.0, Color("d97a2e"))
	_paint(img, func(p): return p.distance_to(Vector2(C, C)) < 6.0, Color("ffd23a"))
	_paint(img, func(p):
		return absf(p.y - C - (p.x - C) * 0.4) < 1.4 and p.distance_to(Vector2(C, C)) < 13.0,
		Color("7a3a12"))
	return img

## Grey metal ingot.
func _ingot() -> Image:
	var img = _tile(Color("33363c"), Color("22242a"))
	_paint(img, func(p):
		var k = (p.y - 26.0) * 0.55
		return p.y >= 26.0 and p.y <= 42.0 and p.x >= 16.0 - k + 6.0 and p.x <= 48.0 + k - 6.0 + 6.0,
		Color("9aa3ad"))
	_paint(img, func(p):
		return p.y >= 26.0 and p.y <= 29.0 and p.x >= 22.0 and p.x <= 48.0,
		Color("c7ced6"))
	return img

## Wooden plank, diagonal.
func _plank() -> Image:
	var img = _tile(Color("3a2c1c"), Color("261c12"))
	_paint(img, func(p):
		var along = (p.x - 14.0) * 0.5 + 14.0
		return p.y > along and p.y < along + 12.0 and p.x >= 12.0 and p.x <= 52.0,
		Color("a4713c"))
	_paint(img, func(p):
		var along = (p.x - 14.0) * 0.5 + 14.0
		return absf(p.y - (along + 6.0)) < 1.0 and p.x >= 14.0 and p.x <= 50.0,
		Color("7c5227"))
	return img

## Coiled string.
func _coil() -> Image:
	var img = _tile(Color("3c3626"), Color("272318"))
	_paint(img, func(p):
		var d = p.distance_to(Vector2(C, C))
		return d > 8.0 and d < 15.0, Color("ded2ae"))
	_paint(img, func(p):
		return absf(p.x - C - 10.0) < 2.0 and absf(p.y - C) < 12.0, Color("ded2ae"))
	return img

## Golden royal jelly: droplet with a crown band.
func _jelly() -> Image:
	var img = _droplet(Color("4a3a14"), Color("e8bb3a"))
	_paint(img, func(p):
		if p.y < 14.0 or p.y > 19.0 or absf(p.x - C) > 10.0:
			return false
		return int(p.x) % 6 < 3 or p.y > 16.0, Color("ffe27a"))
	return img

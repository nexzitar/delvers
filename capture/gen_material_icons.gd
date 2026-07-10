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
	_save(_fitting(), "res://art/materials/mat_brass_fitting.png")
	_save(_droplet(Color("1a1712"), Color("4a4232")), "res://art/materials/mat_engine_oil.png")
	_save(_cog(), "res://art/materials/mat_cog_wheel.png")
	_save(_leather(), "res://art/materials/mat_leather.png")
	_save(_tome(Color("2a3a5e"), Color("18233c"), Color("7fa4d8")), "res://art/tomes/tome_recipe.png")
	_save(_tome(Color("42285e"), Color("2a173c"), Color("a06fd0")), "res://art/tomes/tome_affix.png")
	_save(_tome(Color("4a3a22"), Color("2e2412"), Color("d8c684")), "res://art/tomes/tome_journal.png")
	_save(_silk(Color("e8e4d8")), "res://art/materials/mat_silk_thread.png")
	_save(_chitin(), "res://art/materials/mat_chitin_plate.png")
	_save(_silk(Color("cdb8e0")), "res://art/materials/mat_brood_silk.png")
	_save(_boots(), "res://art/gear/iron_shod_boots.png")
	_save(_gauntlets(), "res://art/gear/goblin_work_gauntlets.png")
	_save(_belt(), "res://art/gear/studded_belt.png")
	_save(_greaves(), "res://art/gear/iron_greaves.png")
	_save(_pauldrons(), "res://art/gear/wardens_pauldrons.png")
	_save(_bracers(), "res://art/gear/silk_bracers.png")
	_save(_cloak(), "res://art/gear/weavers_cloak.png")
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

## Tanned hide with stitch marks.
func _leather() -> Image:
	var img = _tile(Color("3e2a1a"), Color("281a10"))
	_paint(img, func(p):
		var dx = absf(p.x - C)
		var dy = absf(p.y - C)
		return dx + dy * 0.9 < 18.0 and dx < 15.0, Color("9a6a3c"))
	_paint(img, func(p):
		var dx = absf(p.x - C)
		var dy = absf(p.y - C)
		var on_edge = absf(dx + dy * 0.9 - 15.5) < 1.2 and dx < 13.0
		return on_edge and int(p.x + p.y) % 5 < 3, Color("5e3d20"))
	return img

## A bound tome: cover, spine band, and page block.
func _tome(bg: Color, bg2: Color, trim: Color) -> Image:
	var img = _tile(bg, bg2)
	_paint(img, func(p):
		return p.x >= 16.0 and p.x <= 48.0 and p.y >= 14.0 and p.y <= 50.0,
		trim.darkened(0.35))
	_paint(img, func(p):
		return p.x >= 19.0 and p.x <= 45.0 and p.y >= 17.0 and p.y <= 47.0,
		trim.darkened(0.1))
	_paint(img, func(p):
		return p.x >= 19.0 and p.x <= 23.0 and p.y >= 14.0 and p.y <= 50.0,
		trim.lightened(0.15))
	_paint(img, func(p):
		return p.x >= 28.0 and p.x <= 40.0 and absf(p.y - 32.0) < 5.0 \
			and int(p.y) % 4 < 2, trim.lightened(0.45))
	return img

## A wound spool of thread.
func _silk(thread: Color) -> Image:
	var img = _tile(Color("3a3040"), Color("241c2a"))
	_paint(img, func(p):
		return absf(p.x - C) < 12.0 and absf(p.y - C) < 14.0, Color("6b5a3c"))
	_paint(img, func(p):
		if absf(p.x - C) > 11.0 or absf(p.y - C) > 12.0:
			return false
		return int(p.y) % 4 < 2, thread)
	return img

## An overlapping shell plate.
func _chitin() -> Image:
	var img = _tile(Color("2e2418"), Color("1c160e"))
	for row in 3:
		_paint(img, func(p):
			var cy = 20.0 + row * 10.0
			if p.y < cy or p.y > cy + 11.0:
				return false
			var half = 16.0 - row * 1.5
			return absf(p.x - C) < half * (1.0 - (p.y - cy) / 22.0 * 0.4),
			Color("6e4f2e").lightened(0.12 * row))
	return img

## A sturdy boot, iron at the toe.
func _boots() -> Image:
	var img = _tile(Color("32281c"), Color("1e1810"))
	_paint(img, func(p):
		return p.x >= 22.0 and p.x <= 34.0 and p.y >= 14.0 and p.y <= 42.0,
		Color("6e4f2e"))
	_paint(img, func(p):
		return p.x >= 22.0 and p.x <= 48.0 and p.y >= 36.0 and p.y <= 48.0,
		Color("6e4f2e"))
	_paint(img, func(p):
		return p.x >= 40.0 and p.x <= 48.0 and p.y >= 38.0 and p.y <= 48.0,
		Color("9aa3ad"))
	return img

## A studded fist wrap.
func _gauntlets() -> Image:
	var img = _tile(Color("2c241c"), Color("1a1610"))
	_paint(img, func(p):
		return p.distance_to(Vector2(30, 34)) < 13.0, Color("8a6a42"))
	for i in 4:
		_paint(img, func(p):
			return p.distance_to(Vector2(20.0 + i * 7.0, 24)) < 3.2,
			Color("c7ced6"))
	_paint(img, func(p):
		return p.x >= 24.0 and p.x <= 40.0 and p.y >= 42.0 and p.y <= 50.0,
		Color("5e4426"))
	return img

## A wide belt, studded, heavy buckle.
func _belt() -> Image:
	var img = _tile(Color("2c2418"), Color("1a160e"))
	_paint(img, func(p):
		return p.y >= 26.0 and p.y <= 40.0, Color("6e4f2e"))
	_paint(img, func(p):
		return absf(p.x - C) < 7.0 and absf(p.y - 33.0) < 6.0, Color("c7a94a"))
	_paint(img, func(p):
		return absf(p.x - C) < 3.0 and absf(p.y - 33.0) < 2.5, Color("2c2418"))
	for i in 4:
		_paint(img, func(p):
			var x = 10.0 + i * 12.0
			if absf(x - C) < 10.0:
				return false
			return p.distance_to(Vector2(x, 33)) < 2.2, Color("c7ced6"))
	return img

func _greaves() -> Image:
	var img = _tile(Color("2c2c30"), Color("1a1a20"))
	for side in [-1, 1]:
		_paint(img, func(p):
			return absf(p.x - C - side * 9.0) < 5.0 and p.y >= 14.0 and p.y <= 46.0,
			Color("8a939d"))
		_paint(img, func(p):
			return absf(p.x - C - side * 9.0) < 6.0 and p.y >= 42.0 and p.y <= 48.0,
			Color("6a7078"))
	return img

func _pauldrons() -> Image:
	var img = _tile(Color("30302a"), Color("1c1c18"))
	for side in [-1, 1]:
		_paint(img, func(p):
			var center = Vector2(C + side * 11.0, 26)
			return p.distance_to(center) < 10.0 and p.y <= 28.0,
			Color("9aa3ad"))
	_paint(img, func(p):
		return absf(p.x - C) < 7.0 and absf(p.y - 30.0) < 4.0, Color("6e4f2e"))
	return img

func _bracers() -> Image:
	var img = _tile(Color("34302a"), Color("201e18"))
	for side in [-1, 1]:
		_paint(img, func(p):
			if absf(p.x - C - side * 9.0) > 5.0 or p.y < 18.0 or p.y > 44.0:
				return false
			return int(p.y) % 6 < 4, Color("ded2ae"))
	return img

func _cloak() -> Image:
	var img = _tile(Color("2e2a34"), Color("1a1820"))
	_paint(img, func(p):
		if p.y < 12.0 or p.y > 50.0:
			return false
		var half = 6.0 + (p.y - 12.0) * 0.28
		return absf(p.x - C) < half, Color("b8b2c8"))
	_paint(img, func(p):
		return absf(p.y - 14.0) < 2.0 and absf(p.x - C) < 8.0, Color("d8c684"))
	return img

## A brass elbow-joint fitting.
func _fitting() -> Image:
	var img = _tile(Color("2e2416"), Color("1c160c"))
	_paint(img, func(p):
		var horizontal = absf(p.y - 36.0) < 5.0 and p.x > 14.0 and p.x < 40.0
		var vertical = absf(p.x - 36.0) < 5.0 and p.y > 14.0 and p.y < 40.0
		return horizontal or vertical, Color("b08a42"))
	_paint(img, func(p):
		return absf(p.y - 36.0) < 2.0 and p.x > 14.0 and p.x < 40.0, Color("d0aa5c"))
	return img

## A toothed cog wheel.
func _cog() -> Image:
	var img = _tile(Color("26221c"), Color("161310"))
	_paint(img, func(p):
		var d = p - Vector2(C, C)
		var r = d.length()
		if r > 21.0 or r < 5.0:
			return false
		if r > 16.0:
			var a = fposmod(atan2(d.y, d.x), TAU / 8.0) / (TAU / 8.0)
			if absf(a - 0.5) > 0.28:
				return false
		return not (r > 9.0 and r < 13.0), Color("8a8272"))
	_paint(img, func(p):
		var r = (p - Vector2(C, C)).length()
		return r > 9.0 and r < 13.0, Color("3a352c"))
	return img

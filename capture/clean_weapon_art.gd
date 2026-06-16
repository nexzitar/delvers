extends SceneTree

# One-off tool: AI art bakes the transparency checkerboard in as opaque pixels.
# Recover real alpha by flood-filling the light checker background inward from
# the borders (the dark weapon outline stops the fill), then trim + scale.
#   Godot --headless --path . -s capture/clean_weapon_art.gd

const TARGETS := [
	"res://art/gear/fast_dagger.png",
	"res://art/gear/heavy_axe.png",
]
const MAX_SIDE := 720
const LIGHT_MIN := 195  # checker squares are light grays/whites
const GRAY_SPREAD := 34  # background is near-neutral (low saturation)

func _is_background(c: Color) -> bool:
	var r := c.r8
	var g := c.g8
	var b := c.b8
	var lo: int = min(r, min(g, b))
	var hi: int = max(r, max(g, b))
	return lo >= LIGHT_MIN and (hi - lo) <= GRAY_SPREAD

func _init():
	for path in TARGETS:
		var abs_path := ProjectSettings.globalize_path(path)
		var img := Image.load_from_file(abs_path)
		if img == null:
			print("FAIL load ", path)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var w := img.get_width()
		var h := img.get_height()

		var visited := {}
		var stack: Array[Vector2i] = []
		for x in range(w):
			stack.append(Vector2i(x, 0))
			stack.append(Vector2i(x, h - 1))
		for y in range(h):
			stack.append(Vector2i(0, y))
			stack.append(Vector2i(w - 1, y))

		var transparent := Color(0, 0, 0, 0)
		while not stack.is_empty():
			var p: Vector2i = stack.pop_back()
			if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
				continue
			var key := p.y * w + p.x
			if visited.has(key):
				continue
			visited[key] = true
			if not _is_background(img.get_pixelv(p)):
				continue
			img.set_pixelv(p, transparent)
			stack.append(Vector2i(p.x + 1, p.y))
			stack.append(Vector2i(p.x - 1, p.y))
			stack.append(Vector2i(p.x, p.y + 1))
			stack.append(Vector2i(p.x, p.y - 1))

		var rect := img.get_used_rect()
		img = img.get_region(rect)
		var rw := img.get_width()
		var rh := img.get_height()
		var longest: int = max(rw, rh)
		if longest > MAX_SIDE:
			var factor := float(MAX_SIDE) / float(longest)
			img.resize(int(round(rw * factor)), int(round(rh * factor)),
				Image.INTERPOLATE_LANCZOS)
		img.save_png(abs_path)
		print("OK %s trim=%s -> %dx%d" % [path, rect, img.get_width(), img.get_height()])
	quit()

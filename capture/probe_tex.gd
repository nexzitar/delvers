extends Node
func _ready():
	for tex_path in ["res://resources/models/starter_helm_Starter_Helmet_basecolor.jpg",
			"res://resources/models/starter_chest_metal_chestplate_armor_3d_model_basecolor.jpg"]:
		var img: Image = load(tex_path).get_image()
		img.resize(64, 64)
		var buckets := {}
		for y in 64:
			for x in 64:
				var c = img.get_pixel(x, y)
				var key = "%d,%d,%d" % [roundi(c.r * 6), roundi(c.g * 6), roundi(c.b * 6)]
				buckets[key] = buckets.get(key, 0) + 1
		var sorted_keys = buckets.keys()
		sorted_keys.sort_custom(func(a, b): return buckets[a] > buckets[b])
		var line = tex_path.get_file() + " top: "
		for i in mini(5, sorted_keys.size()):
			var parts = sorted_keys[i].split(",")
			line += "(%.2f %.2f %.2f)x%d " % [
				float(parts[0]) / 6.0, float(parts[1]) / 6.0, float(parts[2]) / 6.0,
				buckets[sorted_keys[i]]]
		print(line)
	get_tree().quit()

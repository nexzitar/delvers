extends Node

const Separation = preload("res://scripts/combat/separation.gd")

func _ready():
	var a = Vector2(100, 100)
	var b = Vector2(110, 100)
	var offset = Separation.compute_offset(a, [b], 24.0, 1.0)
	assert(offset.length() > 0.1, "pushes apart")
	print("PASS separation")
	get_tree().quit()

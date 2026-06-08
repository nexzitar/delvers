extends Node2D

@onready var sprite = $Sprite2D

func setup(direction):
	sprite.flip_h = direction < 0

func _ready():

	scale = Vector2.ZERO

	var tween = create_tween()

	tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		0.1 
	)

	tween.parallel().tween_property(
		self,
		"modulate:a",
		0.0,
		0.15
	)

	await tween.finished

	queue_free()

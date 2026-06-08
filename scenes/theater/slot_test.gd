extends Label

@export var pos: int

func _process(delta: float) -> void:
	position = BattlefieldLayout.enemy_slot(pos)

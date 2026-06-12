extends Label

@export var battlefield: BattlefieldLayout
@export var pos: int

func _process(_delta: float) -> void:
	if battlefield:
		position = battlefield.enemy_slot(pos)

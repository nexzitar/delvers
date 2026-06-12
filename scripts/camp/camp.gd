extends Control

## The camp between adventures. Upgrades and management will live
## here later; for now the party rests until it embarks again.

@onready var result_label = $ResultLabel

func _ready():

	UiSounds.wire_buttons(self)

	if PlayerRoster.battles_fought == 0:
		result_label.visible = false
		return

	result_label.visible = true

	if PlayerRoster.last_battle_won:
		result_label.text = "The party returns victorious!"
		result_label.add_theme_color_override(
			"font_color", Color(0.85, 0.7, 0.25)
		)
	else:
		result_label.text = "The party limps back to camp..."
		result_label.add_theme_color_override(
			"font_color", Color(0.7, 0.25, 0.2)
		)

func _on_embark_pressed():
	get_tree().change_scene_to_file(
		"res://scenes/theater/battle_theater.tscn"
	)

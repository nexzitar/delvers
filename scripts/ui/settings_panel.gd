extends PanelContainer

@onready var fullscreen_check = %FullscreenCheck
@onready var sliders = {
	"master": %MasterSlider,
	"music": %MusicSlider,
	"sfx": %SfxSlider,
	"ambience": %AmbienceSlider,
}

func _ready():

	visible = false

	fullscreen_check.button_pressed = GameSettings.fullscreen
	fullscreen_check.toggled.connect(GameSettings.set_fullscreen)

	for key in sliders:
		sliders[key].value = GameSettings.volumes[key]
		sliders[key].value_changed.connect(
			func(value): GameSettings.set_volume(key, value)
		)

	# Reset save: two clicks, the second one honest about the cost.
	var reset := Button.new()
	reset.name = "ResetSave"
	reset.text = "Reset Save"
	reset.add_theme_color_override("font_color", Color(0.85, 0.5, 0.4))
	reset.pressed.connect(_on_reset_pressed.bind(reset))
	%FullscreenCheck.get_parent().add_child(reset)

func _on_reset_pressed(button: Button):
	if button.text == "Reset Save":
		button.text = "Really? Everything is lost!"
		button.add_theme_color_override("font_color", Color(0.9, 0.25, 0.2))
		# Disarm if they walk away.
		get_tree().create_timer(4.0).timeout.connect(func():
			if is_instance_valid(button):
				button.text = "Reset Save"
				button.add_theme_color_override("font_color", Color(0.85, 0.5, 0.4)))
		return
	PlayerRoster.reset_save()
	visible = false
	SceneFlow.change_scene("res://scenes/menus/menu.tscn")

func open():
	visible = true

func _on_close_pressed():
	visible = false

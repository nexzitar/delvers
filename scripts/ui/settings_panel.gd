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

func open():
	visible = true

func _on_close_pressed():
	visible = false

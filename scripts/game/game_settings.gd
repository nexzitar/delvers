extends Node

## Autoloaded settings: audio volumes and display mode, persisted to
## user://settings.cfg and applied on startup.

const SAVE_PATH = "user://settings.cfg"

const VOLUME_BUSES = {
	"master": "Master",
	"music": "Music",
	"sfx": "SFX",
	"ambience": "Ambience",
}

var fullscreen := false
var volumes := {
	"master": 1.0,
	"music": 0.7,
	"sfx": 1.0,
	"ambience": 1.0,
}

func _ready():
	load_settings()
	apply_all()

func set_volume(key, value):
	volumes[key] = clampf(value, 0.0, 1.0)
	_apply_volume(key)
	save_settings()

func set_fullscreen(enabled):
	fullscreen = enabled
	_apply_fullscreen()
	save_settings()

func apply_all():
	for key in volumes:
		_apply_volume(key)
	_apply_fullscreen()

func _apply_volume(key):
	var bus = AudioServer.get_bus_index(VOLUME_BUSES[key])
	if bus < 0:
		return
	# Slider 0 means silence, not just very quiet.
	AudioServer.set_bus_mute(bus, volumes[key] <= 0.0)
	AudioServer.set_bus_volume_db(
		bus, linear_to_db(maxf(volumes[key], 0.0001))
	)

func _apply_fullscreen():
	var mode = (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_MAXIMIZED
	)
	DisplayServer.window_set_mode(mode)

func save_settings():
	var config = ConfigFile.new()
	config.set_value("display", "fullscreen", fullscreen)
	for key in volumes:
		config.set_value("audio", key, volumes[key])
	config.save(SAVE_PATH)

func load_settings():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	fullscreen = config.get_value("display", "fullscreen", fullscreen)
	for key in volumes:
		volumes[key] = config.get_value("audio", key, volumes[key])

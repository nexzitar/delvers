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

	# Save slots: stash the current ledger away or bring one back -
	# testing different stages of the guild without burning anything.
	var slots_title := Label.new()
	slots_title.text = "Save Slots"
	%FullscreenCheck.get_parent().add_child(slots_title)
	for i in [1, 2, 3]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.custom_minimum_size = Vector2(110, 0)
		row.add_child(label)
		var store := Button.new()
		store.text = "Store"
		var restore := Button.new()
		restore.text = "Load"
		row.add_child(store)
		row.add_child(restore)
		%FullscreenCheck.get_parent().add_child(row)
		var refresh = func():
			var exists = FileAccess.file_exists(_slot_path(i))
			label.text = "Slot %d%s" % [i, "" if exists else " (empty)"]
			restore.disabled = not exists
		store.pressed.connect(func():
			RosterSave.save(PlayerRoster, _slot_path(i))
			refresh.call())
		restore.pressed.connect(func():
			if RosterSave.load_into(PlayerRoster, _slot_path(i)):
				RosterSave.save(PlayerRoster)
				visible = false
				SceneFlow.change_scene("res://scenes/camp/camp.tscn"))
		refresh.call()

func _slot_path(i: int) -> String:
	return "user://delvers_slot_%d.json" % i

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

extends Control

## The camp between adventures. Upgrades and management will live
## here later; for now the party rests until it embarks again.

@onready var result_label = $UI/ResultLabel
@onready var stage = $Stage
@onready var loadout = $HeroLoadout

func _ready():

	UiSounds.wire_buttons(self)

	# This full-screen root Control would otherwise swallow the cursor;
	# let it pass through so the stage can poll the mouse over heroes.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	stage.hero_selected.connect(_on_hero_selected)
	loadout.hero_changed.connect(stage.refresh_hero)
	loadout.closed.connect(func(): stage.set_picking(true))

	_add_guild_button()

	# Arrivals outrank battle results: someone new sits by the fire.
	if PlayerRoster.arrival_message != "":
		result_label.visible = true
		result_label.text = PlayerRoster.arrival_message
		result_label.add_theme_color_override(
			"font_color", Color(0.85, 0.7, 0.25)
		)
		PlayerRoster.arrival_message = ""
		return

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

func _on_hero_selected(hero_index):
	UiSounds.click()
	stage.set_picking(false)
	loadout.open(hero_index)

func _on_embark_pressed():
	# One dungeon: just go. More: choose the delve.
	if PlayerRoster.unlocked_dungeons.size() <= 1:
		_embark(PlayerRoster.unlocked_dungeons[0])
		return
	stage.set_picking(false)
	var panel := DungeonPicker.new()
	add_child(panel)
	panel.closed.connect(func(): stage.set_picking(true))
	panel.chosen.connect(_embark)

func _embark(dungeon_id: String):
	PlayerRoster.start_delve(dungeon_id)
	SceneFlow.change_scene("res://scenes/theater/battle_theater_3d.tscn")

func _add_guild_button():
	var btn := Button.new()
	btn.text = "Guild"
	btn.add_theme_font_override("font", preload("res://art/fonts/Herculanum.ttf"))
	btn.add_theme_font_size_override("font_size", 30)
	btn.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	btn.flat = true
	btn.anchor_left = 1
	btn.anchor_right = 1
	btn.offset_left = -180
	btn.offset_top = 24
	btn.offset_right = -32
	btn.offset_bottom = 76
	btn.pressed.connect(_on_guild_pressed)
	btn.mouse_entered.connect(UiSounds.hover)
	$UI.add_child(btn)

func _on_guild_pressed():
	UiSounds.click()
	stage.set_picking(false)
	var panel := GuildPanel.new()
	add_child(panel)
	panel.closed.connect(func(): stage.set_picking(true))
	# A new delver needs a seat: rebuild the camp around them.
	panel.roster_grew.connect(func():
		SceneFlow.change_scene("res://scenes/camp/camp.tscn"))

func _on_exit_pressed():
	get_tree().quit()

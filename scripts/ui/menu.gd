extends Control

func _on_enter_pressed():
	get_tree().change_scene_to_file("res://scenes/camp/camp.tscn")

func _on_exit_pressed():
	get_tree().quit()

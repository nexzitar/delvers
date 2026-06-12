extends Node

## Autoloaded scene switcher. Unlike change_scene_to_file, this adds
## the next scene before freeing the old one, so there is never an
## empty frame (which would flash the clear color) in between.

func change_scene(path: String):

	var tree = get_tree()
	var next_scene = (load(path) as PackedScene).instantiate()

	tree.root.add_child(next_scene)
	tree.current_scene.queue_free()
	tree.current_scene = next_scene

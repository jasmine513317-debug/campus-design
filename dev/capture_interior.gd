extends Node2D
## Capture a full-floor interior reference image for the staged visual pass.

func _ready() -> void:
	var interior: Node = load("res://scenes/interiors/teaching_block.tscn").instantiate()
	add_child(interior)
	await get_tree().process_frame
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/teaching_interior.png"))
	get_tree().quit()

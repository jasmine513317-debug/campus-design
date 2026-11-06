extends SceneTree
## Enter the teaching block through its outdoor door, then capture the live interior.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main: Node = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var player := main.get_node("Player") as Node2D
	player.global_position = main.get_node("World").teaching_entry_point()
	player.facing = Vector2.UP
	main.get_node("World").try_interact(player.global_position + player.facing * 20.0)
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	if current_scene == null or current_scene.scene_file_path != "res://scenes/interiors/teaching_block.tscn":
		push_error("Door did not open the teaching interior")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.shots/teaching_interior_from_door.png"))
	print("Captured interior after entering through the outdoor door")
	quit()

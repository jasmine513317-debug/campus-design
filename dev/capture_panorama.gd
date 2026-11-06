extends Node
## A complete, unobstructed campus photograph at 3200 x 1440, from the actual renderer.

func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(3200, 1440)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var main: Node2D = load("res://scenes/world/main.tscn").instantiate()
	viewport.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node2D = main.get_node("Player")
	player.set_physics_process(false)
	player.hide()
	player.position = Vector2(3200, 1440)
	var camera: Camera2D = player.get_node("Camera2D")
	camera.zoom = Vector2(0.5, 0.5)
	camera.position_smoothing_enabled = false
	camera.make_current()
	camera.reset_smoothing()
	main.get_node("HUD").hide()
	var world: Node2D = main.get_node("World")
	world.set_process(false)
	for entry: Dictionary in world._labels:
		entry["label"].hide()
	GameClock.paused = true
	GameClock.minutes_since_wake = 240
	GameClock.time_changed.emit(10, 0)
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var path := "res://screenshots/campus_panorama.png"
	var result := viewport.get_texture().get_image().save_png(path)
	if result != OK:
		push_error("Could not save campus panorama: %s" % result)
	viewport.size = Vector2i(1280, 720)
	player.position = Vector2(888, 676)
	camera.zoom = Vector2(2, 2)
	camera.reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var boat_result := viewport.get_texture().get_image().save_png("res://screenshots/sailing_boat.png")
	if boat_result != OK:
		push_error("Could not save sailing boat close-up: %s" % boat_result)
	get_tree().quit(0 if result == OK and boat_result == OK else 1)

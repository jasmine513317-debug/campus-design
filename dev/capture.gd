extends Node
## 开发用：把主场景装进这个根节点，移动到若干机位截图后退出。
## 运行：godot --path <project> res://dev/capture.tscn

const OUT_DIR := "res://.shots"

var _main: Node2D
var _player: Node2D
var _camera: Camera2D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_main = load("res://scenes/world/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().create_timer(1.4).timeout

	_player = _main.get_node("Player")
	_player.set_physics_process(false)
	_camera = _player.get_node("Camera2D")

	var spots: Array = [
		["gate", Vector2(3328, 2340), 2.0],
		["landmark", Vector2(3328, 2290), 2.0],
		["grove", Vector2(3008, 2208), 2.0],
		["gym", Vector2(1944, 760), 1.0],
		["gym_front", Vector2(1944, 900), 2.0],
		["sports_strip", Vector2(2528, 1600), 1.0],
		["boat", Vector2(888, 676), 2.0],
		["overview", Vector2(3200, 1440), 0.23],
		["lavender", Vector2(5376, 800), 1.0],
		["teaching", Vector2(2992, 728), 2.0],
		["detour", Vector2(4500, 1712), 2.0],
		["international", Vector2(5360, 1920), 1.0],
		["west_campus", Vector2(824, 1360), 0.5],
		["central_axis", Vector2(3328, 1400), 0.5],
		["merged_track", Vector2(2160, 1630), 0.5],
	]
	var idx := 0
	for spot: Array in spots:
		var zoom := float(spot[2])
		_camera.zoom = Vector2(zoom, zoom)
		_player.global_position = spot[1]
		_camera.reset_smoothing()
		await get_tree().create_timer(0.45).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%02d_%s.png" % [OUT_DIR, idx, spot[0]])
		print("shot ", spot[0], " player=", _player.global_position, " center=", _camera.get_screen_center_position())
		idx += 1
	get_tree().quit()

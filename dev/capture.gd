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
	_camera = _player.get_node("Camera2D")

	var spots: Array = [
		["gate", Vector2(3208, 2340), 2.5],
		["landmark", Vector2(3208, 2290), 2.0],
		["grove", Vector2(2848, 2208), 2.4],
		["gym", Vector2(1944, 760), 0.95],
		["gym_front", Vector2(1944, 900), 2.0],
		["sports_strip", Vector2(2528, 1600), 1.0],
		["boat", Vector2(930, 640), 2.5],
		["overview", Vector2(3200, 1440), 0.23],
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

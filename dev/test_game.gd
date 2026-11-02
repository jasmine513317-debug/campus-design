extends Node
## 开发用：无头自检校园地图、相机、NPC 与互动。
## 运行：godot --headless --path <project> res://dev/test_game.tscn

var _fails := 0
var _main: Node2D
var _world: Node2D
var _player: Node2D
var _camera: Camera2D


func _ready() -> void:
	_main = load("res://scenes/world/main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	_world = _main.get_node("World")
	_player = _main.get_node("Player")
	_camera = _player.get_node("Camera2D")

	_check_layout()
	await _check_camera()
	await _check_npcs()
	_check_interact()

	print("----")
	if _fails == 0:
		print("ALL TESTS PASSED")
	else:
		print("%d TEST(S) FAILED" % _fails)
	get_tree().quit()


func _ok(cond: bool, label: String) -> void:
	if cond:
		print("[PASS] ", label)
	else:
		_fails += 1
		print("[FAIL] ", label)


func _check_layout() -> void:
	var rect: Rect2 = _world.get_world_rect()
	_ok(rect.size == Vector2(400 * 16, 180 * 16), "世界尺寸 6400x2880")
	var solids: Node = _world.get_node_or_null("Solids")
	_ok(solids != null and solids.get_child_count() > 200, "静态碰撞体 = %d" % (solids.get_child_count() if solids else 0))
	_ok(get_tree().get_nodes_in_group("farm_grids").is_empty(), "农田已全部移除")
	_ok(_world._buildings.size() == 17, "建筑数量 = %d（西侧 4 个 U 形楼 + 3 连廊 + 其余）" % _world._buildings.size())
	_ok(_world._courts.size() == 2, "篮球场数量 = %d（只保留上侧两个）" % _world._courts.size())
	_ok(_world._tennis.size.x > 0, "网球场 = %s" % _world._tennis.size)
	_ok(_world._pond.size.x > 0, "小池塘 = %s" % _world._pond.size)
	_ok(_world._track.size.x >= 60 and _world._track.size.y >= 88, "操场尺寸 = %s" % _world._track.size)
	var consts: Dictionary = _world.get_script().get_script_constant_map()
	_ok(int(consts.get("FLOORS", 0)) == 5, "所有建筑按 5 层绘制")
	var gate: Rect2i = _world._gates[0]
	var gate_center: float = (gate.position.x + gate.size.x * 0.5) * 16.0
	var campus_center: float = (_world._campus.position.x + _world._campus.size.x * 0.5) * 16.0
	_ok(absf(gate_center - campus_center) < 20.0, "校门居中：gate=%.0f campus=%.0f" % [gate_center, campus_center])


func _check_camera() -> void:
	_player.global_position = Vector2(1900, 900)
	_camera.reset_smoothing()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var center: Vector2 = _camera.get_screen_center_position()
	_ok(center.distance_to(_player.global_position) < 30.0, "相机跟随（大体育馆）")
	_player.global_position = Vector2(3300, 2200)
	_camera.reset_smoothing()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	center = _camera.get_screen_center_position()
	_ok(center.distance_to(_player.global_position) < 30.0, "相机跟随（中心花园）")


func _check_npcs() -> void:
	var npcs := get_tree().get_nodes_in_group("npcs")
	_ok(npcs.size() >= 5, "校园 NPC = %d" % npcs.size())
	if npcs.is_empty():
		return
	var npc := npcs[0] as Node2D
	var before := npc.global_position
	await get_tree().create_timer(1.2).timeout
	_ok(npc.global_position.distance_to(before) > 2.0, "NPC 在走动")


func _check_interact() -> void:
	var sign_pos := Vector2(211 * 16 + 8, 149 * 16 + 8)
	var msg: String = _world.try_interact(sign_pos)
	_ok(msg.length() > 0, "校牌可互动：%s" % msg)
	_ok(_world.zone_name(Vector2(200 * 16, 140 * 16)) == "中心花园", "区域识别：中心花园")
	_ok(_world.zone_name(Vector2(115 * 16, 100 * 16)) == "400m 操场", "区域识别：操场")
	_ok(_world.zone_name(Vector2(158 * 16, 70 * 16)) == "篮球场", "区域识别：篮球场")
	_ok(_world.zone_name(Vector2(158 * 16, 110 * 16)) == "网球场", "区域识别：网球场")
	_ok(_world.zone_name(Vector2(158 * 16, 130 * 16)) == "小池塘", "区域识别：小池塘")

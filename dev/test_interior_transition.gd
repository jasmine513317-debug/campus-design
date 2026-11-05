extends SceneTree
## Verify outdoor entry, indoor spawn/NPCs, and door return as a headless handoff.

var _fails := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(20.0).timeout.connect(func():
		push_error("Interior transition test timed out")
		quit(1)
	)
	var main: Node = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	var player := main.get_node("Player") as Node2D
	var world := main.get_node("World")
	var flow := root.get_node("SceneFlow")
	player.global_position = Vector2(3000, 728)
	player.facing = Vector2.UP
	var target: Vector2 = player.global_position + player.get("facing") * 20.0
	_check(world.interaction_hint(target) == "进入教学楼", "教学楼门口有进入提示")
	main.get_node("HUD")._update_stick(Vector2(48, 0))
	world.try_interact(target)
	_check(flow.enter("res://scenes/interiors/teaching_block.tscn", Vector2.ZERO, Vector2.ZERO) == ERR_BUSY, "切换中重复进入被拦截")
	await scene_changed
	await process_frame
	var indoor := current_scene
	_check(indoor != null and indoor.scene_file_path == "res://scenes/interiors/teaching_block.tscn", "门触发切换到教学楼室内")
	if indoor == null or indoor.scene_file_path != "res://scenes/interiors/teaching_block.tscn":
		quit(1)
		return
	var indoor_player := indoor.get_node("Player") as Node2D
	_check(indoor_player.global_position.distance_to(Vector2(400, 390)) < 1.0, "室内出生点正确")
	_check(indoor_player.touch_direction == Vector2.ZERO, "切换场景后没有遗留的摇杆移动")
	_check(not flow.pending_player_spawn and not flow.transitioning, "进入后出生点已消费且切换锁已解除")
	_check(get_nodes_in_group("npcs").size() == 4, "室内有 4 名 NPC")
	indoor_player.global_position = Vector2(400, 420)
	Input.action_press("move_down")
	for frame in 30:
		await physics_frame
	Input.action_release("move_down")
	_check(indoor_player.global_position.y < 448.0, "出口门槛阻止玩家直接走出室内边界")
	indoor_player.facing = Vector2.DOWN
	var exit_world := indoor.get_node("World")
	_check(exit_world.interaction_hint(Vector2(400, 440)) == "离开教学楼", "出口有离开提示")
	exit_world.try_interact(Vector2(400, 440))
	await scene_changed
	await process_frame
	var returned := current_scene
	_check(returned != null and returned.scene_file_path == "res://scenes/world/main.tscn", "出口返回校园主场景")
	if returned != null and returned.scene_file_path == "res://scenes/world/main.tscn":
		var returned_player := returned.get_node("Player") as Node2D
		_check(returned_player.global_position.distance_to(Vector2(3000, 728)) < 1.0, "返回位置保留在门外")
	print("----")
	print("ALL INTERIOR CHECKS PASSED" if _fails == 0 else "%d INTERIOR CHECK(S) FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] ", label)
	else:
		_fails += 1
		push_error("[FAIL] " + label)

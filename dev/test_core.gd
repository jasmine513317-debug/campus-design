extends Node
## Regression checks for input ownership, time, NPC routes and scene handoff failures.

var _fails := 0


func _ready() -> void:
	get_tree().create_timer(20.0).timeout.connect(func():
		push_error("Core regression test timed out")
		get_tree().quit(1)
	)
	GameClock.set_process(false)
	_check_clock()
	_check_input_map()
	_check_npc_step()
	var main: Node = load("res://scenes/world/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_check_routes(main)
	await _check_controls(main)
	_check_failed_handoff()
	await _check_indoor_interactions()
	print("ALL CORE CHECKS PASSED" if _fails == 0 else "%d CORE CHECK(S) FAILED" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _check_clock() -> void:
	GameClock.minutes_since_wake = 0.0
	GameClock._emit_clock()
	var notifications: Array = []
	var listener := func(h: int, m: int): notifications.append(Vector2i(h, m))
	GameClock.time_changed.connect(listener)
	for i in 10:
		GameClock._process(0.01)
	_check(notifications.is_empty(), "Sub-minute frames do not refresh HUD/lighting")
	GameClock._process(0.05)
	_check(notifications == [Vector2i(6, 1)], "Minute boundary emits one clock update")
	GameClock.paused = true
	var before := GameClock.minutes_since_wake
	GameClock._process(10.0)
	_check(GameClock.minutes_since_wake == before, "Paused clock does not advance")
	GameClock.paused = false
	GameClock.season_index = 3
	GameClock.day = 28
	GameClock.year = 1
	GameClock.minutes_since_wake = 1199.9
	GameClock._process(0.1)
	_check(GameClock.year == 2 and GameClock.day == 1 and GameClock.season_id() == "spring", "Winter rollover advances season and year")
	_check(GameClock.hour() == 6 and GameClock.minute() == 0, "02:00 returns to 06:00")
	GameClock.time_changed.disconnect(listener)
	var light: CanvasModulate = load("res://scripts/world/day_light.gd").new()
	light._on_time(1, 0)
	_check(light.color == light._sample(1.0), "After-midnight lighting samples the correct interval")
	var late: Color = light._sample(23.999)
	var midnight: Color = light._sample(0.0)
	_check(absf(late.r - midnight.r) < 0.001, "Lighting remains continuous at midnight")
	light.free()


func _check_input_map() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"run": [KEY_SHIFT], "interact": [KEY_SPACE, KEY_ENTER],
	}
	for action: String in bindings:
		var complete := InputMap.has_action(action)
		for key: int in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			complete = complete and InputMap.action_has_event(action, event)
		_check(complete, "Physical key bindings: " + action)


func _check_npc_step() -> void:
	var npc: Node2D = load("res://scripts/world/npc_student.gd").new()
	npc.route_scale = 1.0
	npc.route = [Vector2(10, 0), Vector2(20, 0)]
	add_child(npc)
	npc.set_process(false)
	npc._process(10.0)
	_check(npc.position == Vector2(10, 0), "Large frame steps stop at an NPC waypoint")
	npc.free()


func _check_routes(main: Node) -> void:
	var solids := main.get_node("World/Solids")
	var shapes: Array[CollisionShape2D] = []
	for child: Node in solids.get_children():
		if child is CollisionShape2D:
			shapes.append(child)
		else:
			for shape: CollisionShape2D in child.get_children():
				shapes.append(shape)
	for npc: Node2D in get_tree().get_nodes_in_group("npcs"):
		if npc.get_parent() != main:
			continue
		npc.set_process(false)
		var clear := true
		var first_collision := Vector2.ZERO
		for i in npc.route.size():
			var start: Vector2 = npc.route[i] * npc.route_scale
			var end: Vector2 = npc.route[(i + 1) % npc.route.size()] * npc.route_scale
			var steps := maxi(1, ceili(start.distance_to(end) / 8.0))
			for step in steps + 1:
				var sample := start.lerp(end, float(step) / steps)
				for shape: CollisionShape2D in shapes:
					var rect := Rect2(shape.position - shape.shape.size * 0.5, shape.shape.size)
					if rect.grow(4.0).has_point(sample):
						if clear:
							first_collision = sample
						clear = false
		_check(clear, "NPC route avoids solid obstacles: %d (collision %s)" % [npc.get_index(), first_collision])


func _check_controls(main: Node) -> void:
	var player := main.get_node("Player")
	var hud := main.get_node("HUD")
	player.set_physics_process(false)
	Input.action_press("move_left")
	hud._update_stick(Vector2(48, 0))
	_check(player.touch_direction == Vector2.RIGHT, "Joystick drives its own movement vector")
	hud._release_stick()
	_check(Input.is_action_pressed("move_left"), "Joystick release preserves keyboard movement")
	_check(player.touch_direction == Vector2.ZERO, "Joystick release clears touch movement")
	Input.action_release("move_left")
	hud._update_stick(Vector2(48, 0))
	hud._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(player.touch_direction == Vector2.ZERO, "Losing focus clears joystick input")
	hud._update_stick(Vector2(48, 0))
	main.remove_child(hud)
	_check(player.touch_direction == Vector2.ZERO, "Removing HUD clears joystick input")
	hud.free()
	player.global_position = Vector2(3000, 728)
	player.facing = Vector2.UP
	_check(player.interaction_hint() == "进入教学楼", "Player exposes the same entrance hint as its action")
	var before: Vector2 = player.position
	Input.action_press("move_right")
	player._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	await get_tree().physics_frame
	_check(player.position.x > before.x, "Mapped movement action moves the player")


func _check_failed_handoff() -> void:
	var previous_path := SceneFlow.return_scene_path
	var previous_position := SceneFlow.return_position
	var result := SceneFlow.enter("res://missing-scene.tscn", Vector2(1, 2), Vector2(3, 4))
	_check(result == ERR_FILE_NOT_FOUND, "Missing destination returns an error")
	_check(not SceneFlow.pending_player_spawn and not SceneFlow.transitioning, "Failed handoff leaves no stale spawn or lock")
	_check(SceneFlow.return_scene_path == previous_path and SceneFlow.return_position == previous_position, "Failed entry preserves the return destination")


func _check_indoor_interactions() -> void:
	var indoor: Node2D = load("res://scenes/interiors/teaching_block.tscn").instantiate()
	add_child(indoor)
	var world := indoor.get_node("World")
	_check(world._interactive.size() == 7, "Indoor interactions exist before a rendered frame")
	_check(world.interaction_hint(Vector2(400, 405)) == "离开教学楼", "Door prompt covers the same area as door activation")
	_check(world.try_interact(Vector2(100, 310)).contains("售货机"), "Indoor furnishing interaction works headlessly")
	_check(world.try_interact(Vector2(200, 110)).contains("黑板"), "Classroom blackboard interaction is preserved")
	await get_tree().process_frame
	await get_tree().process_frame
	_check_routes(indoor)
	var bounded := true
	for npc: Node2D in get_tree().get_nodes_in_group("npcs"):
		if npc.get_parent() != indoor:
			continue
		for step in 180:
			npc._process(0.25)
			bounded = bounded and world.get_world_rect().has_point(npc.position)
	_check(bounded, "Indoor NPCs remain inside the room during a full walk cycle")
	_check(world._interactive.size() == 7, "Redrawing does not duplicate indoor interactions")
	indoor.queue_free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] ", label)
	else:
		_fails += 1
		push_error("[FAIL] " + label)

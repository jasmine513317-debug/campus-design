extends SceneTree
var _fails := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	if ok:
		print("[PASS] ", description)
	else:
		_fails += 1
		push_error(description)

func _run() -> void:
	var main: Node2D = load("res://scenes/interiors/teaching_block.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	await process_frame
	await physics_frame
	var world: Node2D = main.get_node("World")
	var player: CharacterBody2D = main.get_node("Player")
	var blocked: Array = []
	for npc: CharacterBody2D in get_nodes_in_group("npcs"):
		_check(npc.route_scale == 1.0, "Indoor NPC uses pixel coordinates")
		for i in npc.route.size():
			var a: Vector2 = npc.route[i]
			var b: Vector2 = npc.route[(i + 1) % npc.route.size()]
			for step in range(int(a.distance_to(b) / 2) + 1):
				var p := a.move_toward(b, step * 2)
				for solid: Rect2 in world._solid_rects:
					if Rect2(p + Vector2(-5, -2), Vector2(10, 8)).intersects(solid):
						blocked.append(p)
	_check(blocked.is_empty(), "All four indoor NPC loops clear desks, walls and machines: %s" % str(blocked.slice(0, 5)))
	player.set_physics_process(false)
	for item in [["desk", Rect2(106, 147, 60, 30)], ["podium", Rect2(214, 143, 48, 34)], ["bench", Rect2(492, 370, 62, 26)], ["vending machine", Rect2(98, 318, 46, 96)], ["water fountain", Rect2(656, 326, 38, 82)]]:
		var solid: Rect2 = item[1]
		player.global_position = Vector2(solid.get_center().x, solid.end.y + 20)
		await physics_frame
		var hit := player.move_and_collide(Vector2(0, -90))
		_check(hit != null and player.position.y > solid.end.y, "Swept movement blocks " + str(item[0]))
	_check(main.get_children().filter(func(n): return n.get_script() == preload("res://scripts/art/interior_furniture.gd")).size() == 17, "All 17 indoor furnishings have actor depth sorting")
	print("ALL INTERIOR SAFETY CHECKS PASSED" if _fails == 0 else "%d INTERIOR SAFETY FAILURES" % _fails)
	quit(0 if _fails == 0 else 1)

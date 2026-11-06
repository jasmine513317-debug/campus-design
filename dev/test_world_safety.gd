extends SceneTree
## Physical regression suite: placement, complete NPC loops and swept movement.
var _fails := 0
var _main: Node2D
var _world: Node2D
var _player: CharacterBody2D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_main = load("res://scenes/world/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	await process_frame
	await process_frame
	await physics_frame
	_world = _main.get_node("World")
	_player = _main.get_node("Player")
	_check_planting()
	_check_road_buildings()
	_check_composition()
	_check_prop_bases()
	_check_routes()
	_check_depth()
	_check_controls()
	await _check_sweeps()
	await _check_student_meeting()
	print("ALL WORLD SAFETY CHECKS PASSED" if _fails == 0 else "%d SAFETY CHECKS FAILED" % _fails)
	quit(0 if _fails == 0 else 1)

func _check(condition: bool, description: String) -> void:
	if not condition:
		_fails += 1
		push_error(description)
	else:
		print("[PASS] ", description)

func _check_planting() -> void:
	var invalid: Array = []
	for tree: Sprite2D in get_nodes_in_group("trees"):
		for off in [Vector2.ZERO, Vector2(-24, -8), Vector2(24, -8), Vector2(-24, 8), Vector2(24, 8)]:
			if _world.is_walkway(tree.position + off):
				invalid.append(tree.position)
		var footprint: Rect2 = tree.get_meta("footprint")
		if not footprint.grow(1).has_point(tree.position):
			invalid.append(tree.position)
	_check(invalid.is_empty(), "All %d trees clear roads, X walks, perimeter walks and plazas: %s" % [get_nodes_in_group("trees").size(), invalid])
	for center: Vector2 in _world._garden_walk_centers():
		_check(_world._on_garden_walk(center), "X walk center matches rendered position: %s" % center)

func _check_composition() -> void:
	var u_buildings: Array = _world._buildings.filter(func(b): return b["style"] == "u3d")
	_check(u_buildings.size() == 3 and _world._buildings.filter(func(b): return b["id"] == "teach_c3").is_empty(), "The second U from the south is removed; three remain")
	var axis: float = _world.axis_world_x() / 16
	var admin: Dictionary = _world._buildings.filter(func(b): return b["id"] == "admin")[0]
	var unmatched: Array = []
	for part: Rect2i in admin["parts"]:
		var reflected := Rect2i(int(axis * 2) - part.end.x, part.position.y, part.size.x, part.size.y)
		if not admin["parts"].has(reflected):
			unmatched.append(part)
	_check(unmatched.is_empty(), "Every central building foundation has a matching mirror across the north axis")
	var garden: Rect2i = _world._garden
	_check(is_equal_approx(garden.get_center().x, axis), "Garden plaza and main gate share the teaching axis")
	var upper: Array = _world._buildings.filter(func(b): return b["id"] in ["teach_a", "teach_b", "teach_c", "teach_d"])
	var mirror_errors := 0
	for b: Dictionary in upper:
		var part: Rect2i = b["parts"][0]
		var reflected := Rect2i(int(axis * 2) - part.end.x, part.position.y, part.size.x, part.size.y)
		if not upper.any(func(other): return other["parts"].has(reflected)):
			mirror_errors += 1
	_check(mirror_errors == 0, "Northern teaching blocks mirror each other across the same axis")
	_check(_world._paths.has(Rect2i(int(axis) - 2, 24, 4, 40)), "Northern central avenue aligns with the gate and building symmetry")
	for prop: Dictionary in _world._props:
		if prop["type"] in ["bell", "stele"]:
			_check(is_equal_approx(prop["pos"].x, axis * 16), "Centered landmark: " + str(prop["type"]))
	var sprint: Rect2i = _world._straight_track
	var track: Rect2i = _world._track
	_check(sprint.end.x == track.end.x and sprint.position.x == track.end.x - 6, "Sprint lanes occupy the oval right straight, with no detached strip")
	_check(sprint.position.y == track.position.y and sprint.end.y == track.end.y, "Shared straight extends north and south to the oval limits")
	var boat := PixelArt.prop("boat")
	var white_pixels := 0
	var img := boat.get_image()
	for y in range(15, 148):
		for x in img.get_width():
			var color := img.get_pixel(x, y)
			if color.a > 0.9 and color.r > 0.8 and color.g > 0.8 and color.b > 0.75:
				white_pixels += 1
	_check(boat.get_width() >= 250 and white_pixels > 8000, "Enlarged sand boat includes a substantial white canvas sail")

func _check_prop_bases() -> void:
	var missing := 0
	for prop: Sprite2D in get_nodes_in_group("solid_props"):
		var footprint: Rect2 = prop.get_meta("footprint")
		if not _world._solid_rects.has(footprint) or absf(footprint.get_center().x - prop.position.x) > 1:
			missing += 1
	_check(missing == 0, "Every prop and lamp has an aligned physical base")

func _check_road_buildings() -> void:
	var crossings: Array = []
	for road: Rect2i in _world._paths:
		for building: Dictionary in _world._buildings:
			for part: Rect2i in building["parts"]:
				if road.intersects(part):
					crossings.append([road, building["id"]])
	_check(crossings.is_empty(), "Road network never intersects building foundations: %s" % str(crossings))

func _check_routes() -> void:
	var blocked: Array = []
	for npc: CharacterBody2D in get_nodes_in_group("npcs"):
		for i in npc.route.size():
			var a: Vector2 = npc.route[i] * npc.route_scale
			var b: Vector2 = npc.route[(i + 1) % npc.route.size()] * npc.route_scale
			for sample in range(int(a.distance_to(b) / 4) + 1):
				var point := a.move_toward(b, sample * 4)
				var feet := Rect2(point + Vector2(-5, -2), Vector2(10, 8))
				for obstacle: Rect2 in _world._solid_rects:
					if feet.intersects(obstacle):
						blocked.append([i, point, obstacle])
						break
	_check(blocked.is_empty(), "All six complete NPC loops avoid solid geometry: %s" % str(blocked.slice(0, 8)))

func _check_depth() -> void:
	var count := 0
	var invalid := 0
	for node: Node2D in get_nodes_in_group("campus_buildings"):
		count += 1
		if node.z_index != _player.z_index or not is_equal_approx(node.position.y, node.part.end.y * 16.0):
			invalid += 1
	var expected := 0
	for building: Dictionary in _world._buildings:
		expected += building["parts"].size()
	_check(count == expected and invalid == 0, "Every building part uses actor depth sorting (%d)" % count)

func _check_sweeps() -> void:
	# Real move_and_collide, with motions long enough to expose tunnelling.
	var tree: Sprite2D = get_nodes_in_group("trees")[20]
	var trunk: Rect2 = tree.get_meta("footprint")
	var prop: Sprite2D = get_nodes_in_group("solid_props")[1]
	var boat: Sprite2D = get_nodes_in_group("solid_props").filter(func(p): return str(p.name).begins_with("Prop_boat"))[0]
	var cases := [
		["tree trunk", trunk],
		["landmark", prop.get_meta("footprint")],
		["enlarged sailing boat", boat.get_meta("footprint")],
		["teaching building", Rect2(2720, 480, 544, 224)],
		["pond water", Rect2(2448, 1936, 160, 192)],
		["campus wall", Rect2(288, 224, 32, 500)],
	]
	_player.set_physics_process(false)
	_player.collision_mask = 1
	for entry: Array in cases:
		var rect: Rect2 = entry[1]
		var start := Vector2(rect.get_center().x, rect.end.y + 30)
		_player.global_position = start
		await physics_frame
		var hit := _player.move_and_collide(Vector2(0, -110))
		_check(hit != null and _player.global_position.y > rect.end.y, "Running sweep cannot cross " + str(entry[0]))

func _check_controls() -> void:
	var missing := 0
	for action in {"ui_left": KEY_A, "ui_right": KEY_D, "ui_up": KEY_W, "ui_down": KEY_S}:
		var key := InputEventKey.new()
		key.physical_keycode = {"ui_left": KEY_A, "ui_right": KEY_D, "ui_up": KEY_W, "ui_down": KEY_S}[action]
		if not InputMap.action_has_event(action, key):
			missing += 1
	_check(missing == 0, "Physical WASD bindings are available")

func _check_student_meeting() -> void:
	var students := get_nodes_in_group("npcs")
	for student: Node in students:
		student.set_physics_process(false)
	var a: CharacterBody2D = students[0]
	var b: CharacterBody2D = students[1]
	a.route = [Vector2(1780, 352), Vector2(1680, 352)]
	b.route = [Vector2(1680, 352), Vector2(1780, 352)]
	a.route_scale = 1
	b.route_scale = 1
	a.position = Vector2(1680, 352)
	b.position = Vector2(1780, 352)
	for student in [a, b]:
		student._idx = 0
		student._wait = 0
		student.set_physics_process(true)
	var overlaps := 0
	for frame in 180:
		await physics_frame
		var feet_a := Rect2(a.position + Vector2(-5, -2), Vector2(10, 8))
		var feet_b := Rect2(b.position + Vector2(-5, -2), Vector2(10, 8))
		if feet_a.intersects(feet_b):
			overlaps += 1
	_check(overlaps == 0, "Students never intersect when meeting head-on")
	_check(a.position.x > b.position.x, "Students pass each other without getting stuck")

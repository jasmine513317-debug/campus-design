extends Node2D
## Programmatic teaching building interior: two classrooms, hall, furnishings and exit.

const ROOM_A := Rect2(54, 48, 316, 226)
const ROOM_B := Rect2(430, 48, 316, 226)
const HALL := Rect2(54, 290, 692, 144)
const WALL := Color("d6c9aa")
const WALL_SHADE := Color("9c8e75")
const FLOOR_A := Color("c19a70")
const FLOOR_B := Color("c4a37b")
const HALL_FLOOR := Color("a2b1a2")
const INK := Color("3e3935")

var _solids: Node2D
var _solid_rects: Array[Rect2] = []
var _interactive: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("estate")
	_build_collision()
	_spawn_npcs()
	_spawn_furniture()
	queue_redraw()


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(800, 480))


func zone_name(_position: Vector2) -> String:
	return "教学楼 A · 室内"


func _draw() -> void:
	_interactive.clear()
	_interactive.append({"rect": Rect2(98, 318, 46, 96).grow(20), "text": "售货机里摆着饮料和零食。"})
	_interactive.append({"rect": Rect2(656, 326, 38, 82).grow(20), "text": "饮水机的水温刚刚好。"})
	draw_rect(Rect2(0, 0, 800, 480), Color("514b43"))
	_draw_tiled_floor(Rect2(32, 32, 736, 416), Color("c9bea7"), 32)
	_draw_tiled_floor(ROOM_A, FLOOR_A, 32)
	_draw_tiled_floor(ROOM_B, FLOOR_B, 32)
	_draw_tiled_floor(HALL, HALL_FLOOR, 24)
	for room: Rect2 in [ROOM_A, ROOM_B]:
		for y in range(int(room.position.y) + 9, int(room.end.y), 12):
			draw_line(Vector2(room.position.x, y), Vector2(room.end.x, y), Color("896c51", 0.25), 1)
			for x in range(int(room.position.x) + ((y / 12) % 2) * 36, int(room.end.x), 72):
				draw_line(Vector2(x, y - 11), Vector2(x, y), Color("8c6d4d", 0.28), 1)
		draw_rect(room.grow(-3), Color("805e45"), false, 2)
	# Sunlit wall windows with wooden frames and a small leafy plant below each.
	for x in [80, 330, 456, 706]:
		draw_rect(Rect2(x - 6, 69, 26, 48), Color("756451"))
		draw_rect(Rect2(x - 3, 72, 20, 39), Color("9ebfbd"))
		draw_rect(Rect2(x - 2, 73, 7, 35), Color("d5e1d1"))
		draw_rect(Rect2(x + 6, 72, 2, 39), Color("ece0bf"))
		draw_rect(Rect2(x - 6, 114, 26, 4), Color("e9cf9f"))
		draw_rect(Rect2(x, 123, 11, 10), Color("ab7656"))
		draw_rect(Rect2(x - 2, 115, 15, 10), Color("638661"))
		draw_rect(Rect2(x + 1, 111, 6, 9), Color("94b177"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 3, 120), Vector2(x + 17, 120), Vector2(x + 65, 166), Vector2(x + 28, 166)]), Color("fff2c2", 0.09))
	# Exterior walls and baseboards.
	_draw_wall(Rect2(24, 24, 752, 24))
	_draw_wall(Rect2(24, 24, 24, 432))
	_draw_wall(Rect2(752, 24, 24, 432))
	_draw_wall(Rect2(24, 448, 324, 24))
	_draw_wall(Rect2(452, 448, 324, 24))
	# Classroom fronts; door openings align to the central corridor.
	_draw_wall(Rect2(54, 270, 142, 18))
	_draw_wall(Rect2(250, 270, 120, 18))
	_draw_wall(Rect2(430, 270, 142, 18))
	_draw_wall(Rect2(626, 270, 120, 18))
	_draw_wall(Rect2(388, 48, 24, 230))
	_draw_wall(Rect2(54, 48, 692, 18))
	_draw_wall(Rect2(54, 48, 18, 240))
	_draw_wall(Rect2(728, 48, 18, 240))
	# Room doors, plaques, and classroom boards.
	_draw_classroom_door(Vector2(196, 270), "A101")
	_draw_classroom_door(Vector2(572, 270), "A102")
	_draw_blackboard(Rect2(142, 74, 170, 46), "今日课程：函数与极限", "例：f(x) = x² + 2x")
	_draw_blackboard(Rect2(506, 74, 170, 46), "物理实验 · 力与运动", "F = m · a")
	# Corridor bulletin board, vending machine and water fountain.
	_draw_bulletin_board(Rect2(344, 304, 108, 70))
	_draw_wall_clock(Vector2(400, 88))
	_draw_exit_door(Rect2(356, 430, 88, 28))
	# Warm light pools under the hallway lamps.
	for x in [180.0, 400.0, 620.0]:
		draw_rect(Rect2(x - 4, 294, 8, 3), Color("f1dc9d"))
		draw_rect(Rect2(x - 22, 298, 44, 2), Color("e6d2a0", 0.12))
	draw_rect(Rect2(24, 24, 752, 432), Color("51483e"), false, 2.0)


func _draw_tiled_floor(rect: Rect2, color: Color, tile: int) -> void:
	draw_rect(rect, color)
	var dark := color.darkened(0.09)
	var light := color.lightened(0.07)
	for x in range(int(rect.position.x), int(rect.end.x), tile):
		draw_line(Vector2(x, rect.position.y), Vector2(x, rect.end.y), dark, 1.0, false)
	for y in range(int(rect.position.y), int(rect.end.y), tile):
		draw_line(Vector2(rect.position.x, y), Vector2(rect.end.x, y), dark, 1.0, false)
	for y in range(int(rect.position.y) + int(tile / 2), int(rect.end.y), tile):
		for x in range(int(rect.position.x) + int(tile / 2), int(rect.end.x), tile):
			if (int(x / tile) + int(y / tile)) % 3 == 0:
				draw_rect(Rect2(x, y, 2, 2), light)


func _draw_wall(rect: Rect2, outline: bool = false) -> void:
	draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color("51483e", 0.22))
	draw_rect(rect, WALL_SHADE)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, minf(rect.size.y, 5.0))), WALL.lightened(0.12))
	draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size - Vector2(6, 7)), WALL)
	if outline:
		draw_rect(rect, Color("51483e"), false, 2.0)


func _draw_classroom_door(pos: Vector2, plaque: String) -> void:
	draw_rect(Rect2(pos + Vector2(0, -2), Vector2(54, 7)), Color("75614b"))
	draw_rect(Rect2(pos + Vector2(3, 5), Vector2(48, 12)), Color("57483a"))
	draw_rect(Rect2(pos + Vector2(7, 17), Vector2(40, 54)), Color("7b6349"))
	draw_rect(Rect2(pos + Vector2(10, 20), Vector2(34, 48)), Color("9c7754"))
	draw_rect(Rect2(pos + Vector2(12, 23), Vector2(29, 43)), Color("b6a27d"))
	draw_rect(Rect2(pos + Vector2(14, 26), Vector2(24, 37)), Color("738b8d"))
	draw_rect(Rect2(pos + Vector2(15, 27), Vector2(9, 32)), Color("a7c1b9"))
	draw_rect(Rect2(pos + Vector2(36, 45), Vector2(3, 3)), Color("e0bd67"))
	draw_rect(Rect2(pos + Vector2(16, -17), Vector2(38, 13)), Color("745b42"))
	draw_rect(Rect2(pos + Vector2(18, -15), Vector2(34, 9)), Color("e6d4a8"))
	draw_string(ThemeDB.fallback_font, pos + Vector2(21, -8), plaque, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, INK)
	_interactive.append({"rect": Rect2(pos + Vector2(-9, 0), Vector2(72, 74)), "text": "%s 教室门牌" % plaque})


func _draw_blackboard(rect: Rect2, heading: String, line: String) -> void:
	draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color("40382f", 0.30))
	draw_rect(rect, Color("654c36"))
	draw_rect(rect.grow(-4), Color("344c43"))
	draw_rect(Rect2(rect.position + Vector2(7, 6), Vector2(rect.size.x - 14, 1)), Color("b7a37b"))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 24), heading, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 20, 10, Color("e5dcc0"))
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(14, 39), line, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 22, 9, Color("c9d0b4"))
	draw_rect(Rect2(rect.position.x + 8, rect.end.y + 2, rect.size.x - 16, 3), Color("a4845d"))
	_interactive.append({"rect": rect.grow(18), "text": "黑板上写着今天的课程内容。"})


func _draw_bulletin_board(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(3, 4), rect.size), Color("40382f", 0.26))
	draw_rect(rect, Color("654d39"))
	draw_rect(rect.grow(-4), Color("b18a5d"))
	for i in 3:
		var note := Rect2(rect.position + Vector2(10 + i * 28, 11 + (i % 2) * 7), Vector2(20, 28))
		draw_rect(note, Color("e9dfc2"))
		draw_rect(Rect2(note.position + Vector2(3, 5), Vector2(14, 1)), Color("95866b"))
		draw_rect(Rect2(note.position + Vector2(3, 10), Vector2(11, 1)), Color("95866b"))
		draw_circle(note.position + Vector2(10, 2), 2.0, Color("a04f43"))
	_interactive.append({"rect": rect.grow(22), "text": "公告栏：本周课程与社团活动安排。"})


func _draw_wall_clock(center: Vector2) -> void:
	draw_circle(center + Vector2(2, 3), 15.0, Color("5c5142", 0.28))
	draw_circle(center, 14.0, Color("eadbb9"))
	draw_circle(center, 11.0, Color("f4e8cc"))
	draw_arc(center, 11.0, 0.0, TAU, 12, Color("665744"), 1.0)
	draw_line(center, center + Vector2(-1, -7), INK, 1.5)
	draw_line(center, center + Vector2(6, 2), INK, 1.0)
	draw_circle(center, 1.5, Color("a17443"))


func _draw_exit_door(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position.x - 14, rect.position.y - 8, rect.size.x + 28, 9), Color("65533f"))
	draw_rect(Rect2(rect.position.x - 9, rect.position.y, rect.size.x + 18, rect.size.y), Color("57483a"))
	draw_rect(Rect2(rect.position.x - 4, rect.position.y + 3, rect.size.x + 8, rect.size.y - 5), Color("77908e"))
	draw_rect(Rect2(rect.position.x + 5, rect.position.y + 5, rect.size.x - 10, rect.size.y - 9), Color("a7c0b7"))
	draw_rect(Rect2(rect.get_center().x - 2, rect.position.y + 5, 4, rect.size.y - 9), Color("596d6b"))
	draw_rect(Rect2(rect.end.x - 9, rect.position.y + 14, 3, 3), Color("e1bd68"))
	_interactive.append({"rect": Rect2(350, 414, 100, 66), "text": "离开教学楼，回到校园。"})


func _build_collision() -> void:
	_solids = Node2D.new()
	_solids.name = "Solids"
	add_child(_solids)
	for rect in [
		Rect2(24, 24, 752, 24), Rect2(24, 24, 24, 432), Rect2(752, 24, 24, 432),
		Rect2(24, 448, 324, 24), Rect2(452, 448, 324, 24),
		Rect2(54, 270, 142, 18), Rect2(250, 270, 120, 18),
		Rect2(430, 270, 142, 18), Rect2(626, 270, 120, 18), Rect2(388, 48, 24, 230),
		Rect2(54, 48, 692, 18), Rect2(54, 48, 18, 240), Rect2(728, 48, 18, 240),
		Rect2(98, 318, 46, 96), Rect2(656, 326, 38, 82), Rect2(344, 304, 108, 70),
		Rect2(492, 370, 62, 26), Rect2(214, 143, 48, 34), Rect2(578, 143, 48, 34),
	]:
		_add_solid(rect)
	for p in [Vector2(106, 145), Vector2(174, 145), Vector2(280, 145), Vector2(106, 208), Vector2(174, 208), Vector2(280, 208), Vector2(482, 145), Vector2(550, 145), Vector2(656, 145), Vector2(482, 208), Vector2(550, 208), Vector2(656, 208)]:
		_add_solid(Rect2(p + Vector2(0, 2), Vector2(60, 30)))


func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)
	_solids.add_child(body)
	_solid_rects.append(rect)


func _spawn_furniture() -> void:
	var items := [
		["podium", Vector2(210, 137), 42], ["podium", Vector2(574, 137), 42],
		["vending", Vector2(98, 318), 96], ["water", Vector2(656, 326), 82],
		["bench", Vector2(484, 366), 30],
	]
	for p in [Vector2(106, 145), Vector2(174, 145), Vector2(280, 145), Vector2(106, 208), Vector2(174, 208), Vector2(280, 208), Vector2(482, 145), Vector2(550, 145), Vector2(656, 145), Vector2(482, 208), Vector2(550, 208), Vector2(656, 208)]:
		items.append(["desk", p, 32])
	for item: Array in items:
		var visual := preload("res://scripts/art/interior_furniture.gd").new()
		visual.kind = item[0]
		visual.anchor = item[1]
		visual.position = item[1] + Vector2(0, item[2])
		get_parent().add_child.call_deferred(visual)


func _spawn_npcs() -> void:
	var npc_script := preload("res://scripts/world/npc_student.gd")
	var routes := [
		[Vector2(164, 338), Vector2(268, 338), Vector2(268, 400), Vector2(164, 400)],
		[Vector2(480, 408), Vector2(630, 408), Vector2(630, 424), Vector2(480, 424)],
		[Vector2(254, 184), Vector2(272, 184), Vector2(272, 196), Vector2(254, 196)],
		[Vector2(634, 184), Vector2(646, 184), Vector2(646, 196), Vector2(634, 196)],
	]
	var shirts := [Color("b26654"), Color("637d91"), Color("9a8050"), Color("6a8066")]
	for i in routes.size():
		var npc: Node2D = npc_script.new()
		npc.route = routes[i]
		npc.shirt = shirts[i]
		npc.position = routes[i][0]
		get_parent().add_child.call_deferred(npc)


func interaction_hint(world_pos: Vector2) -> String:
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as Node2D
		if npc != null and npc.global_position.distance_to(world_pos) < 58.0:
			return "打个招呼"
	for item: Dictionary in _interactive:
		if (item["rect"] as Rect2).has_point(world_pos):
			return "离开教学楼" if world_pos.y > 414.0 else "查看"
	return ""


func try_interact(world_pos: Vector2) -> String:
	if Rect2(350, 414, 100, 66).grow(12.0).has_point(world_pos):
		SceneFlow.leave_building()
		return "走出教学楼，回到校园。"
	for item: Dictionary in _interactive:
		if (item["rect"] as Rect2).has_point(world_pos):
			return str(item["text"])
	return ""

extends Node2D
## 校园世界：严格按 campus 平面图生成建筑、道路、操场、球场、花园与绿化。
##
## 分工：
##   World（本节点，z_index = -10）  静态地表 / 建筑 / 操场 / 球场 / 围墙
##   Sprite2D（挂在父节点）          树、道具、人物，按 y 排序，可与玩家互相遮挡
## 所有几何都来自 data/estate.json。

const TILE := 16
const FLOORS := 5

var _layout: Dictionary = {}
var _size := Vector2i(400, 180)
var _campus := Rect2i(18, 14, 364, 142)
var _paths: Array[Rect2i] = []
var _path_cells: Dictionary = {}
var _buildings: Array = []
var _gates: Array[Rect2i] = []
var _track := Rect2i()
var _courts: Array[Rect2i] = []
var _tennis := Rect2i()
var _pond := Rect2i()
var _straight_track := Rect2i()
var _top_garden := Rect2i()
var _landscape := Rect2i()
var _garden := Rect2i()
var _blocked: Dictionary = {}
var _labels: Array = []
var _props: Array = []
var _tree_shadows: Array = []
var _solids: StaticBody2D
var _tile_rects: Dictionary = {}
var _player: Node2D

var _wall_tex: Texture2D
var _roof_tex: Texture2D
var _paving_tex: Texture2D
var _track_tex: Texture2D
var _court_tex: Texture2D
var _hedge_tex: Texture2D
var _asphalt_tex: Texture2D
var _concrete_tex: Texture2D
var _brick_pave_tex: Texture2D


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_load_layout()
	for name in ["grass0", "grass1", "grass2", "grass3", "grass4", "grass5", "grass6", "grass7", "lawn", "lawn2", "lawn3", "paving", "hedge", "asphalt", "concrete", "brick_paving"]:
		_tile_rects[name] = PixelArt.cell(name)
	_wall_tex = PixelArt.tile_texture("wall_plaster")
	_roof_tex = PixelArt.tile_texture("roof_concrete")
	_paving_tex = PixelArt.tile_texture("paving")
	_track_tex = PixelArt.tile_texture("track")
	_court_tex = PixelArt.tile_texture("court")
	_hedge_tex = PixelArt.tile_texture("hedge")
	_asphalt_tex = PixelArt.tile_texture("asphalt")
	_concrete_tex = PixelArt.tile_texture("concrete")
	_brick_pave_tex = PixelArt.tile_texture("brick_paving")
	_build_masks()
	_build_collision()
	_build_labels()
	add_to_group("estate")
	queue_redraw()
	_spawn_decor.call_deferred()


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	for entry: Dictionary in _labels:
		var label: Label = entry["label"]
		var dist: float = _player.global_position.distance_to(entry["pos"])
		var a := clampf(1.4 - dist / 340.0, 0.0, 0.95)
		label.modulate.a = a
		label.visible = a > 0.02


# =====================================================================
# 数据
# =====================================================================

func _load_layout() -> void:
	var file := FileAccess.open("res://data/estate.json", FileAccess.READ)
	if file == null:
		push_error("无法读取 estate.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("estate.json 格式错误")
		return
	_layout = parsed
	var size: Array = _layout.get("size", [400, 180])
	_size = Vector2i(int(size[0]), int(size[1]))
	_campus = _rect_i(_layout.get("campus", [18, 14, 364, 142]))
	for p: Variant in _layout.get("paths", []):
		_paths.append(_rect_i(p))
	for g: Variant in _layout.get("boundary", {}).get("gates", []):
		_gates.append(_rect_i(g))
	_track = _rect_i(_layout.get("track", [84, 58, 62, 90]))
	for c: Variant in _layout.get("courts", []):
		_courts.append(_rect_i(c))
	_tennis = _rect_i(_layout.get("tennis", [0, 0, 0, 0]))
	_pond = _rect_i(_layout.get("pond", [0, 0, 0, 0]))
	_straight_track = _rect_i(_layout.get("straight_track", [0, 0, 0, 0]))
	_top_garden = _rect_i(_layout.get("top_garden", [0, 0, 0, 0]))
	_landscape = _rect_i(_layout.get("landscape", [0, 0, 0, 0]))
	_garden = _rect_i(_layout.get("garden", [160, 126, 80, 24]))
	for b: Variant in _layout.get("buildings", []):
		var building: Dictionary = b
		var parts: Array[Rect2i] = []
		for p: Variant in building.get("parts", []):
			parts.append(_rect_i(p))
		building["parts"] = parts
		_buildings.append(building)


func _rect_i(arr: Variant) -> Rect2i:
	var a: Array = arr
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))


func _build_masks() -> void:
	for path: Rect2i in _paths:
		for y in range(path.position.y, path.end.y):
			for x in range(path.position.x, path.end.x):
				_path_cells[Vector2i(x, y)] = true
				_blocked[Vector2i(x, y)] = true
	for b: Variant in _buildings:
		for part: Rect2i in (b as Dictionary)["parts"]:
			for y in range(part.position.y - 1, part.end.y + 1):
				for x in range(part.position.x - 1, part.end.x + 1):
					_blocked[Vector2i(x, y)] = true
	for y in range(_track.position.y, _track.end.y):
		for x in range(_track.position.x, _track.end.x):
			_blocked[Vector2i(x, y)] = true
	for c: Rect2i in _courts:
		for y in range(c.position.y, c.end.y):
			for x in range(c.position.x, c.end.x):
				_blocked[Vector2i(x, y)] = true
	if _tennis.size.x > 0:
		for y in range(_tennis.position.y, _tennis.end.y):
			for x in range(_tennis.position.x, _tennis.end.x):
				_blocked[Vector2i(x, y)] = true
	if _pond.size.x > 0:
		for y in range(_pond.position.y, _pond.end.y):
			for x in range(_pond.position.x, _pond.end.x):
				_blocked[Vector2i(x, y)] = true
	for y in range(_campus.position.y, _campus.end.y):
		for x in range(_campus.position.x, _campus.end.x):
			if x < _campus.position.x + 2 or x >= _campus.end.x - 2 or y < _campus.position.y + 2 or y >= _campus.end.y - 2:
				_blocked[Vector2i(x, y)] = true


func _free(cell: Vector2i) -> bool:
	if cell.x < 2 or cell.y < 2 or cell.x >= _size.x - 2 or cell.y >= _size.y - 2:
		return false
	return not _blocked.has(cell)


func _in_gate(cell: Vector2i) -> bool:
	for g: Rect2i in _gates:
		if g.has_point(cell):
			return true
	return false


func get_world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(_size * TILE))


func spawn_point() -> Vector2:
	return Vector2(193 * TILE + 8, 152 * TILE + 8)


# =====================================================================
# 地表
# =====================================================================

func _draw() -> void:
	_draw_ground()
	_draw_aprons()
	_draw_paths()
	_draw_beds()
	_draw_garden()
	_draw_track()
	_draw_straight_track()
	_draw_courts()
	_draw_tennis()
	_draw_pond()
	_draw_top_garden()
	_draw_landscape()
	_draw_shadows()
	_draw_buildings()
	_draw_boundary()
	_draw_ground_details()


func _draw_shadows() -> void:
	## 统一光源（左上）投射的阴影层：建筑 + 树。画在建筑之前，被建筑本体盖住，
	## 只在轮廓外露出，形成 2.5D 的落地感。
	var s := Color("3a3140")
	for b: Variant in _buildings:
		var building: Dictionary = b
		if str(building.get("style", "slab")) == "glass":
			continue
		for part: Rect2i in building["parts"]:
			var px := Rect2(part.position * TILE, part.size * TILE)
			var dy := clampf(px.size.y * 0.26, 16.0, 50.0)
			var dx := dy * 0.38
			draw_rect(Rect2(px.position + Vector2(dx, dy), px.size), Color(s, 0.22))
			draw_rect(Rect2(px.position + Vector2(dx * 1.5, dy * 1.3), px.size), Color(s, 0.11))
	for t: Variant in _tree_shadows:
		var e: Array = t
		var p: Vector2 = e[0]
		var w: float = e[1]
		var r := Vector2(w * 0.36, w * 0.13)
		var off := Vector2(w * 0.15, w * 0.09)
		_ellipse(p + off, r, Color(s, 0.17))
		_ellipse(p + off * 1.35, r * 1.3, Color(s, 0.07))


func _grass_name(x: int, y: int) -> String:
	var h := absi((x * 73856093) ^ (y * 19349663)) % 1000
	var base := (absi((x * 83492791) ^ (y * 2097593)) % 2) * 4
	if h < 300:
		return "grass%d" % base
	elif h < 580:
		return "grass%d" % (base + 1)
	elif h < 700:
		return "grass%d" % (base + 2)
	return "grass%d" % (base + 3)


func _lawn_name(x: int, y: int) -> String:
	var h := absi((x * 40503) ^ (y * 12289)) % 100
	if h < 55:
		return "lawn"
	elif h < 85:
		return "lawn2"
	return "lawn3"


func _draw_ground() -> void:
	var tex := PixelArt.atlas()
	var in_campus_x0 := _campus.position.x
	var in_campus_y0 := _campus.position.y
	var in_campus_x1 := _campus.end.x
	var in_campus_y1 := _campus.end.y
	for y in _size.y:
		var py := y * TILE
		for x in _size.x:
			var name := _grass_name(x, y)
			if x >= in_campus_x0 and x < in_campus_x1 and y >= in_campus_y0 and y < in_campus_y1:
				name = _lawn_name(x, y)
			draw_texture_rect_region(tex, Rect2(x * TILE, py, TILE, TILE), _tile_rects[name])


func _draw_aprons() -> void:
	## 建筑四周铺与建筑风格配套的硬质铺装，形成“楼前场院”。
	for b: Variant in _buildings:
		var building: Dictionary = b
		var style := str(building.get("style", "slab"))
		var tex: Texture2D = _concrete_tex
		match style:
			"classic", "u3d", "hall", "library":
				tex = _paving_tex
			"brick", "gable":
				tex = _brick_pave_tex
			_:
				tex = _concrete_tex
		for part: Rect2i in building["parts"]:
			var r := Rect2(part.position * TILE, part.size * TILE).grow(32)
			draw_texture_rect(tex, r, true)
			draw_rect(Rect2(r.position + Vector2(1, 1), r.size - Vector2(2, 2)), Color(0, 0, 0, 0.08), false, 2.0)


func _is_path(cell: Vector2i) -> bool:
	return _path_cells.has(cell)


func _draw_paths() -> void:
	var tex := PixelArt.atlas()
	for path: Rect2i in _paths:
		for y in range(path.position.y, path.end.y):
			for x in range(path.position.x, path.end.x):
				var cell := Vector2i(x, y)
				var px := Vector2(x * TILE, y * TILE)
				draw_texture_rect_region(tex, Rect2(px, Vector2(TILE, TILE)), _tile_rects["asphalt"])
				# 路缘石：受光顶面 + 竖直侧面 + 落下投影，做出 2px 高差
				if not _is_path(cell + Vector2i(0, -1)):
					draw_rect(Rect2(px.x, px.y, TILE, 1), Color("ece6d8"))
					draw_rect(Rect2(px.x, px.y + 1, TILE, 2), Color("d4cec0"))
					draw_rect(Rect2(px.x, px.y + 3, TILE, 1), Color(0.16, 0.13, 0.18, 0.38))
				if not _is_path(cell + Vector2i(0, 1)):
					draw_rect(Rect2(px.x, px.y + TILE - 3, TILE, 2), Color("bdb7a9"))
					draw_rect(Rect2(px.x, px.y + TILE - 1, TILE, 1), Color(0.14, 0.11, 0.16, 0.42))
				if not _is_path(cell + Vector2i(-1, 0)):
					draw_rect(Rect2(px.x, px.y, 1, TILE), Color("e2dccd"))
					draw_rect(Rect2(px.x + 1, px.y, 2, TILE), Color("c9c3b5"))
				if not _is_path(cell + Vector2i(1, 0)):
					draw_rect(Rect2(px.x + TILE - 2, px.y, 2, TILE), Color("b6b0a2"))
					draw_rect(Rect2(px.x + TILE - 1, px.y, 1, TILE), Color(0.14, 0.11, 0.16, 0.38))
	# 中央虚线
	for path: Rect2i in _paths:
		var horizontal := path.size.x >= path.size.y
		var length := maxi(path.size.x, path.size.y)
		if length < 16:
			continue
		if horizontal:
			var cy := (path.position.y + path.size.y * 0.5) * TILE
			var x := path.position.x * TILE + 10.0
			while x < path.end.x * TILE - 10.0:
				draw_rect(Rect2(x, cy - 1, 12, 2), Color(0.90, 0.88, 0.78, 0.65))
				x += 30.0
		else:
			var cx := (path.position.x + path.size.x * 0.5) * TILE
			var y := path.position.y * TILE + 10.0
			while y < path.end.y * TILE - 10.0:
				draw_rect(Rect2(cx - 1, y, 2, 12), Color(0.90, 0.88, 0.78, 0.65))
				y += 30.0
	# 校门前的斑马线
	if not _gates.is_empty():
		var gate: Rect2i = _gates[0]
		for i in 4:
			draw_rect(Rect2(gate.position.x * TILE, 150 * TILE + 6 + i * 14, gate.size.x * TILE, 7), Color(0.92, 0.92, 0.88, 0.70))
	# 井盖
	for path: Rect2i in _paths:
		var h := absi((path.position.x * 31) ^ (path.position.y * 17))
		if h % 5 != 0:
			continue
		var gx := path.position.x + h % maxi(1, path.size.x)
		var gy := path.position.y + (h / 3) % maxi(1, path.size.y)
		draw_circle(Vector2(gx * TILE + 8, gy * TILE + 8), 5.0, Color("6f7275"))
		draw_circle(Vector2(gx * TILE + 8, gy * TILE + 8), 3.0, Color("55585a"))


func _draw_ground_details() -> void:
	for y in range(2, _size.y - 2):
		for x in range(2, _size.x - 2):
			var h := absi((x * 92837111) ^ (y * 689287499)) % 10000
			if h >= 150:
				continue
			var cell := Vector2i(x, y)
			if _blocked.has(cell):
				continue
			if _path_cells.has(cell):
				continue
			if _garden.has_point(cell):
				continue
			var px := Vector2(x * TILE + 4, y * TILE + 6)
			if h < 40:
				var petals := [Color("f2e9a8"), Color("e8b3c8"), Color("f0f0f0"), Color("a8c8f0")]
				draw_rect(Rect2(px + Vector2(0, 1), Vector2(1, 3)), Color("4f8a46"))
				draw_rect(Rect2(px + Vector2(-1, -1), Vector2(3, 3)), petals[h % petals.size()])
				draw_rect(Rect2(px + Vector2(0, 0), Vector2(1, 1)), Color("d9c76a"))
			elif h < 100:
				draw_rect(Rect2(px, Vector2(2, 1)), Color("7fb257"))
				draw_rect(Rect2(px + Vector2(1, -1), Vector2(1, 2)), Color("4c7331"))
			else:
				draw_rect(Rect2(px, Vector2(3, 2)), Color("9a9484"))
				draw_rect(Rect2(px + Vector2(0, 0), Vector2(2, 1)), Color("b7b1a1"))


# =====================================================================
# 花园（中轴对称 + 两片 X 形花坛）
# =====================================================================

func _draw_beds() -> void:
	# 沿路的小花坛，填补大片草坪的空
	var flowers := [Color("e8b3c8"), Color("f2e9a8"), Color("e07070"), Color("a8c8f0")]
	for path: Rect2i in _paths:
		var horizontal := path.size.x >= path.size.y
		var count := int(path.size.x / 15.0) if horizontal else int(path.size.y / 15.0)
		for i in range(1, count):
			var cell: Vector2i
			if horizontal:
				cell = Vector2i(path.position.x + i * 15, path.position.y - 2)
			else:
				cell = Vector2i(path.position.x - 2, path.position.y + i * 15)
			if not _free(cell):
				continue
			if _garden.grow(2).has_point(cell):
				continue
			var r := Rect2(cell.x * TILE - 12, cell.y * TILE - 6, 40, 24)
			draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Color(0.10, 0.14, 0.08, 0.18))
			draw_rect(r, Color("6b4a2c"))
			draw_rect(Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 4)), Color("4b3220"))
			draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 1)), Color("8a5f38"))
			for f in 3:
				var fp := r.position + Vector2(7 + f * 11, 8)
				draw_rect(Rect2(fp + Vector2(0, 3), Vector2(1, 4)), Color("4f8a46"))
				draw_rect(Rect2(fp + Vector2(-2, -2), Vector2(5, 5)), flowers[(i + f) % flowers.size()])
				draw_rect(Rect2(fp + Vector2(-1, -1), Vector2(1, 1)), Color("f6f0c8"))


func _draw_garden() -> void:
	if _garden.size.x <= 0:
		return
	var px := Rect2(_garden.position * TILE, _garden.size * TILE)
	var c := px.get_center()
	draw_texture_rect(PixelArt.tile_texture("lawn"), px, true)
	# 中轴大道加宽到 12 格，地标不再拥挤
	var axis_w := 192.0
	var axis := Rect2(c.x - axis_w * 0.5, px.position.y, axis_w, px.size.y)
	draw_texture_rect(_paving_tex, axis, true)
	draw_rect(Rect2(axis.position.x, axis.position.y, 2, axis.size.y), Color("e9e3d2"))
	draw_rect(Rect2(axis.end.x - 2, axis.position.y, 2, axis.size.y), Color("b9b2a0"))
	# 轴线两侧花带
	for side in [-1, 1]:
		var fx := c.x + float(side) * (axis_w * 0.5 + 12.0)
		var strip := Rect2(fx - 9, px.position.y + 16, 18, px.size.y - 32)
		draw_rect(strip, Color("6b4a2c"))
		draw_rect(Rect2(strip.position + Vector2(2, 2), strip.size - Vector2(4, 4)), Color("4b3220"))
		draw_rect(Rect2(strip.position, Vector2(strip.size.x, 1)), Color("8a5f38"))
		for i in range(0, int(strip.size.y) - 12, 14):
			var fy := strip.position.y + 6 + i
			draw_rect(Rect2(strip.position.x + 3, fy + 2, 2, 4), Color("4f8a46"))
			draw_rect(Rect2(strip.position.x + 5, fy, 8, 5), [Color("e8b3c8"), Color("f2e9a8"), Color("e07070")][int(i / 14.0) % 3])
			draw_rect(Rect2(strip.position.x + 7, fy + 1, 2, 2), Color("f6f0c8"))
	# 两片 X 形花林：窄人行小道（2 格），其余留给草木
	var zone_w := 32.0 * TILE
	var zone_h := 20.0 * TILE
	_draw_x_walk(Vector2(px.position.x + 18.0 * TILE, c.y), zone_w, zone_h)
	_draw_x_walk(Vector2(px.end.x - 18.0 * TILE, c.y), zone_w, zone_h)
	_draw_garden_plants()
	# 中央环形广场（抬高 2px，带落影）
	_ellipse(c + Vector2(3, 6), Vector2(86, 86), Color(0.16, 0.12, 0.18, 0.22))
	_ellipse(c, Vector2(84, 84), Color("c9c2b0"))
	_ellipse(c, Vector2(78, 78), Color("d9d2c0"))
	_ellipse(c, Vector2(54, 54), Color("bfb8a6"))
	_ellipse(c, Vector2(48, 48), Color("d2cbb8"))
	# 花园外圈：与人行道同材质的铺装收边（去掉原来的绿篱/草地圈，和道路自然衔接）
	var edge := 2
	var edge_rects := [
		Rect2i(_garden.position, Vector2i(_garden.size.x, edge)),
		Rect2i(Vector2i(_garden.position.x, _garden.end.y - edge), Vector2i(_garden.size.x, edge)),
		Rect2i(Vector2i(_garden.position.x, _garden.position.y + edge), Vector2i(edge, _garden.size.y - edge * 2)),
		Rect2i(Vector2i(_garden.end.x - edge, _garden.position.y + edge), Vector2i(edge, _garden.size.y - edge * 2)),
	]
	for er: Rect2i in edge_rects:
		draw_texture_rect(_paving_tex, Rect2(er.position * TILE, er.size * TILE), true)
	draw_rect(Rect2(px.position, px.size), Color("b0a996"), false, 2.0)


func _draw_x_walk(center: Vector2, w: float, h: float) -> void:
	## 花林里的 X 形人行小道：外圈 2 格 + 对角 2 格，窄而连通。
	var rect := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	var t := 32.0
	draw_texture_rect(_paving_tex, Rect2(rect.position, Vector2(w, t)), true)
	draw_texture_rect(_paving_tex, Rect2(rect.position + Vector2(0, h - t), Vector2(w, t)), true)
	draw_texture_rect(_paving_tex, Rect2(rect.position, Vector2(t, h)), true)
	draw_texture_rect(_paving_tex, Rect2(rect.position + Vector2(w - t, 0), Vector2(t, h)), true)
	var corners := [
		rect.position,
		rect.position + Vector2(w, 0),
		rect.position + Vector2(0, h),
		rect.position + Vector2(w, h),
	]
	for corner: Vector2 in corners:
		draw_line(corner, center, Color("8f897b"), 44.0)
		draw_line(corner, center, Color("c9c2b0"), 38.0)
		draw_line(corner, center, Color("ddd6c4"), 32.0)
		# 圆角收头，避免岔口露出尖角
		draw_circle(corner, 19.0, Color("c9c2b0"))
		draw_circle(corner, 16.0, Color("ddd6c4"))
	draw_circle(center, 22.0, Color("c9c2b0"))
	draw_circle(center, 18.0, Color("ddd6c4"))


func _on_garden_walk(p: Vector2) -> bool:
	## 判断一个世界坐标点是否落在花园的步道 / 中轴 / 中心广场上。
	if _garden.size.x <= 0:
		return false
	var px := Rect2(_garden.position * TILE, _garden.size * TILE)
	if not px.has_point(p):
		return false
	var c := px.get_center()
	if absf(p.x - c.x) < 100.0:
		return true
	if p.distance_to(c) < 88.0:
		return true
	for side in [-1.0, 1.0]:
		var zc := Vector2(c.x + float(side) * 18.0 * TILE, c.y)
		var rect := Rect2(zc - Vector2(16.0 * TILE, 10.0 * TILE), Vector2(32.0 * TILE, 20.0 * TILE))
		if not rect.has_point(p):
			continue
		var t := 32.0
		if p.y < rect.position.y + t or p.y > rect.end.y - t:
			return true
		if p.x < rect.position.x + t or p.x > rect.end.x - t:
			return true
		var corners := [
			rect.position,
			rect.position + Vector2(rect.size.x, 0),
			rect.position + Vector2(0, rect.size.y),
			rect.position + Vector2(rect.size.x, rect.size.y),
		]
		for corner: Vector2 in corners:
			if Geometry2D.get_closest_point_to_segment(p, corner, zc).distance_to(p) < 24.0:
				return true
		if p.distance_to(zc) < 24.0:
			return true
	return false


func _draw_garden_plants() -> void:
	## 花林底层：散落的花丛、草簇和小灌木，避开步道。
	var px := Rect2(_garden.position * TILE, _garden.size * TILE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9173
	var petals := [Color("e8b3c8"), Color("f2e9a8"), Color("e07070"), Color("a8c8f0"), Color("d9a0e0"), Color("f0c8a0")]
	for i in 170:
		var p := Vector2(rng.randf_range(px.position.x + 20, px.end.x - 20), rng.randf_range(px.position.y + 20, px.end.y - 20))
		if _on_garden_walk(p) or _is_path(Vector2i(int(p.x / TILE), int(p.y / TILE))):
			continue
		var c: Color = petals[i % petals.size()]
		draw_rect(Rect2(p + Vector2(0, 2), Vector2(1, 4)), Color("4f8a46"))
		draw_rect(Rect2(p + Vector2(-2, -1), Vector2(5, 4)), c)
		draw_rect(Rect2(p + Vector2(-1, 0), Vector2(1, 1)), Color("f6f0c8"))
	for i in 120:
		var p2 := Vector2(rng.randf_range(px.position.x + 20, px.end.x - 20), rng.randf_range(px.position.y + 20, px.end.y - 20))
		if _on_garden_walk(p2) or _is_path(Vector2i(int(p2.x / TILE), int(p2.y / TILE))):
			continue
		draw_rect(Rect2(p2, Vector2(2, 1)), Color("7a8a4a"))
		draw_rect(Rect2(p2 + Vector2(1, -1), Vector2(1, 2)), Color("5a6a36"))
	for i in 26:
		var p3 := Vector2(rng.randf_range(px.position.x + 24, px.end.x - 24), rng.randf_range(px.position.y + 24, px.end.y - 24))
		if _on_garden_walk(p3) or _is_path(Vector2i(int(p3.x / TILE), int(p3.y / TILE))):
			continue
		_ellipse(p3, Vector2(9, 6), Color("4a5a32"))
		_ellipse(p3 + Vector2(-2, -2), Vector2(6, 4), Color("60703c"))


func _draw_hedge_rect(r: Rect2i) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	draw_texture_rect(_hedge_tex, Rect2(r.position * TILE, r.size * TILE), true)


# =====================================================================
# 操场（标准 400m 跑道 + 足球场）
# =====================================================================

func _draw_track() -> void:
	if _track.size.x <= 0 or _track.size.y <= 0:
		return
	var px := Rect2(_track.position * TILE, _track.size * TILE)
	var c := px.get_center()
	var half_w := px.size.x * 0.5
	var half_straight := maxf(0.0, (px.size.y - px.size.x) * 0.5)
	var outer_r := half_w
	var lane_w := 12.0
	var band := lane_w * 8.0
	var inner_r := outer_r - band

	draw_rect(px, Color("5f8f3d"))
	_fill_stadium(c, outer_r, half_straight, Color("b2544a"))
	_fill_stadium(c, inner_r, half_straight, Color("5f9a45"))
	for i in range(0, 9):
		var r := outer_r - lane_w * i
		_stroke_stadium(c, r, half_straight, Color(0.94, 0.92, 0.86, 0.55), 1.4)
	_stroke_stadium(c, outer_r, half_straight, Color(0.96, 0.94, 0.88, 0.85), 2.0)

	var pitch_w := inner_r * 1.62
	var pitch_h := (half_straight * 2.0) + inner_r * 1.55
	var pitch := Rect2(c - Vector2(pitch_w, pitch_h) * 0.5, Vector2(pitch_w, pitch_h))
	var white := Color(0.95, 0.96, 0.90, 0.85)
	draw_rect(pitch, white, false, 2.0)
	draw_line(Vector2(pitch.position.x, c.y), Vector2(pitch.end.x, c.y), white, 2.0)
	draw_arc(c, 62.0, 0, TAU, 40, white, 2.0)
	draw_circle(c, 3.0, white)
	for dir in [-1.0, 1.0]:
		var goal_y: float = c.y + float(dir) * pitch_h * 0.5
		var box_y: float = goal_y - float(dir) * 110.0
		var box := Rect2(c.x - 150, minf(goal_y, box_y), 300, absf(box_y - goal_y))
		draw_rect(box, white, false, 2.0)
		var small_y: float = goal_y - float(dir) * 46.0
		var small := Rect2(c.x - 70, minf(goal_y, small_y), 140, absf(small_y - goal_y))
		draw_rect(small, white, false, 2.0)
		draw_circle(Vector2(c.x, goal_y - float(dir) * 78.0), 3.0, white)
		draw_rect(Rect2(c.x - 46, minf(goal_y, goal_y + float(dir) * 8.0), 92, 8), Color(0.92, 0.92, 0.86, 0.9))
	draw_rect(Rect2(px.position - Vector2(6, 6), px.size + Vector2(12, 12)), Color(0.12, 0.20, 0.10, 0.12), false, 6.0)


func _stadium_points(c: Vector2, r: float, half_straight: float, steps: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var top := c - Vector2(0, half_straight)
	var bottom := c + Vector2(0, half_straight)
	pts.append(top + Vector2(r, 0))
	pts.append(bottom + Vector2(r, 0))
	for i in range(1, steps):
		var a := PI * float(i) / float(steps)
		pts.append(bottom + Vector2(cos(a) * r, sin(a) * r))
	pts.append(bottom + Vector2(-r, 0))
	pts.append(top + Vector2(-r, 0))
	for i in range(1, steps):
		var a := PI + PI * float(i) / float(steps)
		pts.append(top + Vector2(cos(a) * r, sin(a) * r))
	return pts


func _fill_stadium(c: Vector2, r: float, half_straight: float, color: Color) -> void:
	if r <= 2.0:
		return
	draw_colored_polygon(_stadium_points(c, r, half_straight), color)


func _stroke_stadium(c: Vector2, r: float, half_straight: float, color: Color, width: float) -> void:
	if r <= 2.0:
		return
	var pts := _stadium_points(c, r, half_straight)
	pts.append(pts[0])
	draw_polyline(pts, color, width)


# =====================================================================
# 篮球场 ×2（上下朝向）
# =====================================================================

func _draw_courts() -> void:
	for court: Rect2i in _courts:
		_draw_basketball(court)


func _draw_basketball(court: Rect2i) -> void:
	var px := Rect2(court.position * TILE, court.size * TILE)
	draw_rect(px.grow(5), Color("3f6b81"))
	draw_texture_rect(_court_tex, px, true)
	var white := Color(0.95, 0.96, 0.94, 0.90)
	var b := px.grow(-10)
	draw_rect(b, white, false, 2.0)
	var mid := b.get_center()
	# 上下朝向：中线横穿，中圈在中央
	draw_line(Vector2(b.position.x, mid.y), Vector2(b.end.x, mid.y), white, 2.0)
	draw_arc(mid, b.size.y * 0.13, 0, TAU, 24, white, 1.5)
	var key_w := b.size.x * 0.34
	var key_h := b.size.y * 0.17
	for dir in [-1.0, 1.0]:
		var base_y: float = b.position.y if dir < 0.0 else b.end.y
		var key_y: float = base_y - float(dir) * key_h
		draw_rect(Rect2(mid.x - key_w * 0.5, minf(base_y, key_y), key_w, key_h), white, false, 1.5)
		var ft_start := 0.0 if dir < 0.0 else PI
		draw_arc(Vector2(mid.x, key_y), key_w * 0.34, ft_start, ft_start + PI, 16, white, 1.5)
		var hoop := Vector2(mid.x, base_y - float(dir) * 12.0)
		draw_rect(Rect2(hoop.x - 9, hoop.y - 1, 18, 2), Color("e8e2d0"))
		draw_arc(hoop, 6.0, 0, TAU, 12, Color("e08a2a"), 2.0)
		# 三分线：以篮筐为圆心，只画朝场内的一段
		var r3 := b.size.y * 0.32
		var arc_start := 0.0 if dir < 0.0 else PI
		draw_arc(hoop, r3, arc_start, arc_start + PI, 22, white, 1.5)
	draw_rect(px.grow(-3), Color(0.93, 0.95, 0.94, 0.25), false, 1.0)


# =====================================================================
# 网球场
# =====================================================================

func _draw_tennis() -> void:
	if _tennis.size.x <= 0:
		return
	var px := Rect2(_tennis.position * TILE, _tennis.size * TILE)
	draw_rect(px, Color("3f7f8f"))
	draw_texture_rect(_court_tex, px.grow(-6), true, Color(0.78, 0.96, 0.82))
	var white := Color(0.95, 0.96, 0.94, 0.88)
	var b := px.grow(-14)
	draw_rect(b, white, false, 2.0)
	# 单打边线（上下朝向：左右各内收）
	var single := b.grow(-14)
	draw_line(Vector2(single.position.x, b.position.y), Vector2(single.position.x, b.end.y), white, 1.5)
	draw_line(Vector2(single.end.x, b.position.y), Vector2(single.end.x, b.end.y), white, 1.5)
	# 发球线
	var service_top := b.position.y + b.size.y * 0.26
	var service_bottom := b.end.y - b.size.y * 0.26
	draw_line(Vector2(single.position.x, service_top), Vector2(single.end.x, service_top), white, 1.5)
	draw_line(Vector2(single.position.x, service_bottom), Vector2(single.end.x, service_bottom), white, 1.5)
	# 中线
	draw_line(Vector2(b.get_center().x, service_top), Vector2(b.get_center().x, service_bottom), white, 1.5)
	# 球网
	var net_y := b.get_center().y
	draw_rect(Rect2(b.position.x - 6, net_y - 1, b.size.x + 12, 3), Color("2f3a3c"))
	draw_rect(Rect2(b.position.x - 6, net_y - 1, b.size.x + 12, 1), Color("e8e8e0"))
	for i in 6:
		draw_rect(Rect2(b.position.x - 6 + i * (b.size.x + 12) / 5.0, net_y - 5, 2, 6), Color("d8d8ce"))


# =====================================================================
# 小池塘 + 白色铁栅栏 + 垂柳
# =====================================================================

func _draw_pond() -> void:
	if _pond.size.x <= 0:
		return
	var px := Rect2(_pond.position * TILE, _pond.size * TILE)
	var c := px.get_center()
	# 岸边草地
	draw_rect(px, Color("66704a"))
	_ellipse(c, px.size * 0.46, Color("c9b083"))
	_ellipse(c, px.size * 0.43, Color("a8905f"))
	_ellipse(c, px.size * 0.40, Color("4f97c4"))
	_ellipse(c, px.size * 0.36, Color("5fa8d0"))
	_ellipse(c + Vector2(-18, -14), Vector2(26, 12), Color(0.70, 0.88, 0.96, 0.35))
	# 白色铁栅栏（小）
	var white := Color("e9e9e1")
	var x0 := px.position.x + 6
	var y0 := px.position.y + 6
	var x1 := px.end.x - 6
	var y1 := px.end.y - 6
	draw_line(Vector2(x0, y0), Vector2(x1, y0), white, 1.5)
	draw_line(Vector2(x0, y1), Vector2(x1, y1), white, 1.5)
	draw_line(Vector2(x0, y0), Vector2(x0, y1), white, 1.5)
	draw_line(Vector2(x1, y0), Vector2(x1, y1), white, 1.5)
	var step := 32.0
	var xx := x0
	while xx <= x1:
		draw_rect(Rect2(xx - 1, y0 - 4, 2, 8), white)
		draw_rect(Rect2(xx - 1, y1 - 4, 2, 8), white)
		xx += step
	var yy := y0
	while yy <= y1:
		draw_rect(Rect2(x0 - 4, yy - 1, 8, 2), white)
		draw_rect(Rect2(x1 - 4, yy - 1, 8, 2), white)
		yy += step


func _draw_straight_track() -> void:
	## 操场右侧的直跑道：4 条直道，带分道线和起终点线。
	if _straight_track.size.x <= 0:
		return
	var px := Rect2(_straight_track.position * TILE, _straight_track.size * TILE)
	draw_rect(px, Color("b45a4a"))
	draw_rect(Rect2(px.position, Vector2(px.size.x, 4)), Color("c46a56"))
	var lanes := 4
	var lw := px.size.x / float(lanes)
	for i in range(1, lanes):
		draw_line(Vector2(px.position.x + i * lw, px.position.y + 10), Vector2(px.position.x + i * lw, px.end.y - 10), Color(0.96, 0.94, 0.86, 0.85), 1.5)
	draw_rect(px, Color("e8e2d0"), false, 2.0)
	draw_rect(Rect2(px.position.x, px.position.y + 12, px.size.x, 6), Color("f2eee2"))
	draw_rect(Rect2(px.position.x, px.end.y - 18, px.size.x, 6), Color("f2eee2"))


func _draw_top_garden() -> void:
	## 右上角花园：凉亭 + 薰衣草花田 + 碎石小径（原实验楼位置）。
	if _top_garden.size.x <= 0:
		return
	var px := Rect2(_top_garden.position * TILE, _top_garden.size * TILE)
	draw_texture_rect(PixelArt.tile_texture("lawn"), px, true)
	# 碎石环形小径
	var c := px.get_center()
	_ellipse(c, Vector2(px.size.x * 0.30, px.size.y * 0.26), Color("b9b2a0"))
	_ellipse(c, Vector2(px.size.x * 0.28, px.size.y * 0.24), Color("cfc9bb"))
	# 薰衣草花田：四条带状
	for i in 4:
		var by := px.position.y + 24 + i * (px.size.y - 60) / 4.0
		draw_rect(Rect2(px.position.x + 20, by, px.size.x - 40, 14), Color("6a6a7a"))
		var fx := px.position.x + 24.0
		while fx < px.end.x - 24.0:
			draw_rect(Rect2(fx, by + 4, 2, 6), Color("5a7a4a"))
			_ellipse(Vector2(fx + 1, by + 3), Vector2(4, 5), Color("8f76c8"))
			_ellipse(Vector2(fx + 1, by + 2), Vector2(2, 3), Color("b49ae0"))
			fx += 11.0
	# 花境
	draw_rect(Rect2(px.position.x + 10, px.position.y + 10, px.size.x - 20, 4), Color("6b4a2c"))


func _draw_landscape() -> void:
	## 国际学院内院左下角的景观：假山 + 小湖 + 灌木，只占内院左下部分。
	if _landscape.size.x <= 0:
		return
	var px := Rect2(_landscape.position * TILE, _landscape.size * TILE)
	# 草坪与碎石铺边
	draw_rect(px, Color("6f7a48"))
	draw_rect(Rect2(px.position.x, px.end.y - 6, px.size.x, 6), Color("b9b2a0"))
	# 小湖
	var lake_c := Vector2(px.position.x + px.size.x * 0.62, px.position.y + px.size.y * 0.58)
	_ellipse(lake_c + Vector2(3, 4), Vector2(78, 44), Color(0.16, 0.12, 0.18, 0.18))
	_ellipse(lake_c, Vector2(76, 42), Color("4f97c4"))
	_ellipse(lake_c, Vector2(68, 36), Color("5fa8d0"))
	_ellipse(lake_c + Vector2(-14, -10), Vector2(24, 12), Color(0.72, 0.9, 0.98, 0.35))
	# 假山（左）
	var rock_c := Vector2(px.position.x + px.size.x * 0.18, px.position.y + px.size.y * 0.55)
	for i in 4:
		var off := Vector2(-30 + i * 20, 18 - i * 6)
		var r := 20 - i * 3
		_ellipse(rock_c + off + Vector2(3, 4), Vector2(r * 1.1, r * 0.6), Color(0.16, 0.12, 0.18, 0.20))
		_ellipse(rock_c + off, Vector2(r, r * 0.75), Color("8f8a80"))
		_ellipse(rock_c + off + Vector2(-4, -4), Vector2(r * 0.55, r * 0.4), Color("b2ada2"))
	# 灌木/草
	for i in 8:
		var p := Vector2(px.position.x + 10 + i * 26, px.end.y - 16 - (i % 3) * 8)
		_ellipse(p, Vector2(10, 6), Color("4f6a38"))
		_ellipse(p + Vector2(-2, -2), Vector2(7, 4), Color("65804a"))


# =====================================================================
# 建筑（全部 5 层）
# =====================================================================

func _draw_buildings() -> void:
	for b: Variant in _buildings:
		var building: Dictionary = b
		var parts: Array = building["parts"]
		var sorted := parts.duplicate()
		sorted.sort_custom(func(a, b2): return (a as Rect2i).position.y < (b2 as Rect2i).position.y)
		for part: Rect2i in sorted:
			_draw_part(part, building)


func _draw_glass_link(px: Rect2) -> void:
	## 两栋楼之间的玻璃连廊：屋顶是玻璃网格，边框是深色金属。
	draw_rect(Rect2(px.position + Vector2(4, 5), px.size), Color(0.06, 0.09, 0.08, 0.22))
	draw_rect(px, Color("5f7a88"))
	draw_rect(Rect2(px.position + Vector2(2, 2), px.size - Vector2(4, 4)), Color("a8c8d4"))
	draw_rect(Rect2(px.position + Vector2(2, 2), Vector2(px.size.x - 4, 3)), Color("d8ecf4"))
	for i in range(1, 4):
		draw_rect(Rect2(px.position.x + i * px.size.x / 4.0 - 1, px.position.y + 2, 2, px.size.y - 4), Color("6f8b98"))
	for j in range(1, 3):
		draw_rect(Rect2(px.position.x + 2, px.position.y + j * px.size.y / 3.0, px.size.x - 4, 1), Color("6f8b98"))
	draw_rect(px, Color("3f5a68"), false, 2.0)


func _draw_gym(px: Rect2, b: Dictionary) -> void:
	## 大体育馆：大矩形 + 内凹双坡屋顶（左右两端高，向中间下凹成倒三角），
	## 左右两馆（体育馆 / 游泳馆），各一个入口、一排天窗。
	var wall := Color(str(b.get("wall", "#d9d4c8")))
	var roof := Color(str(b.get("roof", "#7d8a92")))
	var glass := Color(str(b.get("window", "#6f93b0")))
	var wood := Color("8a6a44")
	var facade_h := 130.0
	var base_eave := px.end.y - facade_h
	var roof_top := px.position.y + 3.0
	var dip := 52.0
	var mid_x := px.get_center().x
	var x0 := px.position.x
	var x1 := px.end.x
	var half := px.size.x * 0.5
	# 1) 墙体先整块铺，屋顶多边形会把上沿切成 V 形
	draw_texture_rect(_wall_tex, Rect2(x0, base_eave, px.size.x, facade_h), true, wall)
	# 2) 左右两坡：靠中间低，形成内凹的倒三角
	var left_poly := PackedVector2Array([
		Vector2(x0, roof_top), Vector2(mid_x, roof_top),
		Vector2(mid_x, base_eave + dip), Vector2(x0, base_eave),
	])
	var right_poly := PackedVector2Array([
		Vector2(mid_x, roof_top), Vector2(x1, roof_top),
		Vector2(x1, base_eave), Vector2(mid_x, base_eave + dip),
	])
	draw_colored_polygon(left_poly, roof.lightened(0.12))
	draw_colored_polygon(right_poly, roof.darkened(0.16))
	# 3) 瓦面纹理与瓦垄（只落在完整屋顶带内）
	var shingle := PixelArt.tile_texture("roof_shingle")
	draw_texture_rect(shingle, Rect2(x0, roof_top, px.size.x, base_eave - roof_top), true, roof.lightened(0.02))
	var ry := roof_top + 10.0
	while ry < base_eave - 4.0:
		draw_rect(Rect2(x0, ry, px.size.x, 1), roof.darkened(0.24))
		ry += 14.0
	# 4) 两端向中间的渐变，强化“内凹”
	var bands := 12
	for i in bands:
		var t := float(i) / float(bands)
		var bw := half / float(bands)
		draw_rect(Rect2(x0 + half * t, roof_top, bw, base_eave - roof_top), Color(0, 0, 0, 0.22 * t))
		draw_rect(Rect2(mid_x + half * t, roof_top, bw, base_eave - roof_top), Color(0, 0, 0, 0.22 * (1.0 - t)))
	# 5) 谷底线：暗槽 + 左侧受光边
	draw_rect(Rect2(mid_x - 3, roof_top, 6, base_eave + dip - roof_top), roof.darkened(0.42))
	draw_rect(Rect2(mid_x - 4, roof_top, 1, base_eave + dip - roof_top), roof.lightened(0.22))
	# 6) V 形檐口 + 顶部水平檐
	draw_polyline(PackedVector2Array([Vector2(x0, base_eave), Vector2(mid_x, base_eave + dip), Vector2(x1, base_eave)]), roof.darkened(0.42), 3.0)
	draw_polyline(PackedVector2Array([Vector2(x0, base_eave - 2), Vector2(mid_x, base_eave + dip - 2), Vector2(x1, base_eave - 2)]), roof.lightened(0.20), 1.0)
	draw_rect(Rect2(x0, roof_top, px.size.x, 5), roof.darkened(0.34))
	# 7) 两端高点收头
	for side in [-1.0, 1.0]:
		var ex := x0 if side < 0.0 else x1 - 10.0
		draw_rect(Rect2(ex, roof_top, 10, base_eave - roof_top), roof.lightened(0.10) if side < 0.0 else roof.darkened(0.20))
		draw_rect(Rect2(ex, roof_top, 1, base_eave - roof_top), Color("241f1a", 0.45))
	# 8) 天窗：左右各一排
	for side in [-1.0, 1.0]:
		var cxx: float = mid_x + float(side) * px.size.x * 0.24
		var sky_y := roof_top + 34.0
		draw_rect(Rect2(cxx - 62, sky_y, 124, 30), Color("3f4b52"))
		draw_rect(Rect2(cxx - 60, sky_y + 2, 120, 26), Color("9fc4d4"))
		draw_rect(Rect2(cxx - 60, sky_y + 2, 120, 3), Color("cfe6ef"))
		var sx: float = cxx - 60.0
		while sx < cxx + 58.0:
			draw_rect(Rect2(sx, sky_y + 2, 1, 26), Color("6f8b98"))
			sx += 15.0
	# 9) 立面玻璃带（V 形最低点以下，避免被屋面盖住）
	var glass_top := base_eave + dip + 8.0
	for f in 2:
		var by := glass_top + f * 34.0
		draw_rect(Rect2(x0 + 22, by, px.size.x - 44, 20), wall.darkened(0.38))
		draw_rect(Rect2(x0 + 23, by + 1, px.size.x - 46, 18), glass)
		draw_rect(Rect2(x0 + 23, by + 1, px.size.x - 46, 2), glass.lightened(0.25))
		var gx := x0 + 23.0
		while gx < x1 - 23.0:
			draw_rect(Rect2(gx, by + 1, 1, 18), wall.darkened(0.42))
			gx += 26.0
	# 檐下阴影
	draw_rect(Rect2(x0, base_eave + dip, px.size.x, 3), Color(0.12, 0.10, 0.09, 0.20))
	# 10) 两个入口 + 雨棚 + 台阶
	for side in [-1.0, 1.0]:
		var ex2: float = mid_x + float(side) * px.size.x * 0.24
		_draw_entrance(Vector2(ex2, px.end.y), wall, glass)
		draw_rect(Rect2(ex2 - 28, glass_top - 12, 56, 5), wood)
		draw_rect(Rect2(ex2 - 28, glass_top - 12, 56, 1), wood.lightened(0.3))
	# 11) 描边 + 根部 AO
	draw_rect(Rect2(px.position + Vector2(0.5, 0.5), px.size - Vector2(1, 1)), Color("241f1a", 0.55), false, 1.5)
	draw_rect(Rect2(x0 - 3, px.end.y, px.size.x + 6, 6), Color(0.16, 0.12, 0.18, 0.24))
	draw_rect(Rect2(x0 - 3, px.end.y + 6, px.size.x + 6, 4), Color(0.16, 0.12, 0.18, 0.12))


func _draw_part(r: Rect2i, b: Dictionary) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var px := Rect2(r.position * TILE, r.size * TILE)
	var wall := Color(str(b.get("wall", "#e0d6c0")))
	var roof := Color(str(b.get("roof", "#9a9384")))
	var glass := Color(str(b.get("window", "#6f93b0")))
	var balcony := bool(b.get("balcony", false))
	var style := str(b.get("style", "slab"))

	if style == "glass":
		_draw_glass_link(px)
		return
	if style == "gym":
		_draw_gym(px, b)
		return

	var facade_h := clampf(px.size.y * 0.5, 78.0, 118.0)
	if style == "u3d":
		facade_h = clampf(px.size.y * 0.52, 62.0, 96.0)
	facade_h = minf(facade_h, px.size.y - 18.0)
	if px.size.y < 60.0:
		facade_h = px.size.y * 0.55
	var roof_h := px.size.y - facade_h
	var roof_rect := Rect2(px.position + Vector2(0, 2), Vector2(px.size.x, maxf(roof_h - 2.0, 4.0)))
	var face_rect := Rect2(px.position + Vector2(0, roof_h), Vector2(px.size.x, facade_h))

	draw_rect(Rect2(px.position + Vector2(7, 9), px.size), Color(0.06, 0.09, 0.06, 0.20))

	if style == "gable":
		draw_texture_rect(PixelArt.tile_texture("roof_shingle"), roof_rect, true, roof)
		var ridge_y := roof_rect.position.y + roof_rect.size.y * 0.42
		draw_rect(Rect2(roof_rect.position.x, ridge_y - 1, roof_rect.size.x, 3), roof.lightened(0.30))
		# 四坡明暗，避免变成一块红色平板
		draw_rect(Rect2(roof_rect.position.x, roof_rect.position.y, roof_rect.size.x, 6), roof.lightened(0.12))
		draw_rect(Rect2(roof_rect.position.x, roof_rect.end.y - 8, roof_rect.size.x, 8), roof.darkened(0.24))
		draw_rect(Rect2(roof_rect.position.x, roof_rect.position.y, 8, roof_rect.size.y), roof.lightened(0.06))
		draw_rect(Rect2(roof_rect.end.x - 8, roof_rect.position.y, 8, roof_rect.size.y), roof.darkened(0.18))
	elif style == "u3d":
		# 三角坡顶：屋脊在中间，两端三角山墙
		var ridge_y2 := roof_rect.position.y + roof_rect.size.y * 0.46
		var sh2 := PixelArt.tile_texture("roof_shingle")
		draw_texture_rect(sh2, Rect2(roof_rect.position, Vector2(roof_rect.size.x, ridge_y2 - roof_rect.position.y)), true, roof.darkened(0.20))
		draw_texture_rect(sh2, Rect2(Vector2(roof_rect.position.x, ridge_y2), Vector2(roof_rect.size.x, roof_rect.end.y - ridge_y2)), true, roof.lightened(0.06))
		draw_rect(Rect2(roof_rect.position.x, ridge_y2 - 2, roof_rect.size.x, 4), roof.lightened(0.32))
		for side in [-1.0, 1.0]:
			var ex := roof_rect.position.x if side < 0.0 else roof_rect.end.x - 16.0
			var tri := PackedVector2Array([
				Vector2(ex, roof_rect.position.y + 2),
				Vector2(ex, roof_rect.end.y - 2),
				Vector2(ex + 16.0 * (1.0 if side < 0.0 else -1.0), ridge_y2),
			])
			draw_colored_polygon(tri, wall.lightened(0.04))
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color("241f1a", 0.45), 1.0)
	else:
		draw_texture_rect(_roof_tex, roof_rect, true, roof)
		draw_rect(Rect2(roof_rect.position, Vector2(roof_rect.size.x, 3)), roof.lightened(0.18))
	draw_rect(roof_rect, roof.darkened(0.28), false, 2.0)
	_draw_roof_details(roof_rect, r, roof)

	draw_rect(Rect2(px.position.x - 2, roof_rect.end.y, px.size.x + 4, 4), wall.darkened(0.22))
	draw_rect(Rect2(px.position.x - 2, roof_rect.end.y + 3, px.size.x + 4, 1), wall.lightened(0.25))
	draw_rect(Rect2(px.position.x, roof_rect.end.y + 4, px.size.x, 2), Color(0.08, 0.09, 0.07, 0.18))

	var wall_tex := _wall_tex
	if style == "brick":
		wall_tex = PixelArt.tile_texture("wall_brick")
	draw_texture_rect(wall_tex, face_rect, true, wall)
	draw_rect(face_rect, wall.darkened(0.10), false, 1.0)

	var floor_h := facade_h / float(FLOORS)
	for f in range(1, FLOORS):
		var fy := face_rect.position.y + f * floor_h
		draw_rect(Rect2(face_rect.position.x, fy, face_rect.size.x, 1), wall.darkened(0.16))

	var wide := int(face_rect.size.x / 24.0)
	var margin := 12.0
	var step := (face_rect.size.x - margin * 2.0) / maxf(float(wide), 1.0)
	# 竖向壁柱：打断长立面的单调
	if face_rect.size.x > 420.0:
		var bay := 0
		while true:
			var bx := face_rect.position.x + margin + bay * 96.0 - 3.0
			if bx > face_rect.end.x - margin - 4.0:
				break
			draw_rect(Rect2(bx, face_rect.position.y, 6, facade_h - 3.0), wall.darkened(0.12))
			draw_rect(Rect2(bx, face_rect.position.y, 1, facade_h - 3.0), wall.lightened(0.16))
			bay += 1
	if style == "modern":
		# 现代风格：横向带窗 + 白色横条
		for f in FLOORS:
			var band_y := face_rect.position.y + f * floor_h + floor_h * 0.24
			var band_h := clampf(floor_h * 0.46, 8.0, 16.0)
			draw_rect(Rect2(face_rect.position.x + 10, band_y, face_rect.size.x - 20, band_h), wall.darkened(0.28))
			draw_rect(Rect2(face_rect.position.x + 11, band_y + 1, face_rect.size.x - 22, band_h - 2), glass)
			var mx := face_rect.position.x + 10
			while mx < face_rect.end.x - 10:
				draw_rect(Rect2(mx, band_y, 2, band_h), wall.darkened(0.34))
				mx += 30
		_draw_entrance(Vector2(face_rect.get_center().x, face_rect.end.y), wall, glass)
	else:
		for f in range(FLOORS):
			var fy := face_rect.position.y + f * floor_h + 4.0
			var wh := clampf(floor_h - 9.0, 8.0, 16.0)
			var ground := f == FLOORS - 1
			for i in wide:
				var wx := face_rect.position.x + margin + i * step + (step - 12.0) * 0.5
				if ground:
					if wide >= 12 and (i == int(wide * 0.5) or i == int(wide * 0.5) - 1):
						_draw_entrance(Vector2(wx - 4.0, face_rect.end.y), wall, glass)
						continue
					_draw_window(Vector2(wx, fy), glass, wall, wh + 4.0, 12.0, balcony)
				else:
					_draw_window(Vector2(wx, fy), glass, wall, wh, 12.0, balcony)

	draw_rect(Rect2(face_rect.position.x, face_rect.end.y - 4, face_rect.size.x, 4), wall.darkened(0.26))
	draw_rect(Rect2(face_rect.position.x, face_rect.end.y - 1, face_rect.size.x, 1), Color(0.10, 0.09, 0.07, 0.30))

	# 东侧窄立面：给体块一个厚度方向
	if px.size.x > 46.0:
		var sw := 6.0
		var side := Rect2(px.end.x - sw, roof_rect.position.y + 3, sw, px.size.y - 3)
		draw_rect(side, wall.darkened(0.38))
		draw_rect(Rect2(side.position.x, side.position.y, 1, side.size.y), wall.darkened(0.16))
		draw_rect(Rect2(side.position.x, side.position.y, sw, 1), Color(0.12, 0.10, 0.08, 0.35))
	# 檐口下的投影
	draw_rect(Rect2(px.position.x, roof_rect.end.y + 4, px.size.x, 3), Color(0.12, 0.09, 0.07, 0.22))
	# 整体描边
	draw_rect(Rect2(px.position + Vector2(0.5, 0.5), px.size - Vector2(1, 1)), Color("241f1a", 0.55), false, 1.5)
	# 建筑根部的环境光遮蔽
	draw_rect(Rect2(px.position.x - 3, px.end.y, px.size.x + 6, 6), Color(0.16, 0.12, 0.18, 0.24))
	draw_rect(Rect2(px.position.x - 3, px.end.y + 6, px.size.x + 6, 4), Color(0.16, 0.12, 0.18, 0.12))

	# 侧面明暗，做出体量
	draw_rect(Rect2(px.position.x, px.position.y + 2, 4, facade_h), Color(0, 0, 0, 0.14))
	draw_rect(Rect2(px.end.x - 3, px.position.y + 2, 3, facade_h), Color(1, 1, 1, 0.08))
	if style == "u3d":
		# 米黄色楼的石质基座，显得更高更稳
		draw_rect(Rect2(face_rect.position.x - 2, face_rect.end.y - 4, face_rect.size.x + 4, 8), Color("b8b2a2"))
		draw_rect(Rect2(face_rect.position.x - 2, face_rect.end.y - 4, face_rect.size.x + 4, 1), Color("d9d2c0"))
		draw_rect(Rect2(face_rect.position.x - 2, face_rect.end.y + 4, face_rect.size.x + 4, 2), Color(0.10, 0.09, 0.07, 0.25))

	# 门前铺装小广场
	if px.size.x > 200.0:
		draw_texture_rect(_paving_tex, Rect2(px.position.x + px.size.x * 0.5 - 76, px.end.y - 2, 152, 58), true)
		draw_rect(Rect2(px.position.x + px.size.x * 0.5 - 76, px.end.y - 2, 152, 2), Color("e9e3d2"))


func _draw_window(pos: Vector2, glass: Color, wall: Color, h: float, w: float, balcony: bool) -> void:
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), wall.darkened(0.42))
	draw_rect(Rect2(pos, Vector2(w, h)), glass.darkened(0.30))
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w - 2, h - 2)), glass)
	# 窗洞上沿的内阴影 + 下沿的受光，让窗“凹”进去
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w - 2, 1)), glass.darkened(0.55))
	draw_rect(Rect2(pos + Vector2(1, h - 1), Vector2(w - 2, 1)), glass.lightened(0.30))
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w * 0.45, h * 0.4)), glass.lightened(0.20))
	draw_rect(Rect2(pos + Vector2(w * 0.5 - 0.5, 1), Vector2(1, h - 2)), wall.darkened(0.36))
	draw_rect(Rect2(pos + Vector2(1, h * 0.5 - 0.5), Vector2(w - 2, 1)), wall.darkened(0.36))
	draw_rect(Rect2(pos + Vector2(-2, h), Vector2(w + 4, 2)), wall.lightened(0.26))
	draw_rect(Rect2(pos + Vector2(-2, h + 2), Vector2(w + 4, 1)), wall.darkened(0.30))
	if balcony:
		draw_rect(Rect2(pos + Vector2(-2, h + 2), Vector2(w + 4, 3)), Color("8f8a7c"))
		draw_rect(Rect2(pos + Vector2(-2, h + 2), Vector2(w + 4, 1)), Color("c9c2b0"))
		for i in 3:
			draw_rect(Rect2(pos + Vector2(1 + i * 4, h + 2), Vector2(1, 3)), Color("6f6a5e"))


func _draw_entrance(pos: Vector2, wall: Color, glass: Color) -> void:
	draw_rect(Rect2(pos + Vector2(-18, 0), Vector2(36, 4)), Color("c9c2b0"))
	draw_rect(Rect2(pos + Vector2(-14, -2), Vector2(28, 3)), Color("d9d2c0"))
	# 三级台阶：每级 4px，带受光面和投影，做出高差
	for i in 3:
		var sw := 38.0 + i * 10.0
		var sy := pos.y + 2 + i * 5.0
		draw_rect(Rect2(pos.x - sw * 0.5, sy, sw, 5), Color("c4beb0"))
		draw_rect(Rect2(pos.x - sw * 0.5, sy, sw, 1), Color("e6e0d2"))
		draw_rect(Rect2(pos.x - sw * 0.5, sy + 4, sw, 1), Color(0.14, 0.11, 0.10, 0.45))
	draw_rect(Rect2(pos + Vector2(-13, -34), Vector2(26, 35)), Color("5c5348"))
	draw_rect(Rect2(pos + Vector2(-11, -32), Vector2(22, 32)), Color("7d97a8"))
	draw_rect(Rect2(pos + Vector2(-10, -31), Vector2(20, 30)), Color("8fb4c8"))
	draw_rect(Rect2(pos + Vector2(-1, -31), Vector2(2, 30)), Color("6a8494"))
	# 雨棚 + 棚下阴影
	draw_rect(Rect2(pos + Vector2(-17, -40), Vector2(34, 5)), Color("8b8476"))
	draw_rect(Rect2(pos + Vector2(-17, -40), Vector2(34, 1)), Color("b8b2a2"))
	draw_rect(Rect2(pos + Vector2(-16, -35), Vector2(32, 2)), Color(0.10, 0.10, 0.08, 0.32))


func _draw_roof_details(roof_rect: Rect2, r: Rect2i, roof: Color) -> void:
	if roof_rect.size.x < 130.0 or roof_rect.size.y < 54.0:
		return
	var h := absi((r.position.x * 7349) ^ (r.position.y * 1571))
	var bw := 74.0
	var bh := 54.0
	var bx := roof_rect.position.x + 14.0 + float(h % maxi(1, int(maxf(roof_rect.size.x - bw - 28.0, 1.0))))
	var by := roof_rect.position.y + 12.0 + float((h / 7) % maxi(1, int(maxf(roof_rect.size.y - bh - 24.0, 1.0))))
	var bulk := Rect2(bx, by, bw, bh)
	draw_rect(Rect2(bulk.position + Vector2(3, 4), bulk.size), Color(0.10, 0.12, 0.10, 0.22))
	draw_rect(bulk, roof.darkened(0.16))
	draw_rect(Rect2(bulk.position, Vector2(bulk.size.x, 4)), roof.lightened(0.18))
	draw_rect(bulk, roof.darkened(0.34), false, 2.0)
	draw_rect(Rect2(bulk.position.x + 10, bulk.end.y - 22, 16, 22), Color("5c5348"))
	draw_rect(Rect2(bulk.position.x + 12, bulk.end.y - 20, 12, 20), Color("7d97a8"))
	for i in 2:
		var ax := roof_rect.position.x + 12.0 + fmod(float(h + i * 97), maxf(roof_rect.size.x - 46.0, 1.0))
		var ay := roof_rect.position.y + 10.0 + fmod(float(h / 3 + i * 53), maxf(roof_rect.size.y - 40.0, 1.0))
		var ac := Rect2(ax, ay, 32, 22)
		draw_rect(Rect2(ac.position + Vector2(2, 3), ac.size), Color(0.10, 0.12, 0.10, 0.20))
		draw_rect(ac, roof.darkened(0.26))
		draw_rect(Rect2(ac.position, Vector2(ac.size.x, 2)), roof.lightened(0.10))
		draw_circle(ac.get_center(), 7.0, roof.darkened(0.42))
		draw_circle(ac.get_center(), 3.0, roof.darkened(0.55))
	if roof_rect.size.x > 220.0:
		var sx := roof_rect.position.x + fmod(float(h / 11), maxf(roof_rect.size.x - 120.0, 1.0)) + 40.0
		var sy := roof_rect.position.y + fmod(float(h / 5), maxf(roof_rect.size.y - 60.0, 1.0)) + 24.0
		var sky := Rect2(sx, sy, 64, 26)
		draw_rect(sky, Color("5c5348"))
		draw_rect(Rect2(sky.position + Vector2(3, 3), sky.size - Vector2(6, 6)), Color("6a93a8"))
		draw_rect(Rect2(sky.position + Vector2(3, 3), Vector2(26, 8)), Color("9fc4d4"))


# =====================================================================
# 围墙与校门
# =====================================================================

func _draw_boundary() -> void:
	var x0 := _campus.position.x
	var y0 := _campus.position.y
	var x1 := _campus.end.x
	var y1 := _campus.end.y
	for y in range(y0, y1):
		for x in range(x0, x1):
			var edge := x < x0 + 2 or x >= x1 - 2 or y < y0 + 2 or y >= y1 - 2
			if not edge:
				continue
			if _in_gate(Vector2i(x, y)):
				continue
			draw_texture_rect_region(PixelArt.atlas(), Rect2(x * TILE, y * TILE, TILE, TILE), _tile_rects["hedge"])
			if y == y0 + 1 or y == y1 - 1:
				draw_rect(Rect2(x * TILE, y * TILE + TILE - 3, TILE, 3), Color(0.10, 0.16, 0.08, 0.28))
	var gate := _gates[0] if not _gates.is_empty() else Rect2i(186, 151, 15, 5)
	var gate_y := gate.position.y * TILE
	var left_x := (gate.position.x - 4) * TILE
	var right_x := (gate.end.x + 1) * TILE
	# 校门：石柱 + 柱帽 + 门牌横梁
	for px_x in [left_x, right_x]:
		draw_rect(Rect2(px_x + 4, gate_y + 8, 26, 52), Color(0.10, 0.12, 0.10, 0.25))
		draw_rect(Rect2(px_x, gate_y + 46, 34, 14), Color("9a9384"))
		draw_rect(Rect2(px_x, gate_y + 46, 34, 2), Color("c9c2b0"))
		draw_rect(Rect2(px_x + 3, gate_y + 10, 28, 38), Color("bdb6a6"))
		draw_rect(Rect2(px_x + 3, gate_y + 10, 2, 38), Color("d9d2c0"))
		draw_rect(Rect2(px_x + 3, gate_y + 10, 28, 2), Color("d9d2c0"))
		draw_rect(Rect2(px_x - 2, gate_y + 4, 38, 8), Color("8f897b"))
		draw_rect(Rect2(px_x - 2, gate_y + 4, 38, 2), Color("c9c2b0"))
		draw_rect(Rect2(px_x + 12, gate_y - 6, 14, 12), Color("3f3a33"))
		draw_rect(Rect2(px_x + 14, gate_y - 4, 10, 8), Color("f6d27a"))
	# 门牌横梁
	draw_rect(Rect2(left_x + 6, gate_y - 22, right_x + 28 - left_x, 14), Color("5c5348"))
	draw_rect(Rect2(left_x + 8, gate_y - 20, right_x + 24 - left_x, 10), Color("8a6a44"))
	draw_rect(Rect2(left_x + 8, gate_y - 20, right_x + 24 - left_x, 2), Color("b08a5a"))
	# 入口地面
	var gx := gate.position.x * TILE
	var gw := gate.size.x * TILE
	draw_texture_rect(_paving_tex, Rect2(gx - 8, gate_y, gw + 16, gate.size.y * TILE), true)
	draw_rect(Rect2(gx - 8, gate_y, gw + 16, 2), Color("d9d2c0"))


# =====================================================================
# 树、道具、人物
# =====================================================================

func _spawn_decor() -> void:
	_spawn_trees()
	_spawn_groves()
	_spawn_forest_ring()
	_spawn_props()
	_spawn_lamps()
	_spawn_npcs()
	queue_redraw()


func _place_tree(main: Node, cell: Vector2i, kind: String, ignore_block: bool = false) -> void:
	if _path_cells.has(cell):
		return
	if not ignore_block and not _free(cell):
		return
	var tex := PixelArt.tree(kind, (cell.x * 7 + cell.y * 13) % 3 if kind != "pine" else 0)
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.position = Vector2(cell.x * TILE + 8, cell.y * TILE + 15)
	sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 4)
	sprite.name = "Tree"
	sprite.add_to_group("trees")
	if kind == "willow":
		sprite.scale = Vector2(1.45, 1.45)
		sprite.offset = Vector2(-tex.get_width() / 2.0, 4.0 / 1.45 - tex.get_height())
	main.add_child(sprite)
	_tree_shadows.append([sprite.position, float(tex.get_width())])
	_add_solid(Rect2(cell.x * TILE + 5, cell.y * TILE + 10, 6, 5))


func _spawn_trees() -> void:
	var main := get_parent()
	for row: Variant in _layout.get("trees", []):
		var r: Dictionary = row
		var kind := str(r.get("kind", "oak"))
		for j in int(r.get("rows", 1)):
			for i in int(r.get("cols", 1)):
				var cell := Vector2i(int(r["x"]) + i * int(r["sx"]), int(r["y"]) + j * int(r["sy"]))
				if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y:
					continue
				_place_tree(main, cell, kind)


func _spawn_groves() -> void:
	## 花林：在花园里按“最小间距 + 随机抖动”撒树，避开步道，散而不乱。
	var main := get_parent()
	for g: Variant in _layout.get("groves", []):
		var grove: Dictionary = g
		var r: Array = grove["rect"]
		var rect := Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))
		var kinds: Array = grove.get("kinds", ["oak"])
		var count := int(grove.get("count", 12))
		var rng := RandomNumberGenerator.new()
		rng.seed = rect.position.x * 7919 + rect.position.y * 104729 + rect.size.x * 31
		var cells: Array[Vector2i] = []
		var tries := 0
		while cells.size() < count and tries < count * 60:
			tries += 1
			var cell := Vector2i(
				rng.randi_range(rect.position.x + 1, rect.end.x - 2),
				rng.randi_range(rect.position.y + 1, rect.end.y - 2)
			)
			var pos := Vector2(cell.x * TILE + 8, cell.y * TILE + 15)
			if _on_garden_walk(pos):
				continue
			if not _free(cell):
				continue
			var bad := false
			for c: Vector2i in cells:
				if absi(c.x - cell.x) + absi(c.y - cell.y) < 5:
					bad = true
					break
			if bad:
				continue
			cells.append(cell)
			_place_tree(main, cell, str(kinds[rng.randi_range(0, kinds.size() - 1)]))


func _spawn_forest_ring() -> void:
	var main := get_parent()
	for layer in 2:
		var inset := 2 + layer * 3
		var step := 4
		for x in range(inset, _size.x - inset, step):
			_place_tree(main, Vector2i(x, inset), "pine" if layer % 2 == 0 else "oak", true)
			_place_tree(main, Vector2i(x, _size.y - 1 - inset), "oak", true)
		for y in range(inset + step, _size.y - inset - step, step):
			_place_tree(main, Vector2i(inset, y), "oak", true)
			_place_tree(main, Vector2i(_size.x - 1 - inset, y), "pine", true)


func _spawn_props() -> void:
	var main := get_parent()
	for p: Variant in _layout.get("props", []):
		var prop: Dictionary = p
		var kind := str(prop.get("type", "sign"))
		var cell := Vector2i(int(prop["x"]), int(prop["y"]))
		var tex := PixelArt.prop(kind)
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.position = Vector2(cell.x * TILE + 8, cell.y * TILE + 16)
		sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		sprite.name = "Prop_%s" % kind
		main.add_child(sprite)
		_props.append({
			"type": kind,
			"cell": cell,
			"pos": sprite.position,
			"text": str(prop.get("text", "")),
		})
		match kind:
			"fountain":
				_add_solid(Rect2(cell.x * TILE - 30, cell.y * TILE - 14, 60, 26))
			"flagpole":
				_add_solid(Rect2(cell.x * TILE - 4, cell.y * TILE - 4, 8, 8))
			"bike_rack":
				_add_solid(Rect2(cell.x * TILE - 14, cell.y * TILE - 4, 28, 8))
			"pavilion":
				_add_solid(Rect2(cell.x * TILE - 34, cell.y * TILE - 12, 68, 22))
			"bench":
				_add_solid(Rect2(cell.x * TILE - 10, cell.y * TILE - 2, 20, 8))
			"bin":
				_add_solid(Rect2(cell.x * TILE - 10, cell.y * TILE - 6, 20, 12))
			"planter":
				_add_solid(Rect2(cell.x * TILE - 9, cell.y * TILE - 4, 18, 8))
			"sign":
				_add_solid(Rect2(cell.x * TILE - 4, cell.y * TILE - 4, 8, 8))
			"boat":
				_add_solid(Rect2(cell.x * TILE - 78, cell.y * TILE - 16, 156, 26))
			"bell":
				_add_solid(Rect2(cell.x * TILE - 24, cell.y * TILE - 14, 48, 20))
			"stele":
				_add_solid(Rect2(cell.x * TILE - 66, cell.y * TILE - 10, 132, 16))


func _spawn_lamps() -> void:
	var main := get_parent()
	for path: Rect2i in _paths:
		var horizontal := path.size.x >= path.size.y
		var count := int(path.size.x / 11) if horizontal else int(path.size.y / 11)
		for i in range(1, count):
			var cell: Vector2i
			if horizontal:
				cell = Vector2i(path.position.x + i * 11, path.position.y - 1)
			else:
				cell = Vector2i(path.position.x - 1, path.position.y + i * 11)
			if not _free(cell):
				continue
			var tex := PixelArt.prop("lamp")
			var sprite := Sprite2D.new()
			sprite.texture = tex
			sprite.centered = false
			sprite.position = Vector2(cell.x * TILE + 8, cell.y * TILE + 14)
			sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
			main.add_child(sprite)


func _spawn_npcs() -> void:
	var routes := [
		[Vector2(60, 23), Vector2(200, 23), Vector2(200, 55), Vector2(90, 55)],
		[Vector2(120, 24), Vector2(120, 148), Vector2(160, 148), Vector2(160, 24)],
		[Vector2(210, 65), Vector2(210, 145), Vector2(240, 145), Vector2(240, 65)],
		[Vector2(300, 62), Vector2(300, 95), Vector2(340, 95), Vector2(340, 62)],
		[Vector2(60, 130), Vector2(160, 130), Vector2(160, 148), Vector2(60, 148)],
		[Vector2(180, 24), Vector2(360, 24), Vector2(360, 60), Vector2(180, 60)],
	]
	var shirts := [Color("c05a4a"), Color("4a9a6a"), Color("d9a13a"), Color("6a5aa8"), Color("d97a9a"), Color("3a8fb5")]
	var hairs := [Color("3a2a1e"), Color("5a3a23"), Color("2a2a2a"), Color("6b4423"), Color("4a3020"), Color("3a2a1e")]
	var main := get_parent()
	for i in routes.size():
		var npc = preload("res://scripts/world/npc_student.gd").new()
		npc.route = routes[i]
		npc.shirt = shirts[i % shirts.size()]
		npc.hair = hairs[i % hairs.size()]
		var first: Vector2 = routes[i][0]
		npc.position = first * TILE
		main.add_child(npc)


# =====================================================================
# 碰撞
# =====================================================================

func _build_collision() -> void:
	_solids = StaticBody2D.new()
	_solids.name = "Solids"
	add_child(_solids)
	for b: Variant in _buildings:
		for part: Rect2i in (b as Dictionary)["parts"]:
			_add_solid(Rect2(part.position * TILE, part.size * TILE))
	_add_edge_solids(true, _campus.position.y, _campus.position.x, _campus.end.x)
	_add_edge_solids(true, _campus.end.y - 2, _campus.position.x, _campus.end.x)
	_add_edge_solids(false, _campus.position.x, _campus.position.y, _campus.end.y)
	_add_edge_solids(false, _campus.end.x - 2, _campus.position.y, _campus.end.y)
	if _pond.size.x > 0:
		var pr := Rect2(_pond.position * TILE, _pond.size * TILE)
		_add_solid(Rect2(pr.position.x, pr.position.y, pr.size.x, 6))
		_add_solid(Rect2(pr.position.x, pr.end.y - 6, pr.size.x, 6))
		_add_solid(Rect2(pr.position.x, pr.position.y, 6, pr.size.y))
		_add_solid(Rect2(pr.end.x - 6, pr.position.y, 6, pr.size.y))
	_add_solid(Rect2(-16, -16, _size.x * TILE + 32, 16))
	_add_solid(Rect2(-16, _size.y * TILE, _size.x * TILE + 32, 16))
	_add_solid(Rect2(-16, 0, 16, _size.y * TILE))
	_add_solid(Rect2(_size.x * TILE, 0, 16, _size.y * TILE))


func _add_edge_solids(horizontal: bool, fixed: int, from: int, to: int) -> void:
	var runs: Array[Vector2i] = []
	var start := -1
	for v in range(from, to):
		var cell := Vector2i(v, fixed) if horizontal else Vector2i(fixed, v)
		var other := cell + (Vector2i(0, 1) if horizontal else Vector2i(1, 0))
		if _in_gate(cell) or _in_gate(other):
			if start >= 0:
				runs.append(Vector2i(start, v))
				start = -1
		elif start < 0:
			start = v
	if start >= 0:
		runs.append(Vector2i(start, to))
	for run: Vector2i in runs:
		if run.y <= run.x:
			continue
		if horizontal:
			_add_solid(Rect2(run.x * TILE, fixed * TILE, (run.y - run.x) * TILE, 32))
		else:
			_add_solid(Rect2(fixed * TILE, run.x * TILE, 32, (run.y - run.x) * TILE))


func _add_solid(rect: Rect2) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0:
		return
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size * 0.5
	_solids.add_child(shape)


# =====================================================================
# 标签与交互
# =====================================================================

func _build_labels() -> void:
	var holder := Node2D.new()
	holder.name = "Labels"
	holder.z_as_relative = false
	holder.z_index = 60
	add_child(holder)
	for b: Variant in _buildings:
		var building: Dictionary = b
		var parts: Array = building["parts"]
		if parts.is_empty():
			continue
		var min_y := 99999
		var cx := 0
		for part: Rect2i in parts:
			min_y = mini(min_y, part.position.y)
			cx += int(part.get_center().x)
		cx = cx / parts.size()
		var top_y := min_y * TILE - 26.0
		_add_label(holder, str(building.get("name", "")), float(cx) * TILE, top_y)
		# 大体育馆左右两馆的室内分区标注
		for room: Variant in building.get("rooms", []):
			var room_d: Dictionary = room
			var rr: Array = room_d["rect"]
			var rc := Rect2i(int(rr[0]), int(rr[1]), int(rr[2]), int(rr[3]))
			_add_room_label(holder, str(room_d.get("name", "")), rc.get_center().x * TILE, rc.position.y * TILE + 6.0)
	_add_label(holder, "400m 操场", _track.get_center().x * TILE, _track.position.y * TILE - 24.0)
	if not _courts.is_empty():
		_add_label(holder, "篮球场", _courts[0].get_center().x * TILE, _courts[0].position.y * TILE - 22.0)
	if _tennis.size.x > 0:
		_add_label(holder, "网球场", _tennis.get_center().x * TILE, _tennis.position.y * TILE - 22.0)
	if _pond.size.x > 0:
		_add_label(holder, "小池塘", _pond.get_center().x * TILE, _pond.position.y * TILE - 22.0)
	_add_label(holder, "中心花园", _garden.get_center().x * TILE, _garden.position.y * TILE - 22.0)
	if not _gates.is_empty():
		var gate: Rect2i = _gates[0]
		_add_static_label(holder, "CAMPUS HOLLOW", (gate.position.x + gate.size.x * 0.5) * TILE, gate.position.y * TILE - 27.0)
	# 校训石上的字（跟着石碑走）
	for p: Variant in _layout.get("props", []):
		var prop: Dictionary = p
		if str(prop.get("type", "")) == "stele":
			_add_motto_label(holder, "守正出新   止于至善", int(prop["x"]) * TILE + 8, int(prop["y"]) * TILE - 24)


func _add_static_label(holder: Node2D, text: String, center_x: float, top_y: float) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.96, 0.84, 0.50))
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.05))
	label.add_theme_constant_override("outline_size", 5)
	label.size = Vector2(300, 18)
	label.position = Vector2(center_x - 150.0, top_y)
	holder.add_child(label)


func _add_room_label(holder: Node2D, text: String, center_x: float, top_y: float) -> void:
	if text.is_empty():
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.94, 0.90, 0.78))
	label.add_theme_color_override("font_outline_color", Color(0.10, 0.08, 0.07))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(center_x - 60.0, top_y)
	label.size = Vector2(120, 16)
	label.modulate.a = 0.0
	holder.add_child(label)
	_labels.append({"label": label, "pos": Vector2(center_x, top_y + 8.0)})


func _add_motto_label(holder: Node2D, text: String, center_x: float, top_y: float) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.12, 0.10, 0.08))
	label.size = Vector2(240, 16)
	label.position = Vector2(center_x - 120.0, top_y)
	holder.add_child(label)


func _add_label(holder: Node2D, text: String, center_x: float, top_y: float) -> void:
	if text == "":
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1, 0.98, 0.90))
	label.add_theme_color_override("font_outline_color", Color(0.09, 0.10, 0.07))
	label.add_theme_constant_override("outline_size", 4)
	label.size = Vector2(160, 16)
	label.position = Vector2(center_x - 80.0, top_y - 8.0)
	label.modulate.a = 0.0
	holder.add_child(label)
	_labels.append({"label": label, "pos": Vector2(center_x, top_y + 8.0)})


func zone_name(world_pos: Vector2) -> String:
	for b: Variant in _buildings:
		var building: Dictionary = b
		for part: Rect2i in building["parts"]:
			if Rect2(part.position * TILE, part.size * TILE).grow(10).has_point(world_pos):
				return str(building.get("name", "教学楼"))
	if _track.size.x > 0 and Rect2(_track.position * TILE, _track.size * TILE).has_point(world_pos):
		return "400m 操场"
	for c: Rect2i in _courts:
		if Rect2(c.position * TILE, c.size * TILE).has_point(world_pos):
			return "篮球场"
	if _tennis.size.x > 0 and Rect2(_tennis.position * TILE, _tennis.size * TILE).has_point(world_pos):
		return "网球场"
	if _pond.size.x > 0 and Rect2(_pond.position * TILE, _pond.size * TILE).has_point(world_pos):
		return "小池塘"
	if _garden.size.x > 0 and Rect2(_garden.position * TILE, _garden.size * TILE).has_point(world_pos):
		return "中心花园"
	return "校园"


func try_interact(world_pos: Vector2) -> String:
	var best: Dictionary = {}
	var best_dist := 52.0
	for prop: Dictionary in _props:
		var d: float = world_pos.distance_to(prop["pos"] + Vector2(0, -8))
		if d < best_dist:
			best_dist = d
			best = prop
	if not best.is_empty():
		match str(best["type"]):
			"sign":
				return str(best.get("text", "校园平面图"))
			"fountain":
				return "喷泉在阳光里闪着细碎的光。"
			"bench":
				return "坐下歇了会儿，风从林荫道吹过来。"
			"bike_rack":
				return "自行车整整齐齐地停成一排。"
			_:
				return "校园里很安静。"
	var cell := Vector2i(floori(world_pos.x / TILE), floori(world_pos.y / TILE))
	for b: Variant in _buildings:
		var building: Dictionary = b
		for part: Rect2i in building["parts"]:
			var expanded := Rect2(part.position * TILE, part.size * TILE)
			if expanded.grow(-4).has_point(world_pos):
				return "%s · 五层。现在是上课时间。" % str(building.get("name", "教学楼"))
	return ""


func _ellipse(c: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * float(i) / 40.0
		pts.append(c + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	draw_colored_polygon(pts, color)

extends Node2D
## One physical building part, sorted at its southern foundation.
const TILE := 16
const FLOORS := 5
var part := Rect2i()
var building: Dictionary = {}
var _wall_tex: Texture2D
var _roof_tex: Texture2D
var _paving_tex: Texture2D

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_wall_tex = PixelArt.tile_texture("wall_plaster")
	_roof_tex = PixelArt.tile_texture("roof_concrete")
	_paving_tex = PixelArt.tile_texture("paving")

func _draw() -> void:
	draw_set_transform(-position)
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
		facade_h = clampf(px.size.y * 0.62, 80.0, 104.0)
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
					if face_rect.size.x >= 200 and absf(wx + 6 - face_rect.get_center().x) < 26:
						continue
					_draw_window(Vector2(wx, fy), glass, wall, minf(wh + 3.0, floor_h - 4.0), 12.0, balcony)
				else:
					_draw_window(Vector2(wx, fy), glass, wall, wh, 12.0, balcony)
		if face_rect.size.x >= 200:
			_draw_entrance(Vector2(face_rect.get_center().x, face_rect.end.y), wall, glass)

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
	# Copper gutters, stone corners, climbing ivy and flower boxes.
	for sx in [px.position.x + 6, px.end.x - 10]:
		draw_rect(Rect2(sx, face_rect.position.y, 2, facade_h - 4), Color("89765d"))
		draw_rect(Rect2(sx, face_rect.position.y, 1, facade_h - 4), Color("c5ae81"))
	if style in ["brick", "u3d", "classic", "dorm", "gable"]:
		for i in range(1, wide, 4):
			var fp := Vector2(face_rect.position.x + margin + i * step, face_rect.end.y - floor_h - 3)
			draw_rect(Rect2(fp, Vector2(16, 4)), Color("9a644c"))
			draw_rect(Rect2(fp, Vector2(16, 1)), Color("d39b69"))
			for j in 4:
				draw_rect(Rect2(fp + Vector2(j * 4, -4 - j % 2), Vector2(3, 4)), Color("547c4d"))
				draw_rect(Rect2(fp + Vector2(j * 4, -5 - j % 2), Vector2(2, 2)), Color("efbb9f") if j % 2 == 0 else Color("f0d785"))
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
	# Cut stone corner blocks, with consistent top-left lighting across all facades.
	for y in range(int(face_rect.position.y) + 7, int(face_rect.end.y) - 4, 11):
		for x in [int(face_rect.position.x), int(face_rect.end.x) - 6]:
			draw_rect(Rect2(x, y, 6, 5), wall.lightened(0.08))
			draw_rect(Rect2(x, y + 5, 6, 1), wall.darkened(0.2))



func _draw_window(pos: Vector2, glass: Color, wall: Color, h: float, w: float, balcony: bool) -> void:
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), wall.darkened(0.42))
	draw_rect(Rect2(pos, Vector2(w, h)), glass.darkened(0.30))
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w - 2, h - 2)), glass)
	# 窗洞上沿的内阴影 + 下沿的受光，让窗“凹”进去
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w - 2, 1)), glass.darkened(0.55))
	draw_rect(Rect2(pos + Vector2(1, h - 1), Vector2(w - 2, 1)), glass.lightened(0.30))
	draw_rect(Rect2(pos + Vector2(1, 1), Vector2(w * 0.45, h * 0.4)), glass.lightened(0.20))
	# A few drawn curtains and reflected sky panels soften the institutional grid.
	var room := posmod(int(pos.x / 24) + int(pos.y / 15), 7)
	if room in [1, 4] and w >= 10 and h >= 8:
		draw_rect(Rect2(pos + Vector2(1, 2), Vector2(2, h - 3)), Color("ded4b7"))
		draw_rect(Rect2(pos + Vector2(w - 3, 2), Vector2(2, h - 3)), Color("bcb8a4"))
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


func _ellipse(c: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * float(i) / 40.0
		pts.append(c + Vector2(cos(t) * radii.x, sin(t) * radii.y))
	draw_colored_polygon(pts, color)

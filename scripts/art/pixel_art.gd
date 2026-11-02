class_name PixelArt
extends RefCounted
## 程序化像素素材库：地表、树、角色、作物、道具、图标。
##
## 全部素材在启动时用代码画进一张 256×256 的图集（或独立小图），
## 不依赖外部 PNG，因此项目仍然“打开即跑”。所有绘制都用整数像素、
## 有限调色板和 1px 描边，保证放大 3 倍后依旧干净。

const TILE := 16
const ATLAS_SIZE := 256

# ---- 调色板（秋季，低饱和，暖橄榄 + 灰紫，避免霓虹感）----
const GRASS := Color("6c7444")
const GRASS_HI := Color("858c52")
const GRASS_LO := Color("575e34")
const GRASS_DEEP := Color("454b2a")
const DIRT := Color("b68b58")
const DIRT_HI := Color("caa16b")
const DIRT_LO := Color("936d3e")
const STONE := Color("b3ad9d")
const STONE_HI := Color("cdc7b6")
const STONE_LO := Color("8a8476")
const WATER := Color("4b94cf")
const WATER_LO := Color("3679b0")
const WATER_HI := Color("8ec9e8")
const SHADOW := Color(0.16, 0.13, 0.20, 0.32)

const SKIN := Color("e9b489")
const SKIN_LO := Color("c68f68")
const HAIR := Color("5a3a23")
const HAT := Color("e2b95f")
const HAT_LO := Color("b98f3f")
const SHIRT := Color("3f76b5")
const SHIRT_LO := Color("2d5a90")
const PANTS := Color("3b4d6b")
const BOOT := Color("4a3222")

static var _atlas: ImageTexture = null
static var _cells: Dictionary = {}
static var _tile_tex: Dictionary = {}
static var _tree_cache: Dictionary = {}
static var _char_cache: Dictionary = {}
static var _crop_cache: Dictionary = {}
static var _prop_cache: Dictionary = {}
static var _icon_cache: Dictionary = {}


# =====================================================================
# 公共入口
# =====================================================================

static func atlas() -> Texture2D:
	if _atlas == null:
		_build_atlas()
	return _atlas


static func cell(tile_name: String) -> Rect2:
	atlas()
	return _cells.get(tile_name, Rect2(0, 0, TILE, TILE))


static func draw_tile(ci: CanvasItem, tile_name: String, pos: Vector2, mod: Color = Color.WHITE) -> void:
	ci.draw_texture_rect_region(atlas(), Rect2(pos, Vector2(TILE, TILE)), cell(tile_name), mod)


static func tile_texture(tile_name: String) -> Texture2D:
	## 单独抽出来的一张 16×16 贴图，给需要平铺（draw_texture_rect tile=true）的墙/屋顶用。
	if _tile_tex.has(tile_name):
		return _tile_tex[tile_name]
	var src: Image = atlas().get_image()
	var r := cell(tile_name)
	var img := src.get_region(Rect2i(int(r.position.x), int(r.position.y), TILE, TILE))
	var tex := ImageTexture.create_from_image(img)
	_tile_tex[tile_name] = tex
	return tex


static func tree(kind: String, variant: int = 0) -> Texture2D:
	if kind != "pine":
		var ext := external("tree", kind)
		if ext != null:
			return ext
	var key := "%s_%d" % [kind, variant]
	if _tree_cache.has(key):
		return _tree_cache[key]
	var img: Image
	match kind:
		"pine":
			img = _make_pine()
		"blossom", "cherry":
			img = _make_broadleaf(true, false, variant)
		"fruit":
			img = _make_broadleaf(false, true, variant)
		"bush":
			img = _make_bush()
		"crabapple":
			img = _make_crabapple(variant)
		"ginkgo":
			img = _make_broadleaf(false, false, variant, "ginkgo")
		"maple":
			img = _make_broadleaf(false, false, variant, "maple")
		"plane":
			img = _make_broadleaf(false, false, variant, "plane")
		"cypress":
			img = _make_cypress()
		"larch":
			img = _make_larch()
		"bamboo":
			img = _make_bamboo()
		"willow":
			img = _make_willow()
		_:
			img = _make_broadleaf(false, false, variant)
	var tex := ImageTexture.create_from_image(img)
	_tree_cache[key] = tex
	return tex


static func external(kind: String, key: String) -> Texture2D:
	## 外部素材包挂载点：把同名 PNG 放进 assets/sprites/ 就会自动替换程序化素材。
	## 例如 assets/sprites/tree_ginkgo.png、assets/sprites/prop_bench.png。
	var path := "res://assets/sprites/%s_%s.png" % [kind, key]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func character(direction: String, frame: int) -> Texture2D:
	var key := "%s_%d" % [direction, frame]
	if _char_cache.has(key):
		return _char_cache[key]
	var img: Image
	if direction == "right":
		img = _make_character("left", frame)
		img.flip_x()
	else:
		img = _make_character(direction, frame)
	var tex := ImageTexture.create_from_image(img)
	_char_cache[key] = tex
	return tex


static func person(direction: String, frame: int, shirt: Color, hair: Color, skin: Color, backpack: bool) -> Texture2D:
	## 校园人物：可换衣服/头发/肤色，是否背书包。
	var key := "%s_%d_%s_%s_%s_%s" % [direction, frame, shirt.to_html(false), hair.to_html(false), skin.to_html(false), str(backpack)]
	if _char_cache.has(key):
		return _char_cache[key]
	var img: Image
	if direction == "right":
		img = _make_person("left", frame, shirt, hair, skin, backpack)
		img.flip_x()
	else:
		img = _make_person(direction, frame, shirt, hair, skin, backpack)
	var tex := ImageTexture.create_from_image(img)
	_char_cache[key] = tex
	return tex


static func crop(stage: int, leaf: Color, fruit: Color, ready: bool) -> Texture2D:
	var key := "%d_%s_%s_%s" % [stage, leaf.to_html(false), fruit.to_html(false), ready]
	if _crop_cache.has(key):
		return _crop_cache[key]
	var tex := ImageTexture.create_from_image(_make_crop(stage, leaf, fruit, ready))
	_crop_cache[key] = tex
	return tex


static func prop(kind: String) -> Texture2D:
	var ext := external("prop", kind)
	if ext != null:
		return ext
	if _prop_cache.has(kind):
		return _prop_cache[kind]
	var img: Image
	match kind:
		"bin":
			img = _make_bin()
		"shop":
			img = _make_stall()
		"well":
			img = _make_well()
		"sign":
			img = _make_sign()
		"lamp":
			img = _make_lamp()
		"bench":
			img = _make_bench()
		"crate":
			img = _make_crate()
		"fountain":
			img = _make_fountain()
		"flagpole":
			img = _make_flagpole()
		"bike_rack":
			img = _make_bike_rack()
		"planter":
			img = _make_planter()
		"boat":
			img = _make_boat()
		"bell":
			img = _make_bell()
		"stele":
			img = _make_stele()
		"pavilion":
			img = _make_pavilion()
		_:
			img = _make_sign()
	var tex := ImageTexture.create_from_image(img)
	_prop_cache[kind] = tex
	return tex


static func icon(kind: String) -> Texture2D:
	if _icon_cache.has(kind):
		return _icon_cache[kind]
	var tex := ImageTexture.create_from_image(_make_icon(kind))
	_icon_cache[kind] = tex
	return tex


static func dot_texture() -> Texture2D:
	if _icon_cache.has("dot"):
		return _icon_cache["dot"]
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	var tex := ImageTexture.create_from_image(img)
	_icon_cache["dot"] = tex
	return tex


# =====================================================================
# 基础绘制工具
# =====================================================================

static func _rnd(x: int, y: int, s: int) -> float:
	var h := hash(Vector3i(x, y, s)) & 0xFFFF
	return float(h) / 65535.0


static func _shift(c: Color, amount: float) -> Color:
	if amount >= 0.0:
		return c.lightened(amount)
	return c.darkened(-amount)


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if c.a <= 0.0:
		return
	if c.a < 1.0:
		var under := img.get_pixel(x, y)
		c = under.lerp(Color(c.r, c.g, c.b, 1.0), c.a)
	img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_put(img, xx, yy, c)


static func _hline(img: Image, x: int, y: int, w: int, c: Color) -> void:
	_rect(img, x, y, w, 1, c)


static func _vline(img: Image, x: int, y: int, h: int, c: Color) -> void:
	_rect(img, x, y, 1, h, c)


static func _disc(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for dy in range(-ry, ry + 1):
		var t := 1.0 - pow(float(dy) / float(ry + 0.001), 2.0)
		var half := int(floor(float(rx) * sqrt(max(t, 0.0))))
		for dx in range(-half, half + 1):
			_put(img, cx + dx, cy + dy, c)


static func _noise_rect(img: Image, ox: int, oy: int, w: int, h: int, base: Color, amp: float, seedv: int) -> void:
	for y in h:
		for x in w:
			var n := (_rnd(x, y, seedv) - 0.5) * amp
			_put(img, ox + x, oy + y, _shift(base, n))


static func _shadow(img: Image, cx: int, cy: int, rx: int, ry: int, alpha: float = 0.30) -> void:
	for dy in range(-ry, ry + 1):
		var t := 1.0 - pow(float(dy) / float(ry + 0.001), 2.0)
		var half := int(floor(float(rx) * sqrt(max(t, 0.0))))
		for dx in range(-half, half + 1):
			_put(img, cx + dx, cy + dy, Color(0.08, 0.13, 0.07, alpha))


static func _outline(img: Image, c: Color, threshold: float = 0.55) -> void:
	## 给不透明区域补一圈 1px 描边，这是像素素材“立起来”的关键。
	var w := img.get_width()
	var h := img.get_height()
	var add: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a >= threshold:
				continue
			var touching := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + d.x
				var ny := y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if img.get_pixel(nx, ny).a >= threshold:
					touching = true
					break
			if touching:
				add.append(Vector2i(x, y))
	for p: Vector2i in add:
		img.set_pixel(p.x, p.y, c)


# =====================================================================
# 图集
# =====================================================================

static func _build_atlas() -> void:
	var img := Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var names: PackedStringArray = [
		"grass0", "grass1", "grass2", "grass3", "lawn",
		"dirt0", "dirt1", "stone0", "stone1", "plaza",
		"soil0", "soil1", "water0", "water1",
		"wall_plaster", "wall_brick", "wall_stone", "roof_shingle", "roof_tile",
		"hedge", "gravel", "dirt_edge",
		"grass4", "grass5", "grass6", "grass7",
		"sand", "paving", "track", "court", "roof_concrete",
		"asphalt", "concrete", "brick_paving", "lawn2", "lawn3",
	]
	for i in names.size():
		var cx := i % 16
		var cy := int(floor(float(i) / 16.0))
		var ox := cx * TILE
		var oy := cy * TILE
		_cells[names[i]] = Rect2(ox, oy, TILE, TILE)
		_paint_tile(img, names[i], ox, oy)
	_atlas = ImageTexture.create_from_image(img)


static func _paint_tile(img: Image, tile_name: String, ox: int, oy: int) -> void:
	match tile_name:
		"grass0":
			_paint_grass(img, ox, oy, 0)
		"grass1":
			_paint_grass(img, ox, oy, 1)
		"grass2":
			_paint_grass(img, ox, oy, 2)
		"grass3":
			_paint_grass(img, ox, oy, 3)
		"grass4":
			_paint_grass(img, ox, oy, 4)
		"grass5":
			_paint_grass(img, ox, oy, 5)
		"grass6":
			_paint_grass(img, ox, oy, 6)
		"grass7":
			_paint_grass(img, ox, oy, 7)
		"lawn":
			_paint_lawn(img, ox, oy)
		"dirt0":
			_paint_dirt(img, ox, oy, 0)
		"dirt1":
			_paint_dirt(img, ox, oy, 1)
		"stone0":
			_paint_stone(img, ox, oy, 0)
		"stone1":
			_paint_stone(img, ox, oy, 1)
		"plaza":
			_paint_plaza(img, ox, oy)
		"soil0":
			_paint_soil(img, ox, oy, false)
		"soil1":
			_paint_soil(img, ox, oy, true)
		"water0":
			_paint_water(img, ox, oy, 0)
		"water1":
			_paint_water(img, ox, oy, 1)
		"wall_plaster":
			_paint_plaster(img, ox, oy)
		"wall_brick":
			_paint_brick(img, ox, oy)
		"wall_stone":
			_paint_wall_stone(img, ox, oy)
		"roof_shingle":
			_paint_shingle(img, ox, oy)
		"roof_tile":
			_paint_roof_tile(img, ox, oy)
		"hedge":
			_paint_hedge(img, ox, oy)
		"gravel":
			_paint_gravel(img, ox, oy)
		"dirt_edge":
			_paint_dirt_edge(img, ox, oy)
		"sand":
			_paint_sand(img, ox, oy)
		"paving":
			_paint_paving(img, ox, oy)
		"track":
			_paint_track(img, ox, oy)
		"court":
			_paint_court(img, ox, oy)
		"roof_concrete":
			_paint_roof_concrete(img, ox, oy)
		"asphalt":
			_paint_asphalt(img, ox, oy)
		"concrete":
			_paint_concrete(img, ox, oy)
		"brick_paving":
			_paint_brick_paving(img, ox, oy)
		"lawn2":
			_paint_lawn_variant(img, ox, oy, 2)
		"lawn3":
			_paint_lawn_variant(img, ox, oy, 3)


static func _paint_paving(img: Image, ox: int, oy: int) -> void:
	for sy in 2:
		for sx in 2:
			var x0 := ox + sx * 8
			var y0 := oy + sy * 8
			var base := Color("d7d0be") if (sx + sy) % 2 == 0 else Color("dcd6c5")
			_noise_rect(img, x0, y0, 8, 8, base, 0.05, 781 + sx * 3 + sy)
			_hline(img, x0, y0, 8, Color("e9e3d2"))
			_vline(img, x0, y0, 8, Color("e9e3d2"))
			_hline(img, x0, y0 + 7, 8, Color("b9b2a0"))
			_vline(img, x0 + 7, y0, 8, Color("b9b2a0"))
			_put(img, x0 + 3, y0 + 4, Color("c9c2b0"))


static func _paint_track(img: Image, ox: int, oy: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, Color("b2544a"), 0.10, 791)
	for i in 12:
		var x := int(_rnd(i, 3, 792) * 15.0)
		var y := int(_rnd(i, 7, 792) * 15.0)
		_put(img, ox + x, oy + y, Color("c46a5e") if i % 2 == 0 else Color("9d453d"))


static func _paint_court(img: Image, ox: int, oy: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, Color("4b7d96"), 0.08, 793)
	for i in 10:
		var x := int(_rnd(i, 3, 794) * 15.0)
		var y := int(_rnd(i, 7, 794) * 15.0)
		_put(img, ox + x, oy + y, Color("5c93ac") if i % 2 == 0 else Color("3f6b81"))


static func _paint_roof_concrete(img: Image, ox: int, oy: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, Color("cbc7bb"), 0.06, 795)
	for i in 10:
		var x := int(_rnd(i, 3, 796) * 15.0)
		var y := int(_rnd(i, 7, 796) * 15.0)
		_put(img, ox + x, oy + y, Color("dcd8cc"))
		_put(img, ox + x + 1, oy + y, Color("b6b2a6"))
	# 屋面分缝：只在格子边缘留一条很浅的线
	_vline(img, ox, oy, TILE, Color("bcb8ac"))
	_hline(img, ox, oy, TILE, Color("bcb8ac"))


static func _paint_asphalt(img: Image, ox: int, oy: int) -> void:
	## 沥青：灰紫调、细骨料、少量修补痕（和参考片一致的低饱和冷紫）。
	for y in TILE:
		for x in TILE:
			var n := (_rnd(x, y, 811) - 0.5) * 0.10
			_put(img, ox + x, oy + y, _shift(Color("574f63"), n))
	for i in 30:
		var x := int(_rnd(i, 3, 812) * 15.0)
		var y := int(_rnd(i, 7, 812) * 15.0)
		_put(img, ox + x, oy + y, Color("6a6076") if i % 3 == 0 else Color("45414f"))
	for i in 2:
		var sx := int(_rnd(i, 5, 814) * 12.0)
		var sy := int(_rnd(i, 9, 814) * 12.0)
		_put(img, ox + sx, oy + sy, Color("4a4552"))
		_put(img, ox + sx + 1, oy + sy, Color("4a4552"))
		_put(img, ox + sx, oy + sy + 1, Color("625a6e"))


static func _paint_concrete(img: Image, ox: int, oy: int) -> void:
	## 清水混凝土：中灰分格板（压暗，避免整片发白）。
	_noise_rect(img, ox, oy, TILE, TILE, Color("bbb8ae"), 0.06, 821)
	_hline(img, ox, oy, TILE, Color("a09d93"))
	_vline(img, ox, oy, TILE, Color("a09d93"))
	_hline(img, ox, oy + 8, TILE, Color("afaca2"))
	_vline(img, ox + 8, oy, TILE, Color("c8c4ba"))
	for i in 7:
		var x := 2 + int(_rnd(i, 3, 822) * 11.0)
		var y := 2 + int(_rnd(i, 7, 822) * 11.0)
		_put(img, ox + x, oy + y, Color("aba89e"))


static func _paint_brick_paving(img: Image, ox: int, oy: int) -> void:
	## 红砖铺装：错缝小砖（压暗压灰，别抢画面）。
	_noise_rect(img, ox, oy, TILE, TILE, Color("a89b8c"), 0.05, 831)
	for row in 4:
		var off := 0 if row % 2 == 0 else 4
		for bx in range(-off, TILE, 8):
			var x0 := ox + bx
			for yy in 3:
				for xx in 7:
					var n2 := (_rnd(bx + xx, row * 4 + yy, 832) - 0.5) * 0.08
					_put(img, x0 + xx, oy + row * 4 + yy, _shift(Color("96604e"), n2))
			_hline(img, x0, oy + row * 4, 7, Color("aa7660"))
			_hline(img, x0, oy + row * 4 + 2, 7, Color("7f4c3e"))


static func _paint_lawn_variant(img: Image, ox: int, oy: int, v: int) -> void:
	for y in TILE:
		for x in TILE:
			var c := GRASS.lightened(0.03)
			var s := _rnd(x, y, 71 + v * 17)
			if s > 0.94:
				c = GRASS_HI
			elif s < 0.05:
				c = GRASS.darkened(0.05)
			var n := (_rnd(x, y, 70 + v) - 0.5) * 0.07
			_put(img, ox + x, oy + y, _shift(c, n))
	for i in 3:
		var bx := 2 + int(_rnd(i, 3, 90 + v) * 11.0)
		var by := 3 + int(_rnd(i, 7, 90 + v) * 10.0)
		_put(img, ox + bx, oy + by, GRASS_HI.darkened(0.05))
		_put(img, ox + bx, oy + by - 1, GRASS_HI.darkened(0.02))


static func _paint_sand(img: Image, ox: int, oy: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, Color("d3b985"), 0.10, 771)
	for i in 7:
		var x := 1 + int(_rnd(i, 2, 772) * 13.0)
		var y := 1 + int(_rnd(i, 5, 772) * 13.0)
		_put(img, ox + x, oy + y, Color("e3cfa0"))
		_put(img, ox + x + 1, oy + y, Color("b99c68"))


static func _blade(img: Image, x: int, y: int, hi: Color, lo: Color) -> void:
	_put(img, x, y, hi.darkened(0.10))
	_put(img, x, y - 1, hi.darkened(0.18))
	_put(img, x + 1, y, lo)


static func _paint_grass(img: Image, ox: int, oy: int, variant: int) -> void:
	var style := variant % 4
	var seedv := 11 + variant * 37
	var base := GRASS
	for y in TILE:
		for x in TILE:
			var c := base
			var s := _rnd(x, y, seedv + 7)
			if s > 0.90:
				c = base.darkened(0.05)
			elif s < 0.10:
				c = base.lightened(0.04)
			var n := (_rnd(x, y, seedv) - 0.5) * 0.10
			_put(img, ox + x, oy + y, _shift(c, n))
	if style == 0:
		for i in 4:
			var bx := 1 + int(_rnd(i, 3, seedv) * 13.0)
			var by := 4 + int(_rnd(i, 9, seedv) * 10.0)
			_blade(img, ox + bx, oy + by, GRASS_HI, GRASS_LO)
	elif style == 1:
		for i in 6:
			var bx := 1 + int(_rnd(i, 3, seedv) * 13.0)
			var by := 4 + int(_rnd(i, 9, seedv) * 10.0)
			_blade(img, ox + bx, oy + by, GRASS_HI, GRASS_DEEP)
		_put(img, ox + 12, oy + 2, GRASS_HI)
		_put(img, ox + 13, oy + 3, GRASS_DEEP)
	elif style == 2:
		for i in 2:
			var bx := 3 + int(_rnd(i, 5, seedv) * 9.0)
			var by := 3 + int(_rnd(i, 13, seedv) * 9.0)
			var petal := Color("f2e9a8") if i != 1 else Color("e8b3c8")
			_put(img, ox + bx, oy + by, petal)
			_put(img, ox + bx + 1, oy + by, petal.lightened(0.12))
			_put(img, ox + bx, oy + by - 1, petal)
			_put(img, ox + bx + 1, oy + by - 1, petal.darkened(0.08))
			_put(img, ox + bx, oy + by + 1, Color("d9c76a"))
			_put(img, ox + bx + 2, oy + by + 1, GRASS_LO)
	elif style == 3:
		for i in 2:
			var bx := 2 + int(_rnd(i, 3, seedv) * 11.0)
			var by := 2 + int(_rnd(i, 9, seedv) * 11.0)
			_put(img, ox + bx, oy + by, GRASS_DEEP)
			_put(img, ox + bx + 1, oy + by, GRASS_DEEP)
			_put(img, ox + bx, oy + by + 1, GRASS_LO)
			_put(img, ox + bx + 2, oy + by + 1, GRASS_DEEP)
		for i in 3:
			var bx := 2 + int(_rnd(i, 7, seedv) * 11.0)
			var by := 4 + int(_rnd(i, 17, seedv) * 10.0)
			_blade(img, ox + bx, oy + by, GRASS_HI, GRASS_LO)


static func _paint_lawn(img: Image, ox: int, oy: int) -> void:
	for y in TILE:
		for x in TILE:
			var c := GRASS.lightened(0.02)
			var s := _rnd(x, y, 72)
			if s > 0.93:
				c = GRASS_HI
			elif s < 0.06:
				c = GRASS.darkened(0.05)
			var n := (_rnd(x, y, 71) - 0.5) * 0.07
			_put(img, ox + x, oy + y, _shift(c, n))


static func _paint_dirt(img: Image, ox: int, oy: int, variant: int) -> void:
	var seedv := 201 + variant * 13
	_noise_rect(img, ox, oy, TILE, TILE, DIRT, 0.14, seedv)
	for i in 5:
		var px := 1 + int(_rnd(i, 2, seedv) * 13.0)
		var py := 1 + int(_rnd(i, 6, seedv) * 13.0)
		var light := _rnd(i, 8, seedv) > 0.45
		var c := DIRT_HI if light else DIRT_LO
		_put(img, ox + px, oy + py, c)
		_put(img, ox + px + 1, oy + py, c.darkened(0.06))
		if _rnd(i, 12, seedv) > 0.5:
			_put(img, ox + px, oy + py + 1, c.darkened(0.12))
	if variant == 1:
		_put(img, ox + 3, oy + 12, DIRT_LO)
		_put(img, ox + 4, oy + 12, DIRT_LO)
		_put(img, ox + 12, oy + 3, DIRT_HI)


static func _paint_dirt_edge(img: Image, ox: int, oy: int) -> void:
	# 小路与草地的过渡：上缘压一圈深土，再点几个草尖
	_noise_rect(img, ox, oy, TILE, TILE, DIRT.darkened(0.06), 0.12, 233)
	_hline(img, ox, oy, TILE, DIRT_LO.darkened(0.10))
	for x in range(0, TILE, 3):
		_put(img, ox + x, oy + 1, DIRT_LO)
		_put(img, ox + x + 1, oy + 2, GRASS_DEEP)


static func _paint_stone(img: Image, ox: int, oy: int, variant: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, STONE, 0.10, 301 + variant)
	for sy in 2:
		for sx in 2:
			var x0 := ox + sx * 8
			var y0 := oy + sy * 8
			_hline(img, x0, y0, 7, STONE_HI)
			_vline(img, x0, y0, 7, STONE_HI)
			_hline(img, x0, y0 + 7, 7, STONE_LO.darkened(0.12))
			_vline(img, x0 + 7, y0, 7, STONE_LO.darkened(0.12))
			_put(img, x0 + 7, y0 + 7, STONE_LO.darkened(0.24))
			_put(img, x0 + 2, y0 + 3, STONE_HI.darkened(0.06))
			_put(img, x0 + 5, y0 + 2, STONE_LO)


static func _paint_plaza(img: Image, ox: int, oy: int) -> void:
	for sy in 2:
		for sx in 2:
			var x0 := ox + sx * 8
			var y0 := oy + sy * 8
			var base := STONE if (sx + sy) % 2 == 0 else STONE.lightened(0.06)
			_noise_rect(img, x0, y0, 8, 8, base, 0.08, 401 + sx * 3 + sy)
			_hline(img, x0, y0, 8, STONE_HI)
			_vline(img, x0, y0, 8, STONE_HI)
			_hline(img, x0, y0 + 7, 8, STONE_LO.darkened(0.08))
			_vline(img, x0 + 7, y0, 8, STONE_LO.darkened(0.08))


static func _paint_soil(img: Image, ox: int, oy: int, wet: bool) -> void:
	var base := Color("6b4a2c") if not wet else Color("4a3220")
	var hi := Color("8a6238") if not wet else Color("5c4229")
	var lo := Color("452c18") if not wet else Color("2b1a0c")
	for y in TILE:
		for x in TILE:
			var n := (_rnd(x, y, 501 if not wet else 502) - 0.5) * 0.14
			_put(img, ox + x, oy + y, _shift(base, n))
	# 犁沟：断续的深色沟底 + 上缘亮边，避免整条直线看起来像木板
	for row in range(1, TILE, 5):
		for x in TILE:
			if _rnd(x, row, 77 if not wet else 78) < 0.25:
				continue
			_put(img, ox + x, oy + row + 2, lo)
			_put(img, ox + x, oy + row + 3, lo.darkened(0.08))
			_put(img, ox + x, oy + row, hi)
	# 土块与碎石
	for i in 6:
		var cx := 2 + int(_rnd(i, 3, 79) * 12.0)
		var cy := 2 + int(_rnd(i, 5, 80) * 11.0)
		var c := base.darkened(0.14) if i % 2 == 0 else base.lightened(0.08)
		_put(img, ox + cx, oy + cy, c)
		_put(img, ox + cx + 1, oy + cy, c.darkened(0.05))
		_put(img, ox + cx, oy + cy + 1, c.darkened(0.10))
	if wet:
		for i in 5:
			var wx := 2 + int(_rnd(i, 3, 81) * 12.0)
			var wy := 2 + int(_rnd(i, 5, 82) * 12.0)
			_put(img, ox + wx, oy + wy, Color("6f7f88"))
			_put(img, ox + wx + 1, oy + wy, Color("55646c"))


static func _paint_water(img: Image, ox: int, oy: int, variant: int) -> void:
	var seedv := 601 + variant * 31
	for y in TILE:
		for x in TILE:
			var t := float(y) / float(TILE)
			var c := WATER.lerp(WATER_LO, 0.25 + t * 0.45)
			var n := (_rnd(x, y, seedv) - 0.5) * 0.10
			_put(img, ox + x, oy + y, _shift(c, n))
	# 两道波光：上缘亮、下缘暗，像水面反光
	for row in [4, 11]:
		var off := 2 if (row + variant) % 2 == 0 else 0
		for x in range(off, TILE, 2):
			if _rnd(x, row, seedv) < 0.30:
				continue
			_put(img, ox + x, oy + row, WATER_HI)
			if x + 1 < TILE:
				_put(img, ox + x + 1, oy + row, WATER_HI.darkened(0.10))
			_put(img, ox + x, oy + row + 1, WATER_LO.darkened(0.08))
	if variant == 1:
		_put(img, ox + 6, oy + 7, WATER_HI.lightened(0.18))
		_put(img, ox + 7, oy + 7, WATER_HI)
		_put(img, ox + 3, oy + 13, WATER_HI.darkened(0.12))


static func _paint_plaster(img: Image, ox: int, oy: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, Color("efe8d8"), 0.06, 701)
	# 抹灰墙的错缝分格：比随机噪点更像建筑表面
	_hline(img, ox, oy + 7, TILE, Color("e3d9c5"))
	_hline(img, ox, oy + 15, TILE, Color("e3d9c5"))
	_vline(img, ox + 5, oy, 7, Color("e7ddc9"))
	_vline(img, ox + 11, oy + 8, 7, Color("e7ddc9"))
	_put(img, ox + 13, oy + 5, Color("dccfb8"))
	_put(img, ox + 4, oy + 12, Color("dccfb8"))


static func _paint_brick(img: Image, ox: int, oy: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, Color("ece2d2"), 0.07, 711)
	for row in range(0, TILE, 5):
		_hline(img, ox, oy + row + 4, TILE, Color("cdbfa9"))
		var off := 0 if (row / 5) % 2 == 0 else 4
		for x in range(off, TILE, 8):
			_vline(img, ox + x, oy + row, 4, Color("d6c8b2"))
			_put(img, ox + x, oy + row + 4, Color("c3b49c"))


static func _paint_wall_stone(img: Image, ox: int, oy: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, Color("ded6c6"), 0.09, 721)
	for row in range(0, TILE, 6):
		_hline(img, ox, oy + row, TILE, Color("c2b8a4"))
		var off := 0 if (row / 6) % 2 == 0 else 3
		for x in range(off, TILE, 7):
			_vline(img, ox + x, oy + row, 6, Color("c2b8a4"))
			_put(img, ox + x + 1, oy + row + 1, Color("eae3d4"))


static func _paint_shingle(img: Image, ox: int, oy: int) -> void:
	var base := Color("e9e9e9")
	for y in TILE:
		for x in TILE:
			var n := (_rnd(x, y, 731) - 0.5) * 0.09
			_put(img, ox + x, oy + y, _shift(base, n))
	for row in range(0, TILE, 5):
		_hline(img, ox, oy + row, TILE, Color("ffffff"))
		_hline(img, ox, oy + row + 4, TILE, Color("b9b9b9"))
		var off := 0 if (row / 5) % 2 == 0 else 4
		for x in range(off, TILE, 8):
			_vline(img, ox + x, oy + row, 5, Color("cfcfcf"))
			_put(img, ox + x, oy + row + 4, Color("a8a8a8"))


static func _paint_roof_tile(img: Image, ox: int, oy: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, Color("e6e6e6"), 0.06, 741)
	for x in range(0, TILE, 5):
		_vline(img, ox + x, oy, TILE, Color("bdbdbd"))
		_vline(img, ox + x + 1, oy, TILE, Color("f6f6f6"))
	for y in range(2, TILE, 5):
		_hline(img, ox, oy + y, TILE, Color("d2d2d2"))


static func _paint_hedge(img: Image, ox: int, oy: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, Color("3c6b34"), 0.14, 751)
	for i in 7:
		var x := 1 + int(_rnd(i, 2, 752) * 13.0)
		var y := 1 + int(_rnd(i, 7, 752) * 13.0)
		_put(img, ox + x, oy + y, Color("4f8442"))
		_put(img, ox + x, oy + y + 1, Color("2f5629"))


static func _paint_gravel(img: Image, ox: int, oy: int) -> void:
	_noise_rect(img, ox, oy, TILE, TILE, Color("a9a190"), 0.12, 761)
	for i in 9:
		var x := 1 + int(_rnd(i, 2, 762) * 13.0)
		var y := 1 + int(_rnd(i, 7, 762) * 13.0)
		_put(img, ox + x, oy + y, Color("c4bcaa"))
		_put(img, ox + x + 1, oy + y, Color("8f8877"))


# =====================================================================
# 树
# =====================================================================

static func _make_broadleaf(blossom: bool, fruit: bool, variant: int = 0, kind: String = "oak") -> Image:
	var w := 34
	var h := 46
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2
	var seedv := 801 + variant * 97

	var dark := Color("2b5a2b")
	var mid := Color("3f7b39")
	var light := Color("5b9c4a")
	var hi := Color("7dbe60")
	var outline_c := Color("1c3a1a")
	match kind:
		"ginkgo":
			dark = Color("6a6a24")
			mid = Color("96962f")
			light = Color("c4bc3e")
			hi = Color("e6d96a")
			outline_c = Color("3a3a14")
		"maple":
			dark = Color("6a2a1e")
			mid = Color("9c3a20")
			light = Color("c85a2a")
			hi = Color("e88a3a")
			outline_c = Color("3a160e")
		"plane":
			dark = Color("38542c")
			mid = Color("557a38")
			light = Color("7f9c4a")
			hi = Color("b4c070")
			outline_c = Color("24361a")
	if blossom:
		dark = Color("6d3350")
		mid = Color("a8517a")
		light = Color("d07ba3")
		hi = Color("f0b3c9")
		outline_c = Color("4a2030")

	# 树干
	_rect(img, cx - 3, h - 17, 6, 15, Color("4b3120"))
	_rect(img, cx - 2, h - 16, 3, 13, Color("6b472b"))
	_rect(img, cx - 1, h - 15, 1, 11, Color("8a5f38"))
	_rect(img, cx + 2, h - 15, 1, 12, Color("3f2818"))
	# 根部
	_rect(img, cx - 5, h - 4, 3, 2, Color("4b3120"))
	_rect(img, cx + 3, h - 4, 3, 2, Color("4b3120"))

	var top := Vector2i(cx, h - 30)
	# 外轮廓 + 三层树冠（变体让树冠轮廓略有差别）
	var jx := (variant * 5) % 5 - 2
	_disc(img, top.x, top.y + 2, 16, 12, dark)
	_disc(img, top.x, top.y + 1, 15, 11, mid)
	_disc(img, top.x - 3 + jx, top.y - 3, 12, 9, light)
	_disc(img, top.x + 4 - jx, top.y + 2, 10, 8, mid)
	_disc(img, top.x - 6, top.y + 3, 7, 6, mid)
	_disc(img, top.x - 4, top.y - 5, 8, 6, hi)
	# 侧边小簇，打破圆形
	_disc(img, top.x + 13, top.y + 5, 4, 4, mid)
	_disc(img, top.x - 14, top.y + 4, 4, 4, dark)
	_disc(img, top.x + 10, top.y - 8 - variant, 4, 4, light)

	# 叶簇高光与抖动
	for i in 16:
		var px := cx - 13 + int(_rnd(i, 3, seedv) * 27.0)
		var py := top.y - 12 + int(_rnd(i, 9, seedv) * 22.0)
		var c := hi if _rnd(i, 5, seedv + 1) > 0.45 else light
		_put(img, px, py, c)
	for i in 10:
		var px := cx - 12 + int(_rnd(i, 7, seedv + 2) * 25.0)
		var py := top.y - 10 + int(_rnd(i, 11, seedv + 2) * 20.0)
		_put(img, px, py, dark.darkened(0.08))

	if fruit:
		for p: Vector2i in [Vector2i(-7, 2), Vector2i(5, 6), Vector2i(9, -4), Vector2i(-2, 9)]:
			var fx := cx + p.x + jx
			var fy := top.y + p.y
			_put(img, fx, fy, Color("e07b2a"))
			_put(img, fx + 1, fy, Color("f2a044"))
			_put(img, fx, fy + 1, Color("b85a1c"))
	if blossom:
		for i in 8:
			var px := cx - 11 + int(_rnd(i, 13, seedv + 3) * 23.0)
			var py := top.y - 9 + int(_rnd(i, 17, seedv + 3) * 18.0)
			_put(img, px, py, Color("ffe3ee"))
	_outline(img, outline_c)
	_shadow(img, cx, h - 3, 13, 4, 0.26)
	return img


static func _make_pine() -> Image:
	var w := 28
	var h := 50
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2
	# 树干
	_rect(img, cx - 2, h - 14, 4, 12, Color("4a3120"))
	_rect(img, cx - 1, h - 13, 1, 10, Color("7a5230"))

	# 三层塔形树冠：实心三角形 + 左右明暗 + 锯齿底边
	var layers := [
		{"base": h - 9, "top": h - 22, "half": 12},
		{"base": h - 20, "top": h - 34, "half": 9},
		{"base": h - 31, "top": h - 44, "half": 6},
	]
	for layer: Dictionary in layers:
		var base_y: int = layer["base"]
		var top_y: int = layer["top"]
		var half: int = layer["half"]
		var height := base_y - top_y
		for row in range(height):
			var t := float(row) / float(height)
			var hw := int(round(float(half) * t))
			var y := top_y + row
			_rect(img, cx - hw, y, hw * 2 + 1, 1, Color("2f6438"))
			_put(img, cx - hw, y, Color("4f8a46"))
			_put(img, cx - hw + 1, y, Color("4f8a46"))
			_put(img, cx + hw, y, Color("23502c"))
		# 锯齿状下沿
		var step := 3
		for x in range(cx - half, cx + half + 1, step):
			_put(img, x, base_y, Color("23502c"))
			_put(img, x + 1, base_y, Color("2f6438"))
		# 高光
		for i in 3:
			var hx := cx - half + 3 + int(_rnd(i, layer["base"], 813) * float(half))
			var hy := top_y + 3 + int(_rnd(i, layer["top"], 814) * float(height - 4))
			_put(img, hx, hy, Color("6aa85a"))
	_deep_outline(img, Color("183a20"))
	_shadow(img, cx, h - 3, 10, 4, 0.30)
	return img


static func _deep_outline(img: Image, c: Color) -> void:
	_outline(img, c, 0.55)


static func _make_bush() -> Image:
	var w := 22
	var h := 18
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 11, h - 2, 8, 3, 0.26)
	_disc(img, 11, h - 7, 10, 6, Color("2c5c2c"))
	_disc(img, 9, h - 8, 8, 5, Color("3f7b39"))
	_disc(img, 13, h - 6, 6, 4, Color("4f8f42"))
	_disc(img, 8, h - 10, 5, 4, Color("64a850"))
	for i in 4:
		_put(img, 4 + int(_rnd(i, 2, 821) * 13.0), h - 9 + int(_rnd(i, 5, 821) * 5.0), Color("8cc46a"))
	return img


static func _make_crabapple(variant: int) -> Image:
	## 海棠：深粉花 + 一点点红果，比樱花更浓。
	var w := 30
	var h := 42
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2
	var seedv := 901 + variant * 71
	_rect(img, cx - 2, h - 14, 4, 12, Color("4b3120"))
	_rect(img, cx - 1, h - 13, 1, 10, Color("7a5230"))
	var top := Vector2i(cx, h - 27)
	var dark := Color("8a3552")
	var mid := Color("b8496a")
	var light := Color("dc7d97")
	var hi := Color("f0b3c2")
	_disc(img, top.x, top.y + 1, 13, 10, dark)
	_disc(img, top.x, top.y, 12, 9, mid)
	_disc(img, top.x - 3, top.y - 3, 9, 7, light)
	_disc(img, top.x + 3, top.y + 2, 8, 6, mid)
	_disc(img, top.x - 4, top.y - 4, 6, 5, hi)
	_disc(img, top.x + 10, top.y + 4, 3, 3, mid)
	_disc(img, top.x - 11, top.y + 3, 3, 3, dark)
	for i in 8:
		var px := cx - 8 + int(_rnd(i, 3, seedv) * 17.0)
		var py := top.y - 8 + int(_rnd(i, 7, seedv) * 15.0)
		_put(img, px, py, Color("fff0f4") if i % 3 == 0 else hi)
	for i in 4:
		var px := cx - 6 + int(_rnd(i, 11, seedv) * 13.0)
		var py := top.y - 2 + int(_rnd(i, 13, seedv) * 9.0)
		_put(img, px, py, Color("b8374a"))
		_put(img, px + 1, py, Color("d94a5a"))
	_outline(img, Color("5c2a38"))
	_shadow(img, cx, h - 3, 10, 3, 0.24)
	return img


static func _make_bamboo() -> Image:
	## 竹子：一根主秆 + 两根细秆 + 竹叶。
	var w := 16
	var h := 46
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 8, h - 2, 5, 2, 0.20)
	for stalk in [{"x": 7, "top": 8}, {"x": 11, "top": 16}, {"x": 4, "top": 20}]:
		var x: int = stalk["x"]
		var top_y: int = stalk["top"]
		var c := Color("7fae4c") if x == 7 else Color("6a9a40")
		_rect(img, x, top_y, 2, h - 4 - top_y, c)
		_rect(img, x, top_y, 1, h - 4 - top_y, c.lightened(0.15))
		for y in range(top_y + 3, h - 6, 6):
			_rect(img, x, y, 2, 1, Color("4e7330"))
		# 竹叶
		for leaf in 3:
			var ly := top_y + 2 + leaf * 7
			var dir := 1 if (leaf + x) % 2 == 0 else -1
			_put(img, x + dir, ly, Color("8dc45a"))
			_put(img, x + dir * 2, ly - 1, Color("8dc45a"))
			_put(img, x + dir * 3, ly - 2, Color("7fb257"))
			_put(img, x + dir * 2, ly, Color("6a9a40"))
	return img


static func _make_willow() -> Image:
	## 垂柳：柳条垂到接近地面。
	var w := 44
	var h := 54
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2
	_shadow(img, cx, h - 3, 14, 4, 0.26)
	_rect(img, cx - 3, h - 18, 6, 16, Color("4b3120"))
	_rect(img, cx - 2, h - 17, 2, 14, Color("6b472b"))
	var top := Vector2i(cx, h - 34)
	_disc(img, top.x, top.y, 15, 9, Color("5f8f3d"))
	_disc(img, top.x - 3, top.y - 3, 12, 7, Color("79ab4c"))
	_disc(img, top.x + 4, top.y - 2, 10, 6, Color("6a9a40"))
	_disc(img, top.x - 6, top.y - 4, 8, 5, Color("8cc45a"))
	# 柳条
	for i in 9:
		var ox := cx - 16 + i * 4
		var len := 16 + int(_rnd(i, 3, 951) * 12.0)
		for d in len:
			_put(img, ox, top.y + d - 2, Color("8cc45a") if d % 4 != 0 else Color("6a9a40"))
		_put(img, ox, top.y + len - 3, Color("a8d86a"))
	_outline(img, Color("2f5626"))
	_shadow(img, cx, h - 3, 13, 4, 0.22)
	return img


# =====================================================================
# 角色
# =====================================================================

static func _make_person(direction: String, frame: int, shirt: Color, hair: Color, skin: Color, backpack: bool) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var step := 0
	if frame == 1:
		step = 1
	elif frame == 2:
		step = -1
	var shirt_lo := shirt.darkened(0.22)
	var pants := Color("38465c")
	var boot := Color("3b2a1c")
	var pack := Color("a8703c")
	var pack_dark := Color("7d5028")
	_shadow(img, 8, 22, 5, 2, 0.28)

	if backpack:
		if direction == "up":
			_rect(img, 4, 11, 8, 8, pack)
			_rect(img, 4, 11, 8, 1, pack.lightened(0.15))
			_rect(img, 4, 17, 8, 2, pack_dark)
			_rect(img, 7, 12, 2, 5, pack_dark)
		elif direction == "left":
			_rect(img, 9, 11, 4, 7, pack)
			_rect(img, 9, 11, 1, 7, pack.lightened(0.12))
		else:
			_rect(img, 3, 11, 10, 7, pack)
			_rect(img, 3, 11, 10, 1, pack.lightened(0.12))

	if direction == "up":
		_rect(img, 4, 3, 8, 7, skin)
		_rect(img, 4, 3, 8, 3, hair)
		_rect(img, 4, 6, 8, 3, hair.darkened(0.12))
		_rect(img, 4, 10, 8, 1, skin.darkened(0.12))
		_rect(img, 3, 11, 2, 4, shirt_lo)
		_rect(img, 11, 11, 2, 4, shirt_lo)
		_rect(img, 4, 11, 8, 6, shirt_lo)
		_rect(img, 4, 11, 1, 6, shirt_lo.lightened(0.12))
	else:
		_rect(img, 4, 4, 8, 7, skin)
		_rect(img, 4, 10, 8, 1, skin.darkened(0.14))
		if direction == "left":
			_rect(img, 9, 3, 3, 7, hair)
			_rect(img, 3, 3, 2, 3, hair)
			_rect(img, 4, 3, 5, 1, hair.darkened(0.1))
			_put(img, 5, 7, Color("2a2018"))
			_put(img, 5, 8, Color("2a2018"))
		else:
			_rect(img, 3, 3, 2, 7, hair)
			_rect(img, 11, 3, 2, 7, hair)
			_rect(img, 4, 3, 8, 2, hair)
			_rect(img, 4, 3, 8, 1, hair.lightened(0.08))
			_rect(img, 5, 6, 1, 2, Color("2a2018"))
			_rect(img, 10, 6, 1, 2, Color("2a2018"))
			_put(img, 6, 9, skin.darkened(0.25))
		_rect(img, 4, 11, 8, 6, shirt)
		_rect(img, 4, 11, 8, 1, shirt.lightened(0.10))
		_rect(img, 4, 16, 8, 1, shirt_lo)
		_rect(img, 3, 11, 1, 6, shirt_lo)
		_rect(img, 12, 11, 1, 6, shirt_lo)
		_rect(img, 3, 15, 1, 2, skin)
		_rect(img, 12, 15, 1, 2, skin)
		if backpack:
			_rect(img, 5, 11, 1, 6, pack_dark)
			_rect(img, 10, 11, 1, 6, pack_dark)
	# 腿
	_rect(img, 5, 17, 2, 4 + step, pants)
	_rect(img, 9, 17, 2, 4 - step, pants)
	_rect(img, 4, 21 + step, 3, 2, boot)
	_rect(img, 9, 21 - step, 3, 2, boot)
	return img


static func _make_character(direction: String, frame: int) -> Image:
	var img := Image.create(16, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var step := 0
	if frame == 1:
		step = 1
	elif frame == 2:
		step = -1

	_shadow(img, 8, 22, 5, 2, 0.30)

	if direction == "up":
		# 帽檐 + 后脑头发
		_rect(img, 3, 8, 10, 2, HAT_LO)
		_rect(img, 4, 3, 8, 3, HAT)
		_rect(img, 5, 2, 6, 1, HAT.lightened(0.12))
		_rect(img, 4, 6, 8, 4, HAIR)
		_rect(img, 4, 10, 8, 2, HAIR.darkened(0.15))
		_rect(img, 5, 12, 6, 5, SHIRT)
		_rect(img, 3, 12, 2, 4, SKIN_LO)
		_rect(img, 11, 12, 2, 4, SKIN_LO)
		_rect(img, 6, 12, 4, 5, SHIRT_LO)  # 背带
		_rect(img, 5, 17, 6, 3, PANTS)
		_rect(img, 5, 20, 2 + step, 2, BOOT)
		_rect(img, 9, 20, 2 - step, 2, BOOT)
	else:
		# 头
		_rect(img, 4, 4, 8, 7, SKIN)
		_rect(img, 4, 10, 8, 1, SKIN_LO)
		if direction == "left":
			_rect(img, 9, 4, 3, 7, HAIR)
			_rect(img, 4, 4, 1, 3, HAIR)
			_rect(img, 3, 5, 1, 2, HAIR.darkened(0.1))
		else:
			_rect(img, 3, 4, 2, 7, HAIR)
			_rect(img, 11, 4, 2, 7, HAIR)
			_rect(img, 4, 4, 8, 1, HAIR.darkened(0.05))
		# 草帽
		_rect(img, 2, 3, 12, 2, HAT_LO)
		_rect(img, 3, 2, 10, 1, HAT)
		_rect(img, 4, 1, 8, 1, HAT.lightened(0.1))
		_rect(img, 3, 3, 10, 1, HAT.darkened(0.08))
		# 眼睛
		if direction == "left":
			_put(img, 5, 7, Color("2a2018"))
			_put(img, 5, 8, Color("2a2018"))
		else:
			_put(img, 6, 7, Color("2a2018"))
			_put(img, 6, 8, Color("2a2018"))
			_put(img, 9, 7, Color("2a2018"))
			_put(img, 9, 8, Color("2a2018"))
		# 身体
		_rect(img, 4, 11, 8, 5, SHIRT)
		_rect(img, 4, 15, 8, 1, SHIRT_LO)
		_rect(img, 4, 11, 1, 5, SHIRT.lightened(0.10))
		# 手臂
		if direction == "left":
			_rect(img, 3, 12, 2, 4, SHIRT_LO)
			_put(img, 3, 15, SKIN)
			_put(img, 4, 15, SKIN)
		else:
			_rect(img, 3, 12, 2, 4, SHIRT_LO)
			_rect(img, 11, 12, 2, 4, SHIRT_LO)
			_put(img, 3, 15, SKIN)
			_put(img, 12, 15, SKIN)
			_put(img, 4, 15, SKIN)
			_put(img, 11, 15, SKIN)
		# 背带裤
		_rect(img, 6, 11, 4, 5, PANTS)
		_put(img, 6, 11, PANTS.lightened(0.12))
		_put(img, 9, 11, PANTS.lightened(0.12))
		# 腿
		_rect(img, 5, 16, 2, 4 + step, PANTS)
		_rect(img, 9, 16, 2, 4 - step, PANTS)
		_rect(img, 4, 20 + step, 3, 2, BOOT)
		_rect(img, 9, 20 - step, 3, 2, BOOT)
	return img


# =====================================================================
# 作物
# =====================================================================

static func _make_crop(stage: int, leaf: Color, fruit: Color, ready: bool) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := leaf.darkened(0.28)
	var light := leaf.lightened(0.16)
	_shadow(img, 8, 14, 4, 2, 0.22)
	match stage:
		0:
			_rect(img, 6, 11, 4, 2, Color("8a6238"))
			_put(img, 7, 10, leaf)
			_put(img, 8, 10, light)
		1:
			_rect(img, 7, 8, 1, 6, dark)
			_rect(img, 5, 9, 2, 1, leaf)
			_rect(img, 8, 9, 2, 1, leaf)
			_put(img, 6, 9, light)
		2:
			_rect(img, 7, 7, 1, 7, dark)
			_rect(img, 4, 8, 3, 1, leaf)
			_rect(img, 9, 8, 3, 1, leaf)
			_rect(img, 5, 6, 2, 2, leaf)
			_rect(img, 9, 6, 2, 2, leaf)
			_put(img, 5, 6, light)
			_put(img, 10, 7, light)
		3:
			_rect(img, 7, 6, 1, 8, dark.darkened(0.1))
			_rect(img, 3, 7, 4, 2, leaf)
			_rect(img, 9, 7, 4, 2, leaf)
			_rect(img, 4, 5, 3, 2, light)
			_rect(img, 9, 5, 3, 2, leaf)
			_rect(img, 2, 9, 3, 2, dark)
			_rect(img, 11, 9, 3, 2, dark)
			_rect(img, 6, 3, 4, 3, fruit)
			_rect(img, 7, 2, 2, 1, fruit.lightened(0.2))
			_put(img, 6, 6, fruit.darkened(0.25))
			_put(img, 4, 6, light)
			if ready:
				_put(img, 11, 4, Color("fff3b0"))
				_put(img, 12, 5, Color("ffe27a"))
				_put(img, 3, 3, Color("fff3b0"))
	return img


# =====================================================================
# 道具
# =====================================================================

static func _make_bin() -> Image:
	var img := Image.create(24, 22, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 12, 20, 10, 3, 0.28)
	_rect(img, 3, 6, 18, 13, Color("5d3f24"))
	_rect(img, 4, 7, 16, 11, Color("8a5f38"))
	_rect(img, 4, 7, 16, 2, Color("a5723f"))
	for x in range(5, 20, 4):
		_vline(img, x, 7, 11, Color("6d4a2a"))
	_rect(img, 2, 4, 20, 4, Color("4a3120"))
	_rect(img, 3, 4, 18, 2, Color("a5723f"))
	_rect(img, 6, 3, 12, 2, Color("6b4a2a"))
	_rect(img, 3, 16, 18, 2, Color("b8b0a0"))
	_rect(img, 3, 17, 18, 1, Color("8d8577"))
	_put(img, 11, 9, Color("d9c27a"))
	_put(img, 14, 9, Color("d9c27a"))
	return img


static func _make_stall() -> Image:
	var w := 54
	var h := 44
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, w / 2, h - 2, 22, 4, 0.28)
	# 顶棚：红白条纹
	for row in range(0, 10):
		for x in range(0, w - 4, 8):
			var c := Color("cf5a4a") if (x / 8 + row / 4) % 2 == 0 else Color("f0e6cf")
			_rect(img, 3 + x, 2 + row, 8, 1, c)
	# 顶棚描边
	_rect(img, 2, 1, w - 4, 1, Color("7a3a2c"))
	_rect(img, 2, 11, w - 4, 2, Color("8a5a3a"))
	# 柱子
	_rect(img, 4, 13, 2, 26, Color("6d4a2a"))
	_rect(img, w - 7, 13, 2, 26, Color("6d4a2a"))
	# 柜台
	_rect(img, 3, 28, w - 6, 4, Color("a5723f"))
	_rect(img, 3, 28, w - 6, 1, Color("c98a4a"))
	_rect(img, 5, 32, w - 10, 9, Color("8a5f38"))
	_rect(img, 5, 32, w - 10, 1, Color("6d4a2a"))
	for x in range(7, w - 8, 6):
		_vline(img, x, 33, 8, Color("744b2c"))
	# 台面上的货物：种子袋
	for i in 3:
		var bx := 9 + i * 11
		_rect(img, bx, 24, 7, 5, Color("d9c58a"))
		_rect(img, bx + 1, 23, 5, 1, Color("b89a5e"))
		_put(img, bx + 3, 26, Color("6f9f4a"))
	# 招牌
	_rect(img, 16, 13, 22, 6, Color("4a3120"))
	_rect(img, 17, 14, 20, 4, Color("e6d3a3"))
	_put(img, 20, 15, Color("6f4a24"))
	_put(img, 27, 15, Color("6f4a24"))
	_put(img, 33, 15, Color("6f4a24"))
	return img


static func _make_well() -> Image:
	var img := Image.create(36, 34, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 18, 31, 14, 4, 0.28)
	# 石井圈
	_rect(img, 5, 18, 26, 12, Color("8d8879"))
	_rect(img, 6, 18, 24, 4, Color("b3ad9d"))
	for x in range(6, 30, 6):
		_vline(img, x, 19, 11, Color("716c60"))
	_rect(img, 8, 17, 20, 4, Color("2d3a44"))
	_rect(img, 9, 18, 18, 2, Color("4b94cf"))
	# 立柱与顶
	_rect(img, 5, 6, 2, 12, Color("6d4a2a"))
	_rect(img, 29, 6, 2, 12, Color("6d4a2a"))
	for row in range(0, 6):
		var inset := 2 + row
		_rect(img, 3 + inset, 3 + row, 30 - inset * 2, 1, Color("8a5a3a") if row % 2 == 0 else Color("a5723f"))
	_rect(img, 3, 8, 30, 1, Color("4a3120"))
	# 滑轮与水桶
	_rect(img, 17, 9, 2, 6, Color("c9c2ae"))
	_rect(img, 14, 15, 8, 6, Color("7a5230"))
	_rect(img, 15, 15, 6, 1, Color("b3ad9d"))
	return img


static func _make_sign() -> Image:
	var img := Image.create(20, 26, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 10, 24, 6, 2, 0.26)
	_rect(img, 9, 12, 2, 12, Color("6d4a2a"))
	_rect(img, 2, 4, 16, 9, Color("4a3120"))
	_rect(img, 3, 5, 14, 7, Color("c9a06a"))
	_rect(img, 3, 5, 14, 1, Color("e0bc86"))
	_rect(img, 5, 7, 10, 1, Color("7a5230"))
	_rect(img, 5, 9, 7, 1, Color("7a5230"))
	_put(img, 9, 11, Color("4a3120"))
	return img


static func _make_lamp() -> Image:
	var img := Image.create(12, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 6, 34, 4, 2, 0.26)
	_rect(img, 5, 12, 2, 22, Color("3f3a33"))
	_rect(img, 4, 9, 4, 4, Color("5d564b"))
	_rect(img, 3, 3, 6, 6, Color("2b2b2b"))
	_rect(img, 4, 4, 4, 4, Color("f6d27a"))
	_rect(img, 5, 4, 2, 2, Color("fff2b8"))
	_rect(img, 2, 2, 8, 1, Color("3f3a33"))
	_rect(img, 3, 8, 6, 1, Color("3f3a33"))
	return img


static func _make_bench() -> Image:
	var img := Image.create(26, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 13, 14, 10, 2, 0.24)
	_rect(img, 2, 6, 22, 2, Color("a5723f"))
	_rect(img, 2, 9, 22, 2, Color("8a5f38"))
	_rect(img, 4, 11, 2, 4, Color("4a3120"))
	_rect(img, 20, 11, 2, 4, Color("4a3120"))
	_rect(img, 4, 2, 2, 5, Color("6d4a2a"))
	_rect(img, 20, 2, 2, 5, Color("6d4a2a"))
	return img


static func _make_fountain() -> Image:
	var w := 48
	var h := 46
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 24, h - 4, 20, 5, 0.28)
	# 石砌外圈
	_disc(img, 24, h - 16, 22, 14, Color("8f897b"))
	_disc(img, 24, h - 17, 21, 13, Color("b8b2a2"))
	_disc(img, 24, h - 17, 18, 11, Color("a7a192"))
	# 水面
	_disc(img, 24, h - 17, 16, 9, Color("3f7fa8"))
	_disc(img, 24, h - 18, 15, 8, Color("4f97c4"))
	_disc(img, 22, h - 20, 6, 3, Color("8ec9e8"))
	# 中心水柱与碗
	_rect(img, 23, h - 34, 3, 16, Color("b8b2a2"))
	_rect(img, 23, h - 34, 1, 16, Color("d5cfc0"))
	_disc(img, 24, h - 34, 7, 3, Color("a7a192"))
	_disc(img, 24, h - 35, 6, 2, Color("cfc9ba"))
	_rect(img, 21, h - 40, 7, 5, Color("8ec9e8"))
	_rect(img, 22, h - 41, 5, 2, Color("c4e6f4"))
	_put(img, 20, h - 30, Color("c4e6f4"))
	_put(img, 28, h - 32, Color("c4e6f4"))
	return img


static func _make_flagpole() -> Image:
	var img := Image.create(18, 66, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 9, 64, 6, 2, 0.26)
	_rect(img, 4, 60, 10, 3, Color("a9a293"))
	_rect(img, 4, 60, 10, 1, Color("c9c2b0"))
	_rect(img, 8, 4, 2, 57, Color("c9c2b0"))
	_rect(img, 8, 4, 1, 57, Color("efefea"))
	_disc(img, 9, 3, 2, 2, Color("e0c070"))
	# 旗帜
	_rect(img, 10, 7, 8, 12, Color("b8453a"))
	_rect(img, 10, 8, 7, 3, Color("cf5a4a"))
	_rect(img, 10, 15, 7, 2, Color("9c342c"))
	_put(img, 9, 7, Color("8a2c24"))
	_put(img, 17, 9, Color("8a2c24"))
	_put(img, 17, 13, Color("8a2c24"))
	return img


static func _make_bike_rack() -> Image:
	var img := Image.create(32, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 16, 16, 13, 2, 0.22)
	_rect(img, 2, 13, 28, 2, Color("8f897b"))
	for i in 4:
		var x := 5 + i * 7
		_rect(img, x, 6, 1, 8, Color("7f8790"))
		_rect(img, x + 3, 6, 1, 8, Color("7f8790"))
		_rect(img, x, 5, 4, 1, Color("aab2ba"))
		_put(img, x + 1, 7, Color("5f676e"))
	return img


static func _make_planter() -> Image:
	var img := Image.create(22, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 11, 16, 8, 2, 0.22)
	_rect(img, 2, 8, 18, 8, Color("6b4a2a"))
	_rect(img, 3, 9, 16, 6, Color("8a5f38"))
	_rect(img, 2, 8, 18, 1, Color("a5723f"))
	_rect(img, 4, 7, 14, 2, Color("3f2a18"))
	var petals := [Color("e8b3c8"), Color("f2e9a8"), Color("e07070")]
	for i in 3:
		var x := 6 + i * 5
		_rect(img, x, 3, 1, 4, Color("4f8a46"))
		_rect(img, x - 1, 1, 3, 3, petals[i])
		_put(img, x, 2, Color("f6f0c8"))
	return img


static func _make_boat() -> Image:
	## 木船：船头朝右，甲板被沙子覆盖。
	var w := 188
	var h := 78
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 94, h - 6, 70, 6, 0.24)
	var cy := 42.0
	for x in w:
		var t := float(x) / float(w - 1)
		var half := 0.0
		if t < 0.08:
			half = 22.0 * (0.55 + 0.45 * t / 0.08)
		elif t < 0.80:
			half = 22.0
		else:
			half = 22.0 * (1.0 - pow((t - 0.80) / 0.20, 1.6))
		if half < 1.0:
			continue
		for y in range(int(cy - half), int(cy + half) + 1):
			var edge := absf(float(y) - cy) / maxf(half, 1.0)
			var c := Color("6b4526")
			if edge > 0.82:
				c = Color("4a2e18")
			elif edge < 0.22:
				c = Color("a5723f")
			_put(img, x, y, c)
	# 船舷
	for x in range(2, w - 4):
		var t2 := float(x) / float(w - 1)
		var hh := 22.0 if t2 < 0.8 else 22.0 * (1.0 - pow((t2 - 0.80) / 0.20, 1.6))
		if t2 < 0.08:
			hh = 22.0 * (0.55 + 0.45 * t2 / 0.08)
		_put(img, x, int(cy - hh) + 1, Color("b07f4a"))
		_put(img, x, int(cy + hh) - 1, Color("8a5f38"))
	# 甲板沙
	for x in range(10, w - 10):
		var t3 := float(x) / float(w - 1)
		var hh2 := 19.0 if t3 < 0.8 else 19.0 * (1.0 - pow((t3 - 0.80) / 0.20, 1.6))
		for y in range(int(cy - hh2) + 2, int(cy + hh2) - 1):
			var n := (_rnd(x, y, 963) - 0.5) * 0.10
			_put(img, x, y, _shift(Color("d9c08a"), n))
	# 沙堆与木纹
	for i in 26:
		var sx := 16 + int(_rnd(i, 3, 964) * 150.0)
		var sy := int(cy - 12) + int(_rnd(i, 7, 964) * 22.0)
		_put(img, sx, sy, Color("e8d6a8"))
		_put(img, sx + 1, sy, Color("bfa470"))
	for i in 5:
		var bx := 20 + i * 32
		_rect(img, bx, int(cy - 20), 1, 6, Color("8a5f38"))
		_rect(img, bx, int(cy + 15), 1, 6, Color("8a5f38"))
	# 船头尖角
	for i in 8:
		_put(img, w - 2 - i, int(cy) - int(i / 2.0), Color("6b4526"))
		_put(img, w - 2 - i, int(cy) + int(i / 2.0), Color("6b4526"))
	_outline(img, Color("3a2412"))
	return img


static func _make_bell() -> Image:
	## 木铎：深木铎架 + 三层铜铃（缩小版、木色更暖）。
	var w := 86
	var h := 126
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2
	_shadow(img, cx, h - 5, 30, 6, 0.26)
	_rect(img, 14, h - 22, 58, 18, Color("5a4a3a"))
	_rect(img, 14, h - 22, 58, 3, Color("8a7050"))
	_rect(img, 20, h - 6, 46, 5, Color("463a2c"))
	var body_top := 20
	var body_h := h - 40
	for y in range(body_top, body_top + body_h):
		var t := float(y - body_top) / float(body_h)
		var half := int(16.0 + 13.0 * t)
		_rect(img, cx - half, y, half * 2, 1, Color("4a3a2c"))
		_put(img, cx - half, y, Color("6b5540"))
		_put(img, cx - half + 1, y, Color("5a4636"))
		_put(img, cx + half - 1, y, Color("33261c"))
	for tier in 3:
		var ty := body_top + 14 + tier * 26
		var half2 := int(18.0 + 8.0 * float(tier) / 2.0)
		_rect(img, cx - half2, ty + 10, half2 * 2, 2, Color("2f2418"))
		for k in range(-2, 3):
			var bx := cx + k * 8
			_rect(img, bx - 2, ty, 5, 7, Color("a8763a"))
			_rect(img, bx - 2, ty, 5, 1, Color("d9a95a"))
			_put(img, bx + 1, ty + 3, Color("f0c878"))
	_rect(img, cx - 18, body_top - 6, 36, 7, Color("3a2c20"))
	_rect(img, cx - 21, body_top - 2, 42, 3, Color("5a4636"))
	_rect(img, cx - 12, 6, 24, 8, Color("4a3a2c"))
	_rect(img, cx - 2, 0, 4, 8, Color("6b5540"))
	_outline(img, Color("241a12"))
	return img


static func _make_cypress() -> Image:
	## 柏树：细高的圆锥，适合放在庭院里做序列。
	var w := 18
	var h := 50
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2
	_shadow(img, cx, h - 3, 6, 3, 0.24)
	_rect(img, cx - 1, h - 12, 3, 10, Color("4a3120"))
	for y in range(6, h - 8):
		var t := float(y - 6) / float(h - 14)
		var half := int(2.0 + 6.0 * pow(t, 0.7))
		for x in range(cx - half, cx + half + 1):
			var c := Color("2f5a34")
			if x < cx - half + 2:
				c = Color("4a7a44")
			elif x > cx + half - 2:
				c = Color("1f3f24")
			_put(img, x, y, c)
	for i in 7:
		var yy := 10 + i * 5
		var t2 := float(yy - 6) / float(h - 14)
		var hw := int(2.0 + 6.0 * pow(t2, 0.7))
		_put(img, cx - hw + 1, yy, Color("6a9a5a"))
		_put(img, cx + hw - 1, yy, Color("243f28"))
	_outline(img, Color("1a3320"))
	return img


static func _make_larch() -> Image:
	## 落叶松：秋季金黄的高瘦针叶树，用来做行道树列。
	var w := 22
	var h := 58
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := w / 2
	_shadow(img, cx, h - 3, 7, 3, 0.22)
	_rect(img, cx - 1, h - 14, 3, 12, Color("5a4026"))
	for y in range(4, h - 10):
		var t := float(y - 4) / float(h - 14)
		var half := int(2.0 + 8.0 * pow(t, 0.62))
		for x in range(cx - half, cx + half + 1):
			var c := Color("8a7434")
			if x < cx - half + 2:
				c = Color("b29a4c")
			elif x > cx + half - 2:
				c = Color("6a5a26")
			_put(img, x, y, c)
	for i in 9:
		var yy := 8 + i * 5
		var t2 := float(yy - 4) / float(h - 14)
		var hw := int(2.0 + 8.0 * pow(t2, 0.62))
		_put(img, cx - hw + 1, yy, Color("cbb45e"))
		_put(img, cx + hw - 1, yy, Color("5a4a20"))
	_outline(img, Color("3a3016"))
	return img


static func _make_pavilion() -> Image:
	## 凉亭：石台基 + 木柱 + 攒尖顶，放在右上角花园里。
	var w := 76
	var h := 68
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, w / 2, h - 4, 34, 6, 0.26)
	_rect(img, 4, h - 12, w - 8, 10, Color("b8b2a2"))
	_rect(img, 4, h - 12, w - 8, 2, Color("d9d2c0"))
	_rect(img, 8, h - 4, w - 16, 4, Color("9a9484"))
	for i in 4:
		var px := 10 + i * 18
		_rect(img, px, h - 34, 4, 24, Color("7a5a38"))
		_rect(img, px, h - 34, 1, 24, Color("9a7648"))
	_rect(img, 10, h - 22, w - 20, 2, Color("8a6a44"))
	_rect(img, 10, h - 20, w - 20, 1, Color("6a4a2e"))
	var cx := w / 2
	for y in range(10, h - 32):
		var t := float(y - 10) / float(h - 42)
		var half := int(8 + 30 * t)
		_rect(img, cx - half, y, half * 2, 1, Color("4f6b5a"))
		_put(img, cx - half, y, Color("6f8a72"))
		_put(img, cx + half - 1, y, Color("3a4f44"))
	_rect(img, cx - 3, 8, 6, 5, Color("3a4f44"))
	_rect(img, cx - 1, 4, 2, 6, Color("c8b06a"))
	_rect(img, 4, h - 34, w - 8, 3, Color("3a4f44"))
	_rect(img, 4, h - 34, w - 8, 1, Color("6f8a72"))
	_outline(img, Color("241f1a"))
	return img


static func _make_stele() -> Image:
	## 校训石：浅暖灰巨石，文字由 Label 叠在上面（比之前小一号）。
	var w := 142
	var h := 74
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 72, h - 4, 60, 5, 0.24)
	var heights: Array[int] = []
	for x in w:
		var t := float(x) / float(w - 1)
		var base := 40.0 + 18.0 * sin(PI * clampf(t, 0.0, 1.0))
		base += 5.0 * sin(t * 15.0) + 3.0 * sin(t * 37.0 + 1.0)
		heights.append(int(base))
	for x in w:
		var hh := heights[x]
		for y in range(h - hh, h):
			var t2 := float(y - (h - hh)) / float(maxi(hh, 1))
			var c := Color("d8d3c6")
			if t2 < 0.22:
				c = Color("ebe6da")
			elif t2 > 0.75:
				c = Color("b9b4a7")
			if x > w - 22:
				c = c.darkened(0.10)
			_put(img, x, y, c)
		_put(img, x, h - 2, Color("8a857a"))
	for i in 24:
		var sx := 8 + int(_rnd(i, 3, 971) * 126.0)
		var sy := h - 24 + int(_rnd(i, 7, 971) * 18.0)
		_put(img, sx, sy, Color("c6c1b4"))
		_put(img, sx + 1, sy, Color("e8e4d8"))
	_outline(img, Color("726d62"))
	return img


static func _make_crate() -> Image:
	var img := Image.create(18, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_shadow(img, 9, 14, 7, 2, 0.24)
	_rect(img, 2, 3, 14, 11, Color("6b4a2a"))
	_rect(img, 3, 4, 12, 9, Color("a5723f"))
	_rect(img, 3, 4, 12, 1, Color("c98a4a"))
	_rect(img, 3, 8, 12, 1, Color("6b4a2a"))
	_vline(img, 9, 4, 9, Color("6b4a2a"))
	return img


# =====================================================================
# 图标（HUD）
# =====================================================================

static func _make_icon(kind: String) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"hoe":
			# 木柄斜线
			for i in 9:
				_put(img, 4 + i, 12 - i, Color("8a5f38"))
				_put(img, 5 + i, 12 - i, Color("6b4a2a"))
			_rect(img, 2, 10, 5, 3, Color("9aa0a6"))
			_rect(img, 2, 10, 5, 1, Color("c8cdd2"))
			_rect(img, 2, 12, 5, 1, Color("6f757b"))
		"watering_can":
			_rect(img, 3, 7, 8, 6, Color("7fa8c8"))
			_rect(img, 3, 7, 8, 1, Color("b5d2e8"))
			_rect(img, 3, 12, 8, 1, Color("5a7f9c"))
			for i in 4:
				_put(img, 11 + i, 7 - i, Color("8fb6d4"))
			_put(img, 14, 3, Color("d8e8f2"))
			_put(img, 15, 3, Color("d8e8f2"))
			_rect(img, 4, 5, 1, 2, Color("5a7f9c"))
			_rect(img, 9, 5, 1, 2, Color("5a7f9c"))
			_rect(img, 4, 4, 6, 1, Color("5a7f9c"))
		"seeds":
			_rect(img, 4, 6, 9, 9, Color("d9c58a"))
			_rect(img, 4, 6, 9, 1, Color("efe0b0"))
			_rect(img, 4, 14, 9, 1, Color("b89a5e"))
			_rect(img, 5, 4, 7, 3, Color("b89a5e"))
			_put(img, 7, 8, Color("6f9f4a"))
			_put(img, 10, 10, Color("6f9f4a"))
			_put(img, 6, 11, Color("6f9f4a"))
			_rect(img, 6, 7, 5, 1, Color("8c6f3d"))
		"coin":
			_disc(img, 8, 8, 6, 6, Color("c99a2e"))
			_disc(img, 8, 8, 5, 5, Color("f0c64a"))
			_disc(img, 8, 8, 3, 3, Color("e0b23a"))
			_put(img, 6, 5, Color("fff2b8"))
			_put(img, 7, 5, Color("fff2b8"))
		"energy":
			_rect(img, 7, 2, 3, 5, Color("f0c64a"))
			_rect(img, 4, 7, 9, 3, Color("f0c64a"))
			_rect(img, 6, 10, 3, 4, Color("f0c64a"))
			_rect(img, 7, 3, 1, 4, Color("fff2b8"))
		_:
			_rect(img, 3, 3, 10, 10, Color("888888"))
	return img

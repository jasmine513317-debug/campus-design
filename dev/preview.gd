extends Node2D
## 开发用素材预览：把图集、树、角色、作物、道具、图标铺开截图。

const OUT := "res://.shots/art.png"

var _tex: Texture2D


func _ready() -> void:
	_tex = PixelArt.atlas()
	queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.shots"))
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT))
	get_tree().quit()


func _draw() -> void:
	var x := 12.0
	var y := 12.0
	# 地块 4x
	var tiles := ["grass0", "grass1", "grass2", "grass3", "lawn", "dirt0", "stone0", "plaza", "soil0", "soil1", "water0", "hedge"]
	for t: String in tiles:
		draw_texture_rect_region(_tex, Rect2(x, y, 64, 64), PixelArt.cell(t))
		x += 70
	# 树 3x
	x = 12.0
	y = 100.0
	for kind in ["oak", "fruit", "blossom", "pine", "bush"]:
		var tex := PixelArt.tree(kind)
		draw_texture_rect(tex, Rect2(x, y, tex.get_width() * 3, tex.get_height() * 3), false)
		x += tex.get_width() * 3 + 16
	# 角色 3x
	x = 12.0
	y = 250.0
	for dir in ["down", "up", "left", "right"]:
		for frame in 3:
			draw_texture_rect(PixelArt.character(dir, frame), Rect2(x, y, 48, 72), false)
			x += 54
		x += 16
	# 作物 5x
	x = 12.0
	y = 350.0
	for stage in 4:
		draw_texture_rect(PixelArt.crop(stage, Color("6aa32b"), Color("e8d48a"), stage == 3), Rect2(x, y, 80, 80), false)
		x += 92
	# 道具 2x
	x = 12.0
	y = 450.0
	for kind in ["bin", "well", "sign", "lamp", "bench", "crate"]:
		var tex := PixelArt.prop(kind)
		draw_texture_rect(tex, Rect2(x, y, tex.get_width() * 2, tex.get_height() * 2), false)
		x += tex.get_width() * 2 + 20
	# 图标 4x
	x = 12.0
	y = 560.0
	for kind in ["hoe", "watering_can", "seeds", "coin", "energy"]:
		draw_texture_rect(PixelArt.icon(kind), Rect2(x, y, 64, 64), false)
		x += 76

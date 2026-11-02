extends SceneTree
## 快速自检像素材质是否生成成功。

func _init() -> void:
	var t := PixelArt.atlas()
	print("atlas=", t.get_size())
	for name in ["grass0", "dirt0", "soil1", "water0", "roof_shingle", "wall_plaster"]:
		print("  cell ", name, "=", PixelArt.cell(name))
	print("tree oak=", PixelArt.tree("oak").get_size())
	print("tree pine=", PixelArt.tree("pine").get_size())
	print("char down0=", PixelArt.character("down", 0).get_size())
	print("crop stage3=", PixelArt.crop(3, Color("6aa32b"), Color("e8d48a"), true).get_size())
	print("prop bin=", PixelArt.prop("bin").get_size())
	print("icon hoe=", PixelArt.icon("hoe").get_size())
	quit()

extends Node2D
## The gate is an overhead arch; only its two pillars collide.
const TILE := 16
var gate := Rect2i()
func _draw() -> void:
	draw_set_transform(-position)
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

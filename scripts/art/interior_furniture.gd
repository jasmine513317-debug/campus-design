extends Node2D
## Foot-anchored indoor furniture, sharing the actors' Y-sorted plane.
var kind := "desk"
var anchor := Vector2.ZERO
func _draw() -> void:
	draw_set_transform(-position)
	match kind:
		"desk": _draw_desk(anchor, "")
		"podium": _draw_podium(anchor)
		"bench": _draw_bench(anchor)
		"vending": _draw_vending_machine(Rect2(anchor, Vector2(46, 96)))
		"water": _draw_water_fountain(Rect2(anchor, Vector2(38, 82)))

func _draw_podium(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(4, 18), Vector2(48, 24)), Color("51483e", 0.25))
	draw_rect(Rect2(pos + Vector2(8, 12), Vector2(40, 22)), Color("6e5137"))
	draw_rect(Rect2(pos + Vector2(4, 6), Vector2(48, 12)), Color("9c7547"))
	draw_rect(Rect2(pos + Vector2(7, 7), Vector2(42, 3)), Color("c09a61"))


func _draw_desk(pos: Vector2, book: String) -> void:
	draw_rect(Rect2(pos + Vector2(4, 30), Vector2(52, 19)), Color("53483b", 0.23))
	draw_rect(Rect2(pos + Vector2(8, 20), Vector2(4, 24)), Color("68503a"))
	draw_rect(Rect2(pos + Vector2(48, 20), Vector2(4, 24)), Color("574332"))
	draw_rect(Rect2(pos, Vector2(60, 22)), Color("624a35"))
	draw_rect(Rect2(pos + Vector2(2, 1), Vector2(56, 16)), Color("a57949"))
	draw_rect(Rect2(pos + Vector2(4, 2), Vector2(50, 3)), Color("c0945d"))
	draw_rect(Rect2(pos + Vector2(17, 4), Vector2(18, 9)), Color("dfd2b0"))
	draw_rect(Rect2(pos + Vector2(18, 5), Vector2(15, 1)), Color("81775f"))
	draw_rect(Rect2(pos + Vector2(18, 8), Vector2(12, 1)), Color("81775f"))
	# Chair just south of the desk gives every seat a visible front face.
	draw_rect(Rect2(pos + Vector2(20, 25), Vector2(22, 6)), Color("554438"))
	draw_rect(Rect2(pos + Vector2(22, 26), Vector2(18, 3)), Color("907052"))


func _draw_vending_machine(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color("40382f", 0.25))
	draw_rect(rect, Color("4e5f5d"))
	draw_rect(rect.grow(-4), Color("708883"))
	draw_rect(Rect2(rect.position + Vector2(7, 8), Vector2(rect.size.x - 14, 50)), Color("304545"))
	for i in 3:
		for row in 3:
			var snack := Rect2(rect.position + Vector2(10 + i * 9, 13 + row * 13), Vector2(6, 8))
			draw_rect(snack, [Color("d59a4f"), Color("b96855"), Color("d8bf6f")][(i + row) % 3])
	draw_rect(Rect2(rect.end.x - 14, rect.position.y + 10, 7, 43), Color("a8bbb0"))
	draw_rect(Rect2(rect.position.x + 9, rect.end.y - 25, rect.size.x - 18, 13), Color("596e68"))


func _draw_water_fountain(rect: Rect2) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 7), rect.size), Color("40382f", 0.22))
	draw_rect(Rect2(rect.position + Vector2(7, 4), Vector2(rect.size.x - 14, rect.size.y - 8)), Color("8c9690"))
	draw_rect(Rect2(rect.position + Vector2(10, 7), Vector2(5, rect.size.y - 14)), Color("cbd0c3"))
	draw_rect(Rect2(rect.position + Vector2(8, 4), Vector2(rect.size.x - 16, 8)), Color("b3b6a8"))
	draw_rect(Rect2(rect.position + Vector2(13, 16), Vector2(17, 4)), Color("525e5a"))
	draw_rect(Rect2(rect.position + Vector2(18, 18), Vector2(8, 9)), Color("74a0a4"))


func _draw_bench(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(4, 20), Vector2(74, 14)), Color("524538", 0.22))
	draw_rect(Rect2(pos + Vector2(8, 4), Vector2(62, 7)), Color("855d3a"))
	draw_rect(Rect2(pos + Vector2(8, 4), Vector2(62, 2)), Color("bd8c56"))
	draw_rect(Rect2(pos + Vector2(8, 12), Vector2(62, 6)), Color("735036"))
	draw_rect(Rect2(pos + Vector2(13, 18), Vector2(4, 12)), Color("4e4035"))
	draw_rect(Rect2(pos + Vector2(60, 18), Vector2(4, 12)), Color("4e4035"))

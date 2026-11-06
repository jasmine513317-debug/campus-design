extends Node2D
## Sparse pixel leaves, butterflies and highlights, drawn only near the camera.
var world: Node2D
var _time := 0.0
var _tick := 0.0

func _process(delta: float) -> void:
	_time += delta
	_tick += delta
	if _tick > 0.12:
		_tick = 0
		queue_redraw()

func _draw() -> void:
	if world == null:
		return
	var view := get_viewport_rect()
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var visible := Rect2(inverse * view.position, view.size / get_viewport().get_canvas_transform().get_scale()).grow(80)
	for i in 42:
		var x := 400.0 + fmod(i * 197.0 + _time * 9, 5550)
		var y := 400.0 + fmod(i * 131.0 + _time * 6, 2050)
		var pos := Vector2(x + sin(_time + i) * 9, y).floor()
		if not visible.has_point(pos):
			continue
		var c := Color("e3bb76", 0.7) if i % 3 else Color("f4d4bb", 0.75)
		draw_rect(Rect2(pos, Vector2(2, 1)), c)
		draw_rect(Rect2(pos + Vector2(1, 1), Vector2(2, 1)), c)
	for i in 8:
		var anchor := Vector2(2660 + i * 142, 2135 + (i % 3) * 66)
		var pos := (anchor + Vector2(sin(_time * 0.8 + i) * 22, cos(_time * 1.2 + i) * 10)).floor()
		if not visible.has_point(pos):
			continue
		var wing := 2 if int(_time * 7 + i) % 2 else 1
		draw_rect(Rect2(pos - Vector2(wing, 0), Vector2(wing * 2 + 1, 2)), Color("f8df9b"))
		draw_rect(Rect2(pos, Vector2(1, 3)), Color("816650"))
	var pond: Rect2i = world._pond
	var center := Vector2(pond.get_center() * 16)
	for i in 10:
		var pos := (center + Vector2(sin(i * 13.2) * 45, cos(i * 7.3) * 64)).floor()
		if visible.has_point(pos):
			var length := 2 + int(fmod(_time * 3 + i * 3, 8))
			draw_line(pos, pos + Vector2(length, 0), Color("c3e9e4", 0.6), 1)

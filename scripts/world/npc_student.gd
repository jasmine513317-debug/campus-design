extends Node2D
## 校园 NPC：沿路点循环行走，偶尔停下；可以按空格搭话。

var route: Array = []
## Outdoor routes use tiles; interiors use pixel coordinates.
var route_scale := 16.0
var shirt: Color = Color("c05a4a")
var hair: Color = Color("3a2a1e")
var speed := 46.0

var _idx := 0
var _wait := 0.0
var _sprite: Sprite2D
var _walk := 0.0
var _dir := "down"
var _frame := -1
var _last_dir := ""

const SKIN := Color("e9b489")

const LINES := [
	"早八在 C 楼，得快点走了。",
	"体育馆二楼靠窗的位置最好。",
	"今天操场有体测，去晚了要排队。",
	"实验楼那边的樱花开了。",
	"听说国际学院今晚有讲座。",
	"食堂二楼的麻辣香锅还不错。",
]


func _ready() -> void:
	add_to_group("npcs")
	_sprite = Sprite2D.new()
	_sprite.position = Vector2(0, -12)
	_sprite.centered = true
	add_child(_sprite)
	_apply(0)


func _process(delta: float) -> void:
	if route.is_empty():
		return
	if _wait > 0.0:
		_wait -= delta
		_apply(0)
		return
	var target := Vector2(route[_idx]) * route_scale
	var to := target - global_position
	if to.length() < 4.0:
		_idx = (_idx + 1) % route.size()
		_wait = 0.6 + float((_idx * 37) % 18) * 0.1
		return
	if absf(to.x) > absf(to.y):
		_dir = "right" if to.x > 0.0 else "left"
	else:
		_dir = "down" if to.y > 0.0 else "up"
	global_position = global_position.move_toward(target, speed * delta)
	_walk += delta * 6.0
	_apply(1 + int(_walk) % 2)


func _apply(frame: int) -> void:
	if frame == _frame and _dir == _last_dir:
		return
	_frame = frame
	_last_dir = _dir
	_sprite.texture = PixelArt.person(_dir, frame, shirt, hair, SKIN, true)


func greet() -> String:
	return LINES[int(absf(global_position.x + global_position.y)) % LINES.size()]

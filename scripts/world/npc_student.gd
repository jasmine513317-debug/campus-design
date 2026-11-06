extends CharacterBody2D
## 校园 NPC：沿路点循环行走，偶尔停下；可以按空格搭话。

var route: Array = []
var route_scale := 1.0
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
	collision_layer = 2
	collision_mask = 3
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 8)
	collider.shape = shape
	collider.position = Vector2(0, 2)
	add_child(collider)
	_sprite = Sprite2D.new()
	_sprite.position = Vector2(0, -12)
	_sprite.centered = true
	add_child(_sprite)
	_apply(0)


func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO
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
	velocity = to.normalized() * minf(speed, to.length() / delta)
	# Keep to one side when meeting another student on a shared path.
	var forward := to.normalized()
	for other: Node2D in get_tree().get_nodes_in_group("npcs"):
		if other == self:
			continue
		var separation := other.global_position - global_position
		if separation.length() < 30 and separation.dot(forward) > 0 and absf(separation.cross(forward)) < 15:
			velocity += Vector2(forward.y, -forward.x) * speed * 0.8
			velocity = velocity.limit_length(speed)
			break
	move_and_slide()
	_walk += delta * 6.0
	_apply(1 + int(_walk) % 2)


func _apply(frame: int) -> void:
	if frame == _frame and _dir == _last_dir:
		return
	_frame = frame
	_last_dir = _dir
	_sprite.texture = PixelArt.person(_dir, frame, shirt, hair, SKIN, true)


func greet() -> String:
	_wait = 1.5
	return LINES[int(absf(global_position.x + global_position.y)) % LINES.size()]


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 6, Color("334839", 0.22))

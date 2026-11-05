extends CharacterBody2D
## 玩家：校园里走动、奔跑、和道具/NPC 互动。画面上的角色只是 PixelArt 生成的小图。

const SPEED := 104.0
const RUN_SPEED := 168.0
const TILE := 16

@export var estate_path: NodePath

var facing := Vector2.DOWN
var facing_name := "down"
var touch_direction := Vector2.ZERO

var _estate: Node
var _camera: Camera2D
var _sprite: Sprite2D
var _walk := 0.0
var _frame := -1
var _last_dir := ""
var _dust: CPUParticles2D

const SHIRT := Color("3f76b5")
const HAIR := Color("3a2a1e")
const SKIN := Color("e9b489")


func _ready() -> void:
	add_to_group("player")
	_estate = get_node_or_null(estate_path)
	if _estate == null:
		_estate = get_parent().get_node_or_null("World")
	if SceneFlow != null:
		var handoff: Variant = SceneFlow.consume_player_spawn()
		if handoff is Vector2:
			global_position = handoff
	_build_visual()
	_setup_camera()
	_build_particles()
	Messages.say("WASD 移动 · Shift 奔跑 · 空格 互动 · T 跳到清晨 · F1 隐藏提示")


func _physics_process(delta: float) -> void:
	var input := (Input.get_vector("move_left", "move_right", "move_up", "move_down") + touch_direction).limit_length(1.0)
	var speed := RUN_SPEED if Input.is_action_pressed("run") else SPEED
	velocity = input * speed
	if input.length() > 0.05:
		_update_facing(input)
		_walk += delta * (speed / 26.0)
		_set_frame(1 + int(_walk) % 2)
	else:
		_walk = 0.0
		_set_frame(0)
	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not event.is_echo():
		_interact()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_T:
			GameClock.sleep_until_morning()
			Messages.say("第 %d 天，清晨的校园很安静。" % GameClock.day)


func _update_facing(input: Vector2) -> void:
	if absf(input.x) > absf(input.y):
		facing = Vector2(signf(input.x), 0)
		facing_name = "right" if input.x > 0.0 else "left"
	else:
		facing = Vector2(0, signf(input.y))
		facing_name = "down" if input.y > 0.0 else "up"


func _set_frame(frame: int) -> void:
	if frame == _frame and facing_name == _last_dir:
		return
	_frame = frame
	_last_dir = facing_name
	_sprite.texture = PixelArt.person(facing_name, frame, SHIRT, HAIR, SKIN, true)


func _interact() -> void:
	if SceneFlow.transitioning:
		return
	var npc := _npc_near()
	if npc != null and npc.has_method("greet"):
		Messages.say(npc.greet())
		return
	if _estate != null and _estate.has_method("try_interact"):
		var msg: String = _estate.try_interact(global_position + facing * 20.0)
		if msg != "":
			Messages.say(msg)
			return
	Messages.say("这里没什么特别的。")


func interact() -> void:
	## HUD 触屏动作键复用同一套最近目标交互逻辑。
	_interact()


func interaction_hint() -> String:
	if _npc_near() != null:
		return "打个招呼"
	if _estate != null and _estate.has_method("interaction_hint"):
		return _estate.interaction_hint(global_position + facing * 20.0)
	return ""


func _npc_near() -> Node2D:
	var best: Node2D = null
	var best_dist := 56.0
	for node: Node in get_tree().get_nodes_in_group("npcs"):
		var npc := node as Node2D
		if npc == null:
			continue
		var d := npc.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best = npc
	return best


func _build_visual() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = PixelArt.person("down", 0, SHIRT, HAIR, SKIN, true)
	_sprite.position = Vector2(0, -12)
	_sprite.centered = true
	add_child(_sprite)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 8)
	collision.shape = shape
	collision.position = Vector2(0, 2)
	add_child(collision)


func _setup_camera() -> void:
	_camera = get_node_or_null("Camera2D")
	if _camera == null:
		return
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 7.0
	_camera.limit_smoothed = true
	if _estate != null and _estate.has_method("get_world_rect"):
		var r: Rect2 = _estate.get_world_rect()
		_camera.limit_left = int(r.position.x)
		_camera.limit_top = int(r.position.y)
		_camera.limit_right = int(r.end.x)
		_camera.limit_bottom = int(r.end.y)


func _build_particles() -> void:
	_dust = CPUParticles2D.new()
	_dust.amount = 6
	_dust.lifetime = 0.4
	_dust.one_shot = true
	_dust.emitting = false
	_dust.explosiveness = 0.9
	_dust.direction = Vector2(0, -1)
	_dust.spread = 60.0
	_dust.initial_velocity_min = 8.0
	_dust.initial_velocity_max = 24.0
	_dust.gravity = Vector2(0, 90)
	_dust.scale_amount_min = 0.8
	_dust.scale_amount_max = 1.6
	_dust.texture = PixelArt.dot_texture()
	add_child(_dust)


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 6.0, Color(0.04, 0.07, 0.04, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

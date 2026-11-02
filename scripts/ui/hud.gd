extends CanvasLayer
## 校园 HUD：右上角日历时钟，左下角当前位置，左上角操作提示，底部中央提示条。

const C_PANEL := Color(0.10, 0.12, 0.08, 0.94)
const C_BORDER := Color(0.52, 0.41, 0.24)
const C_GOLD := Color(0.96, 0.82, 0.44)
const C_INK := Color(0.95, 0.92, 0.81)
const C_MUTED := Color(0.70, 0.71, 0.58)
const C_PAPER := Color("e7d6af")
const C_PAPER_LIGHT := Color("f1e5c8")
const C_PAPER_EDGE := Color("93784e")
const C_PAPER_INK := Color("463b31")

var _root: Control
var _clock_label: Label
var _day_label: Label
var _weather_label: Label
var _wind_label: Label
var _loc_label: Label
var _dial: Control
var _map_control: Control
var _toast_panel: PanelContainer
var _toast_label: Label
var _hint_panel: PanelContainer
var _interaction_panel: PanelContainer
var _interaction_label: Label
var _joystick: Control
var _action_button: Button
var _action_label: Control
var _layout_data: Dictionary = {}
var _toast_timer := 0.0
var _loc_timer := 0.0
var _map_timer := 0.0
var _stick_active := false
var _stick_mouse := false
var _stick_touch_id := -1
var _stick_vector := Vector2.ZERO
var _dial_hour := 6
var _dial_minute := 0


func _ready() -> void:
	_build()
	GameClock.time_changed.connect(_on_time)
	GameClock.day_started.connect(_on_day)
	Messages.message.connect(_toast)
	_on_day(GameClock.day, GameClock.season_id())
	_on_time(GameClock.hour(), GameClock.minute())


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer < 0.6:
			_toast_panel.modulate.a = clampf(_toast_timer / 0.6, 0.0, 1.0)
		if _toast_timer <= 0.0:
			_toast_panel.visible = false
	_loc_timer += delta
	if _loc_timer > 0.35:
		_loc_timer = 0.0
		_update_location()
	_map_timer += delta
	if _map_timer > 0.18:
		_map_timer = 0.0
		if _map_control != null:
			_map_control.queue_redraw()
		_update_interaction_hint()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_load_minimap_data()
	_build_minimap()
	_build_clock()
	_build_location()
	_build_hint()
	_build_toast()
	_build_interaction_hint()
	_build_touch_controls()


func _build_clock() -> void:
	var panel := _paper_panel(1.0, 0.0, -282.0, 16.0, 266.0, 132.0)
	var content := _content(panel, 9)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	content.add_child(row)
	var dial_stack := VBoxContainer.new()
	dial_stack.add_theme_constant_override("separation", 0)
	row.add_child(dial_stack)
	_dial = Control.new()
	_dial.custom_minimum_size = Vector2(58, 61)
	_dial.draw.connect(func(): _draw_clock_dial())
	dial_stack.add_child(_dial)
	_clock_label = _label("06:00", 19, C_PAPER_INK)
	_clock_label.add_theme_constant_override("outline_size", 0)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dial_stack.add_child(_clock_label)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)
	_day_label = _label("春季 · 第 1 天", 12, C_PAPER_INK)
	_day_label.add_theme_constant_override("outline_size", 0)
	info.add_child(_day_label)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color("bca47b")
	info.add_child(divider)
	_weather_label = _label("晴朗 · 18°C", 12, C_PAPER_INK)
	_weather_label.add_theme_constant_override("outline_size", 0)
	info.add_child(_weather_label)
	_wind_label = _label("微风  ↘  东南风", 10, Color("76634c"))
	_wind_label.add_theme_constant_override("outline_size", 0)
	info.add_child(_wind_label)
	var place := _label("校园 · 中心城区", 10, Color("76634c"))
	place.add_theme_constant_override("outline_size", 0)
	info.add_spacer(false)
	info.add_child(place)


func _load_minimap_data() -> void:
	var file := FileAccess.open("res://data/estate.json", FileAccess.READ)
	if file == null:
		return
	_layout_data = JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()


func _build_minimap() -> void:
	_map_control = Control.new()
	_map_control.anchor_left = 1.0
	_map_control.anchor_right = 1.0
	_map_control.anchor_top = 0.0
	_map_control.anchor_bottom = 0.0
	_map_control.offset_left = -492.0
	_map_control.offset_top = 16.0
	_map_control.offset_right = -300.0
	_map_control.offset_bottom = 132.0
	_map_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_control.draw.connect(func(): _draw_minimap())
	_root.add_child(_map_control)


func _draw_minimap() -> void:
	if _map_control == null:
		return
	var size := _map_control.size
	_map_control.draw_rect(Rect2(Vector2.ZERO, size), C_PAPER_LIGHT)
	_map_control.draw_rect(Rect2(Vector2.ZERO, size), C_PAPER_EDGE, false, 2.0)
	var font := ThemeDB.fallback_font
	_map_control.draw_string(font, Vector2(7, 14), "校 园 地 图", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_PAPER_INK)
	var map_rect := Rect2(7, 21, size.x - 14, size.y - 28)
	var active_estate := get_tree().get_first_node_in_group("estate")
	if active_estate != null and active_estate.has_method("get_world_rect"):
		var world_bounds: Rect2 = active_estate.get_world_rect()
		if world_bounds.size.x < 1000.0:
			var indoor_player := get_tree().get_first_node_in_group("player") as Node2D
			_draw_indoor_minimap(map_rect, indoor_player)
			return
	_map_control.draw_rect(map_rect, Color("727a4d"))
	var scale := Vector2(map_rect.size.x / 400.0, map_rect.size.y / 180.0)
	var campus: Array = _layout_data.get("campus", [18, 14, 364, 142])
	_map_control.draw_rect(_map_data_rect(campus, map_rect, scale), Color("7d8151"))
	var garden: Array = _layout_data.get("garden", [0, 0, 0, 0])
	_map_control.draw_rect(_map_data_rect(garden, map_rect, scale), Color("8b8a58"))
	var track: Array = _layout_data.get("track", [0, 0, 0, 0])
	_map_control.draw_rect(_map_data_rect(track, map_rect, scale), Color("9c5f50"))
	for court: Array in _layout_data.get("courts", []):
		_map_control.draw_rect(_map_data_rect(court, map_rect, scale), Color("5d8190"))
	var pond: Array = _layout_data.get("pond", [0, 0, 0, 0])
	_map_control.draw_rect(_map_data_rect(pond, map_rect, scale), Color("65a3b5"))
	for path: Array in _layout_data.get("paths", []):
		_map_control.draw_rect(_map_data_rect(path, map_rect, scale), Color("777080"))
	for building: Dictionary in _layout_data.get("buildings", []):
		var building_color := Color("c4aa7d") if str(building.get("style", "")) in ["gable", "brick"] else Color("b7b6a5")
		for part: Array in building.get("parts", []):
			_map_control.draw_rect(_map_data_rect(part, map_rect, scale), building_color)
	_map_control.draw_rect(map_rect, Color("403b37"), false, 1.0)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		var world_cell := player.global_position / 16.0
		var dot := map_rect.position + Vector2(world_cell.x * scale.x, world_cell.y * scale.y)
		_map_control.draw_circle(dot, 3.2, Color("f2d16b"))
		_map_control.draw_arc(dot, 4.2, 0.0, TAU, 12, Color("4f463a"), 1.0)


func _draw_indoor_minimap(outer: Rect2, player: Node2D) -> void:
	_map_control.draw_rect(Rect2(Vector2.ZERO, _map_control.size), C_PAPER_LIGHT)
	_map_control.draw_rect(Rect2(Vector2.ZERO, _map_control.size), C_PAPER_EDGE, false, 2.0)
	var font := ThemeDB.fallback_font
	_map_control.draw_string(font, Vector2(7, 14), "教学楼室内", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, C_PAPER_INK)
	var map_h := outer.size.y
	var map_w := minf(outer.size.x, map_h * 800.0 / 480.0)
	var map_rect := Rect2(outer.position + Vector2((outer.size.x - map_w) * 0.5, 0), Vector2(map_w, map_h))
	var scale := Vector2(map_w / 800.0, map_h / 480.0)
	_map_control.draw_rect(map_rect, Color("665d50"))
	_map_control.draw_rect(Rect2(map_rect.position + Vector2(24, 24) * scale, Vector2(752, 432) * scale), Color("d1c09d"))
	_map_control.draw_rect(Rect2(map_rect.position + Vector2(54, 48) * scale, Vector2(316, 226) * scale), Color("c6b392"))
	_map_control.draw_rect(Rect2(map_rect.position + Vector2(430, 48) * scale, Vector2(316, 226) * scale), Color("c0b393"))
	_map_control.draw_rect(Rect2(map_rect.position + Vector2(54, 290) * scale, Vector2(692, 144) * scale), Color("a99b86"))
	_map_control.draw_rect(Rect2(map_rect.position + Vector2(388, 48) * scale, Vector2(24, 230) * scale), Color("94846e"))
	_map_control.draw_rect(Rect2(map_rect.position + Vector2(356, 430) * scale, Vector2(88, 28) * scale), Color("71898a"))
	_map_control.draw_rect(map_rect, Color("51483e"), false, 1.0)
	if player != null:
		var dot := map_rect.position + player.global_position * scale
		_map_control.draw_circle(dot, 3.0, Color("f2d16b"))
		_map_control.draw_arc(dot, 4.0, 0.0, TAU, 12, Color("4f463a"), 1.0)


func _map_data_rect(values: Array, map_rect: Rect2, scale: Vector2) -> Rect2:
	return Rect2(
		map_rect.position + Vector2(float(values[0]) * scale.x, float(values[1]) * scale.y),
		Vector2(float(values[2]) * scale.x, float(values[3]) * scale.y)
	)


func _draw_clock_dial() -> void:
	if _dial == null:
		return
	var center := Vector2(29.0, 29.0)
	_dial.draw_circle(center, 25.0, Color("d8c69e"))
	_dial.draw_circle(center, 22.0, Color("f3e8cb"))
	# Sun arc from sunrise to sunset, with the moon marker outside daylight.
	_dial.draw_arc(center, 24.0, PI, TAU, 24, Color("a38b64"), 2.0, false)
	for i in 9:
		var a := PI + PI * float(i) / 8.0
		var inner := center + Vector2(cos(a), sin(a)) * 20.0
		var outer := center + Vector2(cos(a), sin(a)) * (23.0 if i % 2 == 0 else 21.0)
		_dial.draw_line(inner, outer, Color("877251"), 1.0, false)
	var day_progress := clampf((float(_dial_hour) + float(_dial_minute) / 60.0 - 6.0) / 20.0, 0.0, 1.0)
	var marker_angle := PI + day_progress * PI
	var marker := center + Vector2(cos(marker_angle), sin(marker_angle)) * 24.0
	if _dial_hour >= 6 and _dial_hour < 18:
		_dial.draw_circle(marker, 4.0, Color("c38b37"))
		_dial.draw_circle(marker + Vector2(-1, -1), 1.5, Color("f1d77f"))
	else:
		_dial.draw_circle(marker, 4.0, Color("74839a"))
		_dial.draw_circle(marker + Vector2(1.5, -1.2), 3.1, Color("f3e8cb"))
	var clock_angle := -PI / 2.0 + (float(_dial_hour % 12) + float(_dial_minute) / 60.0) * TAU / 12.0
	_dial.draw_line(center, center + Vector2(cos(clock_angle), sin(clock_angle)) * 9.0, C_PAPER_INK, 2.0, false)
	var minute_angle := -PI / 2.0 + float(_dial_minute) * TAU / 60.0
	_dial.draw_line(center, center + Vector2(cos(minute_angle), sin(minute_angle)) * 15.0, C_PAPER_INK, 1.0, false)
	_dial.draw_circle(center, 2.0, Color("8a633a"))


func _build_location() -> void:
	var panel := _panel(0.0, 1.0, 164.0, -48.0, 210.0, 34.0)
	var content := _content(panel, 6)
	_loc_label = _label("当前位置：校园", 11, C_INK)
	_loc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_loc_label)


func _build_interaction_hint() -> void:
	_interaction_panel = PanelContainer.new()
	_interaction_panel.visible = false
	_interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interaction_panel.add_theme_stylebox_override("panel", _flat(C_PAPER_LIGHT, C_PAPER_EDGE, 2))
	_interaction_panel.custom_minimum_size = Vector2(122, 30)
	_root.add_child(_interaction_panel)
	var content := _content(_interaction_panel, 5)
	_interaction_label = _label("查看 · 空格", 11, C_PAPER_INK)
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_interaction_label)


func _build_touch_controls() -> void:
	_joystick = Control.new()
	_joystick.anchor_left = 0.0
	_joystick.anchor_right = 0.0
	_joystick.anchor_top = 1.0
	_joystick.anchor_bottom = 1.0
	_joystick.offset_left = 20.0
	_joystick.offset_top = -154.0
	_joystick.offset_right = 154.0
	_joystick.offset_bottom = -20.0
	_joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	_joystick.draw.connect(func(): _draw_joystick())
	_joystick.gui_input.connect(_on_joystick_event.bind(_joystick))
	_root.add_child(_joystick)
	_action_button = Button.new()
	_action_button.text = ""
	_action_button.anchor_left = 1.0
	_action_button.anchor_right = 1.0
	_action_button.anchor_top = 1.0
	_action_button.anchor_bottom = 1.0
	_action_button.offset_left = -116.0
	_action_button.offset_top = -116.0
	_action_button.offset_right = -20.0
	_action_button.offset_bottom = -20.0
	_action_button.focus_mode = Control.FOCUS_NONE
	_action_button.add_theme_font_size_override("font_size", 14)
	_action_button.add_theme_color_override("font_color", C_PAPER_INK)
	_action_button.add_theme_color_override("font_pressed_color", Color("7f5b35"))
	_action_button.add_theme_stylebox_override("normal", _flat(C_PAPER, C_PAPER_EDGE, 3))
	_action_button.add_theme_stylebox_override("hover", _flat(C_PAPER_LIGHT, C_PAPER_EDGE, 3))
	_action_button.add_theme_stylebox_override("pressed", _flat(Color("d4bf91"), C_PAPER_EDGE, 3))
	_action_button.pressed.connect(_on_action_pressed)
	_root.add_child(_action_button)
	_action_label = Control.new()
	_action_label.anchor_left = 1.0
	_action_label.anchor_right = 1.0
	_action_label.anchor_top = 1.0
	_action_label.anchor_bottom = 1.0
	_action_label.offset_left = -116.0
	_action_label.offset_top = -116.0
	_action_label.offset_right = -20.0
	_action_label.offset_bottom = -20.0
	_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_label.draw.connect(func(): _draw_action_caption())
	_root.add_child(_action_label)
	_action_label.queue_redraw()
	call_deferred("_refresh_touch_control_draws")


func _refresh_touch_control_draws() -> void:
	await get_tree().process_frame
	if is_instance_valid(_action_label):
		_action_label.queue_redraw()
	if is_instance_valid(_joystick):
		_joystick.queue_redraw()


func _draw_action_caption() -> void:
	var font := ThemeDB.fallback_font
	_action_label.draw_string(font, Vector2(0, 43), "A", HORIZONTAL_ALIGNMENT_CENTER, 96, 14, C_PAPER_INK)
	_action_label.draw_string(font, Vector2(0, 64), "互 动", HORIZONTAL_ALIGNMENT_CENTER, 96, 13, C_PAPER_INK)


func _draw_joystick() -> void:
	var center := _joystick.size * 0.5
	var radius := minf(_joystick.size.x, _joystick.size.y) * 0.38
	_joystick.draw_circle(center, radius + 8.0, Color(0.25, 0.22, 0.20, 0.32))
	_joystick.draw_circle(center, radius + 4.0, Color(0.88, 0.82, 0.69, 0.78))
	_joystick.draw_arc(center, radius, 0.0, TAU, 24, Color(0.37, 0.31, 0.25, 0.82), 2.0, false)
	for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var p: Vector2 = center + dir * radius * 0.56
		_joystick.draw_circle(p, 2.0, Color(0.50, 0.43, 0.33, 0.68))
	var knob := center + _stick_vector * radius * 0.62
	_joystick.draw_circle(knob + Vector2(2, 3), 19.0, Color(0.20, 0.18, 0.16, 0.28))
	_joystick.draw_circle(knob, 18.0, Color(0.72, 0.62, 0.45, 0.92))
	_joystick.draw_circle(knob + Vector2(-3, -4), 12.0, Color(0.87, 0.77, 0.58, 0.95))


func _on_joystick_event(event: InputEvent, control: Control) -> void:
	var center := control.size * 0.5
	if event is InputEventScreenTouch:
		if event.pressed and not _stick_active:
			_stick_active = true
			_stick_mouse = false
			_stick_touch_id = event.index
			_update_stick(event.position - center)
		elif not event.pressed and _stick_active and event.index == _stick_touch_id:
			_release_stick()
	elif event is InputEventScreenDrag and _stick_active and not _stick_mouse and event.index == _stick_touch_id:
		_update_stick(event.position - center)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_stick_active = true
			_stick_mouse = true
			_update_stick(event.position - center)
		elif _stick_active and _stick_mouse:
			_release_stick()
	elif event is InputEventMouseMotion and _stick_active and _stick_mouse and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_stick(event.position - center)
	control.accept_event()


func _update_stick(delta_pos: Vector2) -> void:
	var max_radius := 48.0
	_stick_vector = (delta_pos / max_radius).limit_length(1.0)
	var threshold := 0.28
	_set_virtual_action("ui_left", _stick_vector.x < -threshold)
	_set_virtual_action("ui_right", _stick_vector.x > threshold)
	_set_virtual_action("ui_up", _stick_vector.y < -threshold)
	_set_virtual_action("ui_down", _stick_vector.y > threshold)
	_joystick.queue_redraw()


func _release_stick() -> void:
	_stick_active = false
	_stick_mouse = false
	_stick_touch_id = -1
	_stick_vector = Vector2.ZERO
	for action in ["ui_left", "ui_right", "ui_up", "ui_down"]:
		_set_virtual_action(action, false)
	_joystick.queue_redraw()


func _set_virtual_action(action: String, pressed: bool) -> void:
	if pressed:
		if not Input.is_action_pressed(action):
			Input.action_press(action)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _on_action_pressed() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("interact"):
		player.call("interact")


func _update_interaction_hint() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var estate := get_tree().get_first_node_in_group("estate")
	if player == null or estate == null or not estate.has_method("interaction_hint"):
		_interaction_panel.visible = false
		return
	var facing: Vector2 = player.get("facing")
	var target: Vector2 = player.global_position + facing * 20.0
	var prompt: String = estate.interaction_hint(target)
	if prompt == "":
		_interaction_panel.visible = false
		return
	_interaction_label.text = "%s · 空格" % prompt
	_interaction_panel.visible = true
	var screen_pos := get_viewport().get_canvas_transform() * (player.global_position + Vector2(0, -38))
	_interaction_panel.position = screen_pos - Vector2(61, 32)


func _build_hint() -> void:
	_hint_panel = _panel(0.0, 0.0, 16.0, 16.0, 330.0, 88.0)
	_hint_panel.modulate.a = 0.92
	var content := _content(_hint_panel, 10)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	content.add_child(stack)
	stack.add_child(_label("CAMPUS HOLLOW · 校园漫游", 11, C_GOLD))
	var hint := _label("WASD / 方向键 移动    Shift 奔跑\n空格 互动（NPC / 长椅 / 喷泉 / 校牌）\nT 跳到清晨    F1 隐藏提示", 10, C_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(hint)


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 1.0
	_toast_panel.anchor_bottom = 1.0
	_toast_panel.offset_left = -260.0
	_toast_panel.offset_right = 260.0
	_toast_panel.offset_top = -132.0
	_toast_panel.offset_bottom = -88.0
	_toast_panel.add_theme_stylebox_override("panel", _flat(Color(0.08, 0.10, 0.07, 0.90), C_BORDER, 2))
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	_root.add_child(_toast_panel)
	var content := _content(_toast_panel, 6)
	_toast_label = _label("", 13, C_INK)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_toast_label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		_hint_panel.visible = not _hint_panel.visible


# ---------------------------------------------------------------------

func _panel(ax: float, ay: float, ox: float, oy: float, w: float, h: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = ax
	panel.anchor_right = ax
	panel.anchor_top = ay
	panel.anchor_bottom = ay
	panel.offset_left = ox
	panel.offset_top = oy
	panel.offset_right = ox + w
	panel.offset_bottom = oy + h
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _flat(C_PANEL, C_BORDER, 2))
	_root.add_child(panel)
	return panel


func _paper_panel(ax: float, ay: float, ox: float, oy: float, w: float, h: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = ax
	panel.anchor_right = ax
	panel.anchor_top = ay
	panel.anchor_bottom = ay
	panel.offset_left = ox
	panel.offset_top = oy
	panel.offset_right = ox + w
	panel.offset_bottom = oy + h
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _flat(C_PAPER, C_PAPER_EDGE, 3))
	_root.add_child(panel)
	return panel


func _content(panel: PanelContainer, padding: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, padding)
	panel.add_child(margin)
	return margin


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.04, 0.9))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _flat(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.shadow_color = Color(0.02, 0.03, 0.02, 0.55)
	style.shadow_size = 2
	style.shadow_offset = Vector2(2, 2)
	return style


func _on_day(day: int, _season_id: String) -> void:
	_day_label.text = "%s季 · 第 %02d 天" % [GameClock.season_name(), day]
	var season := int(GameClock.season_index)
	var conditions := ["晴朗", "薄云", "晴朗", "微雨"]
	var winds := ["东北风", "东南风", "西南风", "西北风"]
	var base_temps := [19, 28, 16, 3]
	var condition_index := (day + season * 2) % conditions.size()
	var temperature := int(base_temps[season]) + int((day % 5) - 2)
	_weather_label.text = "%s · %d°C" % [conditions[condition_index], temperature]
	_wind_label.text = "微风  ↘  %s" % winds[(day + season) % winds.size()]


func _on_time(hour: int, minute: int) -> void:
	_clock_label.text = "%02d:%02d" % [hour, minute]
	_dial_hour = hour
	_dial_minute = minute
	_dial.queue_redraw()


func _update_location() -> void:
	var estate := get_tree().get_first_node_in_group("estate")
	if estate == null or not estate.has_method("zone_name"):
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	_loc_label.text = "当前位置：%s" % str(estate.zone_name((player as Node2D).global_position))


func _toast(text: String) -> void:
	if text == "":
		return
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	_toast_timer = 3.4

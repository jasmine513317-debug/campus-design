extends CanvasModulate
## 昼夜色调：清晨暖、白天正、黄昏橙、夜里偏蓝。HUD 在独立 CanvasLayer，不受影响。

const KEYS := [
	{"t": 0.0, "c": Color(0.34, 0.40, 0.62)},
	{"t": 4.5, "c": Color(0.36, 0.42, 0.64)},
	{"t": 6.0, "c": Color(1.0, 0.94, 0.84)},
	{"t": 8.0, "c": Color(1.0, 1.0, 0.99)},
	{"t": 16.0, "c": Color(1.0, 0.99, 0.95)},
	{"t": 18.5, "c": Color(1.0, 0.87, 0.70)},
	{"t": 20.0, "c": Color(0.78, 0.70, 0.78)},
	{"t": 21.5, "c": Color(0.54, 0.56, 0.76)},
	{"t": 24.0, "c": Color(0.34, 0.40, 0.62)},
]


func _ready() -> void:
	GameClock.time_changed.connect(_on_time)
	_on_time(GameClock.hour(), GameClock.minute())


func _on_time(hour: int, minute: int) -> void:
	var t := float(hour) + float(minute) / 60.0
	color = _sample(t)


func _sample(t: float) -> Color:
	for i in range(KEYS.size() - 1):
		var a: Dictionary = KEYS[i]
		var b: Dictionary = KEYS[i + 1]
		var ta: float = a["t"]
		var tb: float = b["t"]
		if t >= ta and t <= tb:
			var ca: Color = a["c"]
			var cb: Color = b["c"]
			var f := 0.0 if tb <= ta else (t - ta) / (tb - ta)
			# 用 smoothstep 让过渡不生硬
			f = f * f * (3.0 - 2.0 * f)
			return ca.lerp(cb, f)
	var first: Color = KEYS[0]["c"]
	return first

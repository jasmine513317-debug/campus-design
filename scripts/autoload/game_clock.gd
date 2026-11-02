extends Node
## 游戏内时间与季节。这是全游戏共享的“日历”，场景不要各自记天数。
##
## 现实约 1 秒 = 游戏 8 分钟。一天从 6:00 走到 2:00，超时会强制睡下并进入下一天。

signal time_changed(hour: int, minute: int)
signal day_started(day: int, season_id: String)
signal day_ended(day: int)

const MINUTES_PER_REAL_SECOND := 8.0
const WAKE_MINUTE := 6 * 60
const BED_MINUTE := 2 * 60 + 24 * 60  # 次日 02:00，用“从凌晨 0 点起的连续分钟”不方便，改用从 6:00 起算
const MINUTES_IN_DAY := (24 - 6 + 2) * 60  # 6:00 → 次日 2:00 = 20 小时
const DAYS_PER_SEASON := 28
const SEASON_IDS := ["spring", "summer", "autumn", "winter"]
const SEASON_NAMES := ["春", "夏", "秋", "冬"]

var day: int = 2
var year: int = 1
var season_index: int = 2
## 从当天 6:00 起经过的分钟。
var minutes_since_wake: float = 0.0
var paused: bool = false

func _ready() -> void:
	day_started.emit(day, season_id())
	_emit_clock()


func _process(delta: float) -> void:
	if paused:
		return
	minutes_since_wake += MINUTES_PER_REAL_SECOND * delta
	if minutes_since_wake >= MINUTES_IN_DAY:
		sleep_until_morning()
		return
	_emit_clock()


func season_id() -> String:
	return SEASON_IDS[season_index]


func season_name() -> String:
	return SEASON_NAMES[season_index]


func hour() -> int:
	var total := WAKE_MINUTE + int(minutes_since_wake)
	return int(floor(total / 60.0)) % 24


func minute() -> int:
	var total := WAKE_MINUTE + int(minutes_since_wake)
	return total % 60


func clock_text() -> String:
	return "%s %d日  %02d:%02d" % [season_name(), day, hour(), minute()]


func sleep_until_morning() -> void:
	day_ended.emit(day)
	day += 1
	if day > DAYS_PER_SEASON:
		day = 1
		season_index = (season_index + 1) % SEASON_IDS.size()
		if season_index == 0:
			year += 1
	minutes_since_wake = 0.0
	day_started.emit(day, season_id())
	_emit_clock()


func _emit_clock() -> void:
	time_changed.emit(hour(), minute())

extends Node
## Scene handoff between campus and enterable buildings.

const CAMPUS_SCENE := "res://scenes/world/main.tscn"

var return_scene_path := CAMPUS_SCENE
var return_position := Vector2.ZERO
var pending_player_spawn := false
var pending_player_position := Vector2.ZERO
var transitioning := false


func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)


func enter(scene_path: String, outside_position: Vector2, inside_position: Vector2) -> Error:
	if transitioning:
		return ERR_BUSY
	var current := get_tree().current_scene
	var previous_path := return_scene_path
	var previous_position := return_position
	return_scene_path = current.scene_file_path if current != null and current.scene_file_path != "" else CAMPUS_SCENE
	return_position = outside_position
	var error := _change_scene(scene_path, inside_position)
	if error != OK:
		return_scene_path = previous_path
		return_position = previous_position
	return error


func leave_building() -> Error:
	return _change_scene(return_scene_path, return_position)


func _change_scene(scene_path: String, spawn_position: Vector2) -> Error:
	if transitioning:
		return ERR_BUSY
	# Validate before changing handoff state or removing the current scene.
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		Messages.say("暂时无法进入这个场景。")
		return ERR_FILE_NOT_FOUND
	pending_player_position = spawn_position
	pending_player_spawn = true
	transitioning = true
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		pending_player_spawn = false
		transitioning = false
		Messages.say("场景切换失败，请稍后再试。")
	return error


func _on_scene_changed() -> void:
	transitioning = false


func consume_player_spawn() -> Variant:
	if not pending_player_spawn:
		return null
	pending_player_spawn = false
	return pending_player_position

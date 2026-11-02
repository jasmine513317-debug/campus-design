extends Node
## Scene handoff between campus and enterable buildings.

var return_scene_path := "res://scenes/world/main.tscn"
var return_position := Vector2.ZERO
var pending_player_spawn := false
var pending_player_position := Vector2.ZERO


func enter(scene_path: String, outside_position: Vector2, inside_position: Vector2) -> void:
	var current := get_tree().current_scene
	if current != null and current.scene_file_path != "":
		return_scene_path = current.scene_file_path
	else:
		return_scene_path = "res://scenes/world/main.tscn"
	return_position = outside_position
	pending_player_position = inside_position
	pending_player_spawn = true
	get_tree().change_scene_to_file(scene_path)


func leave_building() -> void:
	pending_player_position = return_position
	pending_player_spawn = true
	get_tree().change_scene_to_file(return_scene_path)


func consume_player_spawn() -> Variant:
	if not pending_player_spawn:
		return null
	pending_player_spawn = false
	return pending_player_position

extends Node

var open_world_path : String = ""

var building_id_to_rebuild : String = ""


func start_minigame(building_id : String, minigame_path : String):
	get_tree().change_scene_to_file(minigame_path)
	
	pass

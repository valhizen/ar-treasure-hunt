extends Node

var save_game: SaveGame
var current_slot := 0

func get_slot_path() -> String:
	return "user://save_%d.tres" % current_slot

func new_save():
	save_game = SaveGame.new()
	save_game.player_data = PlayerData.new()

func save_to_slot():
	ResourceSaver.save(save_game, get_slot_path())

func load_from_slot():
	var data = ResourceLoader.load(get_slot_path())
	if data is SaveGame:
		save_game = data
		return true
	return false
	
func autosave(player):
	player.save_state(save_game.player_data)
	save_to_slot()
	
func _on_Timer_timeout():
	autosave(get_player())

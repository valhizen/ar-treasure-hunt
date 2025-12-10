extends Node2D

@export var map_name: String = "bhaktapur"
@onready var player = $MainCharacter

func _ready():
	SaveManager.set_current_map(map_name)
	load_map_state()
	restore_player_position()

func _exit_tree():
	# Save player position when leaving map
	if player:
		SaveManager.set_player_position(map_name, player.global_position)

func load_map_state():
	var map_data = SaveManager.get_map_data(map_name)
	if map_data == null:
		return
	
	# Update map visuals based on completed minigames
	for minigame_id in map_data.minigames_completed.keys():
		if map_data.minigames_completed[minigame_id]:
			on_minigame_completed(minigame_id)

func restore_player_position():
	if player:
		var saved_pos = SaveManager.get_player_position(map_name)
		if saved_pos != Vector2.ZERO:
			player.global_position = saved_pos

func on_minigame_completed(minigame_id: String):
	# Override this in specific map scripts
	# Example: Change broken temple to fixed temple
	pass

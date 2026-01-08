extends Node
signal all_corrupters_defused
signal game_won

var total_corrupters: int = 0
var defused_corrupters: int = 0
var fish_killed: int = 0
var game_start_time: float = 0.0
var game_end_time: float = 0.0
var game_duration: float = 0.0

func _ready() -> void:
	# Add to game_manager group so PortalBlocker can find us
	add_to_group("game_manager")
	
	game_start_time = Time.get_ticks_msec() / 1000.0
	
	# Count all corrupters in the scene
	await get_tree().process_frame  # Wait for scene to be fully loaded
	_count_corrupters()

func register_fish_kill() -> void:
	fish_killed += 1
	print("Fish killed: ", fish_killed)

func _count_corrupters() -> void:
	var corrupters = get_tree().get_nodes_in_group("corrupter")
	total_corrupters = corrupters.size()
	print("Total corrupters found: ", total_corrupters)
	
	# Connect to each corrupter's defused signal
	for corrupter in corrupters:
		if corrupter.has_signal("corrupter_defused"):
			corrupter.corrupter_defused.connect(_on_corrupter_defused)



func _on_corrupter_defused() -> void:
	defused_corrupters += 1
	print("Corrupters defused: ", defused_corrupters, "/", total_corrupters)
	
	# Check if all are defused
	if defused_corrupters >= total_corrupters and total_corrupters > 0:
		_all_corrupters_defused()

func _all_corrupters_defused() -> void:
	game_end_time = Time.get_ticks_msec() / 1000.0
	game_duration = game_end_time - game_start_time
	
	print("All corrupters defused! Fish dying and game won!")
	all_corrupters_defused.emit()
	
	# Kill all fish
	_kill_all_fish()
	
	# Wait for fish to float away, then show win screen
	await get_tree().create_timer(2.5).timeout
	_show_win_screen()



func _kill_all_fish() -> void:
	var fish = get_tree().get_nodes_in_group("enemy")
	for f in fish:
		if f.has_method("die_and_float"):
			f.die_and_float()

func _show_win_screen() -> void:
	game_won.emit()
	
	var win_screen = get_tree().get_first_node_in_group("win_screen")
	win_screen.show_win_screen()

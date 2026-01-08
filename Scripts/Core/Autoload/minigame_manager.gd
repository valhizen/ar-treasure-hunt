extends Node
## MinigameManager - FIXED map tracking when entering minigames

#region Signals
signal minigame_starting(minigame_id: String)
signal minigame_started(minigame_id: String)
signal minigame_completed(minigame_id: String, result: MinigameResult)
signal minigame_failed(minigame_id: String, reason: String)
signal minigame_exited(minigame_id: String)
signal minigame_blocked(minigame_id: String, reason: String)
#endregion

#region State Variables
var current_minigame_id: String = ""
var current_minigame_map: String = ""
var current_minigame_instance: Node = null
var current_minigame_data: Dictionary = {}
var current_pause_menu: CanvasLayer = null

# Saved state for returning from minigame
var saved_map: String = ""
var saved_scene_path: String = ""
var saved_position: Vector2 = Vector2.ZERO
var saved_player_facing: Vector2 = Vector2.DOWN

var is_in_minigame: bool = false
#endregion

#region Pause Menu Scene
const PAUSE_MENU_SCENE: String = "res://Scenes/Core/UI/minigame_pause_menu.tscn"
var pause_menu_packed: PackedScene = null
#endregion

#region Minigame Registry
var minigame_registry: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_minigame_registry()
	_preload_pause_menu()
	print("[MinigameManager] Initialized")


func _preload_pause_menu() -> void:
	if ResourceLoader.exists(PAUSE_MENU_SCENE):
		pause_menu_packed = load(PAUSE_MENU_SCENE)
		print("[MinigameManager] Pause menu preloaded")
	else:
		print("[MinigameManager] Will create pause menu programmatically")


func _load_minigame_registry() -> void:
	minigame_registry = {
		"nyatapola_temple": {
			"id": "nyatapola_temple",
			"display_name": "Nyatapola Temple Challenge",
			"description": "Climb the temple stairs while avoiding obstacles",
			"map": "bhaktapur",
			"scene_path": "res://Scenes/Minigames/Bhaktapur/nyatapola_temple_game.tscn",
			"difficulty": 1,
			"max_score": 1000,
			"time_limit": 60.0,
			"keys_available": 1,
			"base_currency_reward": 25
		},
		"bhaktapur_durbar_square": {
			"id": "bhaktapur_durbar_square",
			"display_name": "Durbar Square Puzzle",
			"description": "Solve the ancient puzzle in the square",
			"map": "bhaktapur",
			"scene_path": "res://Scenes/Minigames/Bhaktapur/durbar_square_puzzle.tscn",
			"difficulty": 2,
			"max_score": 1500,
			"time_limit": 120.0,
			"keys_available": 2,
			"base_currency_reward": 40
		},
		"musem_bhaktapur": {
			"id": "musem_bhaktapur",
			"display_name": "Museum Exploration",
			"description": "Find hidden artifacts in the museum",
			"map": "bhaktapur",
			"scene_path": "res://Scenes/Minigames/Bhaktapur/museum_exploration.tscn",
			"difficulty": 0,
			"max_score": 500,
			"time_limit": 0,
			"keys_available": 1,
			"base_currency_reward": 15
		},
		"kathmandu_market": {
			"id": "kathmandu_market",
			"display_name": "Market Trading",
			"map": "kathmandu",
			"scene_path": "res://Scenes/Minigames/Kathmandu/market_trading.tscn",
			"difficulty": 1,
			"max_score": 800,
			"time_limit": 90.0,
			"keys_available": 1,
			"base_currency_reward": 30
		},
	}
	
	print("[MinigameManager] Loaded %d minigames" % minigame_registry.size())


func register_minigame(minigame_id: String, data: Dictionary) -> void:
	minigame_registry[minigame_id] = data


func unregister_minigame(minigame_id: String) -> void:
	minigame_registry.erase(minigame_id)


func get_minigame_info(minigame_id: String) -> Dictionary:
	return minigame_registry.get(minigame_id, {})


func get_minigames_for_map(map_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for minigame_data in minigame_registry.values():
		if minigame_data.get("map", "") == map_name:
			result.append(minigame_data)
	return result


func get_all_minigames() -> Dictionary:
	return minigame_registry
#endregion

#region Enter Minigame - CRITICAL FIX
func start_minigame(minigame_id: String, entry_position: Vector2 = Vector2.ZERO, player_facing: Vector2 = Vector2.DOWN) -> bool:
	"""Start a minigame - FIXED to capture correct map"""
	if is_in_minigame:
		push_warning("[MinigameManager] Already in a minigame!")
		return false
	
	if not minigame_registry.has(minigame_id):
		push_error("[MinigameManager] Unknown minigame: %s" % minigame_id)
		return false
	
	var minigame_data = minigame_registry[minigame_id]
	var scene_path = minigame_data.get("scene_path", "")
	var map_name = minigame_data.get("map", "")
	
	# Check if already completed
	var player_data = get_node_or_null("/root/PlayerData")
	if player_data and player_data.is_minigame_completed(minigame_id, map_name):
		print("[MinigameManager] Minigame already completed: %s" % minigame_id)
		minigame_blocked.emit(minigame_id, "already_completed")
		return false
	
	if scene_path.is_empty():
		push_error("[MinigameManager] No scene path for minigame: %s" % minigame_id)
		return false
	
	if not ResourceLoader.exists(scene_path):
		push_error("[MinigameManager] Scene not found: %s" % scene_path)
		return false
	
	# ============ CRITICAL FIX: Capture current map correctly ============
	var game_manager = get_node_or_null("/root/GameManager")
	
	# Force GameManager to update its current_map from the actual scene
	if game_manager and game_manager.has_method("_update_current_map_from_scene"):
		game_manager._update_current_map_from_scene()
	
	# Get the REAL current scene and map
	var current_scene = get_tree().current_scene
	if current_scene and current_scene.scene_file_path:
		saved_scene_path = current_scene.scene_file_path
		saved_map = current_scene.scene_file_path.get_file().get_basename()
		print("[MinigameManager] 🎯 Captured map from scene: %s" % saved_map)
	elif game_manager:
		saved_map = game_manager.current_map
		saved_scene_path = _get_scene_path_for_map(saved_map)
		print("[MinigameManager] 🎯 Captured map from GameManager: %s" % saved_map)
	else:
		saved_map = ""
		saved_scene_path = ""
		print("[MinigameManager] ⚠️ WARNING: Could not capture current map!")
	
	# Get position
	saved_position = entry_position if entry_position != Vector2.ZERO else _get_player_position()
	saved_player_facing = player_facing
	
	# Store map position in PlayerData
	if player_data and not saved_map.is_empty():
		player_data.save_map_position(saved_map, saved_position)
		player_data.last_map = saved_map
		player_data.last_position = saved_position
		print("[MinigameManager] 💾 Saved to PlayerData: map=%s pos=%s" % [saved_map, saved_position])
	
	current_minigame_id = minigame_id
	current_minigame_map = map_name if not map_name.is_empty() else saved_map
	current_minigame_data = minigame_data
	
	minigame_starting.emit(minigame_id)
	print("[MinigameManager] Starting minigame: %s (returning to: %s at %s)" % [minigame_id, saved_map, saved_position])
	
	_load_minigame_scene(scene_path)
	
	return true


func _get_scene_path_for_map(map_name: String) -> String:
	"""Convert map name to scene path"""
	var paths = [
		"res://Scenes/Core/Maps/%s.tscn" % map_name,
		"res://Scenes/Core/Maps/Prologue/%s.tscn" % map_name,
		"res://Scenes/Maps/%s.tscn" % map_name,
		"res://Scenes/MainCharacter/%s.tscn" % map_name,
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			return path
	
	return ""


func _load_minigame_scene(scene_path: String) -> void:
	"""Load the minigame scene"""
	is_in_minigame = true
	
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("set_minigame_state"):
		game_manager.set_minigame_state(true)
	
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("[MinigameManager] Failed to load minigame scene: %d" % error)
		is_in_minigame = false
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	_connect_to_minigame()
	_inject_pause_menu()
	
	minigame_started.emit(current_minigame_id)
	print("[MinigameManager] Minigame loaded: %s" % current_minigame_id)


func _connect_to_minigame() -> void:
	"""Connect to the loaded minigame's signals"""
	var root = get_tree().current_scene
	if not root:
		return
	
	current_minigame_instance = root
	
	if root.has_method("_initialize_minigame"):
		if root.has_signal("completed") and not root.completed.is_connected(_on_minigame_completed):
			root.completed.connect(_on_minigame_completed)
		if root.has_signal("failed") and not root.failed.is_connected(_on_minigame_failed):
			root.failed.connect(_on_minigame_failed)
		if root.has_signal("exited") and not root.exited.is_connected(_on_minigame_exited):
			root.exited.connect(_on_minigame_exited)
		
		root._initialize_minigame(_get_minigame_init_data())
	else:
		push_warning("[MinigameManager] Minigame scene doesn't have _initialize_minigame method")


func _inject_pause_menu() -> void:
	"""Inject pause menu into current minigame scene"""
	var root = get_tree().current_scene
	if not root:
		return
	
	if root.has_node("MinigamePauseMenu"):
		current_pause_menu = root.get_node("MinigamePauseMenu")
		print("[MinigameManager] Pause menu already exists in scene")
		return
	
	if pause_menu_packed:
		current_pause_menu = pause_menu_packed.instantiate()
	else:
		current_pause_menu = _create_pause_menu_programmatically()
	
	if current_pause_menu:
		current_pause_menu.name = "MinigamePauseMenu"
		root.add_child(current_pause_menu)
		
		var display_name = current_minigame_data.get("display_name", current_minigame_id)
		if current_pause_menu.has_method("set_minigame_name"):
			current_pause_menu.set_minigame_name(display_name)
		
		print("[MinigameManager] Pause menu injected")


func _create_pause_menu_programmatically() -> CanvasLayer:
	"""Create pause menu without needing a .tscn file"""
	var menu = CanvasLayer.new()
	menu.layer = 100
	menu.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var blur = ColorRect.new()
	blur.name = "BlurOverlay"
	blur.color = Color(0, 0, 0, 0.6)
	blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.add_child(blur)
	
	var panel = PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 360)
	panel.position = Vector2(-200, -180)
	menu.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.name = "Title"
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)
	
	var resume_btn = Button.new()
	resume_btn.name = "ResumeButton"
	resume_btn.text = "Resume"
	resume_btn.custom_minimum_size.y = 50
	resume_btn.pressed.connect(_on_pause_resume)
	vbox.add_child(resume_btn)
	
	var restart_btn = Button.new()
	restart_btn.name = "RestartButton"
	restart_btn.text = "Restart"
	restart_btn.custom_minimum_size.y = 50
	restart_btn.pressed.connect(_on_pause_restart)
	vbox.add_child(restart_btn)
	
	var exit_btn = Button.new()
	exit_btn.name = "ExitButton"
	exit_btn.text = "Exit Minigame"
	exit_btn.custom_minimum_size.y = 50
	exit_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	exit_btn.pressed.connect(_on_pause_exit)
	vbox.add_child(exit_btn)
	
	menu.visible = false
	
	return menu


func _get_minigame_init_data() -> Dictionary:
	var player_data = get_node_or_null("/root/PlayerData")
	var record_key = current_minigame_id
	
	return {
		"minigame_id": current_minigame_id,
		"minigame_data": current_minigame_data,
		"player_name": player_data.player_name if player_data else "Player",
		"player_id": player_data.player_id if player_data else "",
		"is_replay": player_data.is_minigame_completed(current_minigame_id) if player_data else false,
		"previous_best": player_data.minigame_records.get(record_key, {}) if player_data else {},
		"map_name": current_minigame_map
	}


func _get_player_position() -> Vector2:
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.current_player:
		return game_manager.current_player.global_position
	return Vector2.ZERO
#endregion

#region Pause Menu Handlers
func _on_pause_resume() -> void:
	if current_pause_menu:
		current_pause_menu.visible = false
	get_tree().paused = false


func _on_pause_restart() -> void:
	if current_pause_menu:
		current_pause_menu.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_pause_exit() -> void:
	if current_pause_menu:
		current_pause_menu.visible = false
	get_tree().paused = false
	force_exit()


func show_pause_menu() -> void:
	if current_pause_menu:
		current_pause_menu.visible = true
		get_tree().paused = true
		
		var resume_btn = current_pause_menu.get_node_or_null("Panel/MarginContainer/VBox/ResumeButton")
		if not resume_btn:
			resume_btn = current_pause_menu.get_node_or_null("Panel/VBox/ResumeButton")
		if resume_btn:
			resume_btn.grab_focus()


func hide_pause_menu() -> void:
	if current_pause_menu:
		current_pause_menu.visible = false
	get_tree().paused = false
#endregion

#region Input Handling
func _input(event: InputEvent) -> void:
	if not is_in_minigame:
		return
	
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if current_pause_menu:
			if current_pause_menu.visible:
				hide_pause_menu()
			else:
				show_pause_menu()
			get_viewport().set_input_as_handled()
#endregion

#region Exit Minigame - FIXED save
func exit_minigame(result: MinigameResult = null) -> void:
	"""Exit current minigame and return to map"""
	if not is_in_minigame:
		push_warning("[MinigameManager] Not in a minigame!")
		return
	
	var minigame_id = current_minigame_id
	
	if result:
		_process_minigame_result(result)
		
		var score_manager = get_node_or_null("/root/ScoreManager")
		if score_manager:
			score_manager.submit_minigame_result(minigame_id, result)
	
	current_pause_menu = null
	current_minigame_instance = null
	current_minigame_id = ""
	current_minigame_data = {}
	is_in_minigame = false
	
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.has_method("set_minigame_state"):
		game_manager.set_minigame_state(false)
	
	minigame_exited.emit(minigame_id)
	
	_return_to_map()


func _return_to_map() -> void:
	"""Return to the map at saved position"""
	print("[MinigameManager] Returning to %s at %s" % [saved_map, saved_position])
	
	var game_manager = get_node_or_null("/root/GameManager")
	
	if game_manager:
		if game_manager.has_method("change_map"):
			game_manager.change_map(saved_map, saved_position)
		elif game_manager.has_method("change_scene"):
			game_manager._pending_player_position = saved_position
			game_manager.change_scene(saved_scene_path)
		else:
			_direct_return_to_map()
	else:
		_direct_return_to_map()


func _direct_return_to_map() -> void:
	if saved_scene_path.is_empty():
		push_error("[MinigameManager] No saved scene to return to!")
		return
	
	get_tree().change_scene_to_file(saved_scene_path)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var player = _find_player()
	if player and saved_position != Vector2.ZERO:
		player.global_position = saved_position


func _find_player() -> Node2D:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _process_minigame_result(result: MinigameResult) -> void:
	"""Process the minigame result and update PlayerData"""
	var player_data = get_node_or_null("/root/PlayerData")
	if not player_data:
		push_error("[MinigameManager] No PlayerData!")
		return
	
	var minigame_id_to_use = result.minigame_id if not result.minigame_id.is_empty() else current_minigame_id
	
	if result.success:
		# CRITICAL: Use saved_map (the map we came from), NOT current_minigame_map
		player_data.complete_minigame(
			minigame_id_to_use,
			saved_map,  # <-- FIX: This is the actual map where the minigame was started
			{
				"score": result.score,
				"time": result.time_taken,
				"stars": result.stars,
				"success": true
			}
		)
		
		print("[MinigameManager] ✅ Recorded completion: %s on map: %s" % [minigame_id_to_use, saved_map])
		
		for key_id in result.keys_found:
			player_data.collect_key(key_id, saved_map)
		
		for item in result.items_awarded:
			if item.get("special", false):
				player_data.add_special_item(item.get("id", ""))
			else:
				player_data.add_item(item.get("id", ""), item.get("amount", 1))
		
		if result.currency_awarded > 0:
			player_data.add_currency(result.currency_awarded)
		
		_save_after_minigame()
		
		minigame_completed.emit(minigame_id_to_use, result)
		print("[MinigameManager] Minigame completed: %s (Score: %d, Stars: %d)" % [minigame_id_to_use, result.score, result.stars])
	else:
		minigame_failed.emit(minigame_id_to_use, result.failure_reason)
		print("[MinigameManager] Minigame failed: %s (%s)" % [minigame_id_to_use, result.failure_reason])


func _save_after_minigame() -> void:
	"""Save game after minigame completion - FIXED"""
	print("[MinigameManager] 💾 Saving after minigame completion...")
	print("  - Map to save: %s" % saved_map)
	print("  - Position to save: %s" % saved_position)
	
	var save_manager = get_node_or_null("/root/SaveManager")
	if not save_manager:
		push_error("[MinigameManager] No SaveManager!")
		return
	
	var player_data = get_node_or_null("/root/PlayerData")
	var game_manager = get_node_or_null("/root/GameManager")
	
	var save_data = {
		"save_name": "Auto-Save",
		"timestamp": Time.get_unix_time_from_system(),
		"datetime": Time.get_datetime_string_from_system(),
		"current_map": saved_map,  # <-- Use saved_map (the map we came from)
		"player_position": {
			"x": saved_position.x,
			"y": saved_position.y
		},
		"player_data": player_data.to_dictionary() if player_data else {},
		"game_version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
		"is_auto_save": true
	}
	
	# Update GameManager's current_map so future saves are correct
	if game_manager:
		game_manager.current_map = saved_map
	
	save_manager._write_save_file(0, save_data)
	print("[MinigameManager] ✅ Auto-saved to slot 0 (map: %s)" % saved_map)
	
	var most_recent = save_manager._get_most_recent_slot()
	if most_recent > 0:
		save_manager._write_save_file(most_recent, save_data)
		print("[MinigameManager] ✅ Also saved to slot %d" % most_recent)
	
	# Sync to server
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.sync_progress()
#endregion

#region Signal Handlers
func _on_minigame_completed(result: MinigameResult) -> void:
	exit_minigame(result)


func _on_minigame_failed(reason: String) -> void:
	var result = MinigameResult.new()
	result.success = false
	result.failure_reason = reason
	exit_minigame(result)


func _on_minigame_exited() -> void:
	exit_minigame(null)
#endregion

#region Quick Exit
func request_exit() -> void:
	if not is_in_minigame:
		return
	
	if current_minigame_instance and current_minigame_instance.has_method("request_exit"):
		current_minigame_instance.request_exit()
	else:
		exit_minigame(null)


func force_exit() -> void:
	exit_minigame(null)
#endregion

#region Utility
func get_current_minigame_id() -> String:
	return current_minigame_id


func get_current_minigame_data() -> Dictionary:
	return current_minigame_data


func get_saved_position() -> Vector2:
	return saved_position


func get_saved_map() -> String:
	return saved_map
#endregion

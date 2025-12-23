extends Node
## SaveManager - Save/Load System
## AutoLoad Singleton: Manages save files, multiple slots, auto-save

#region Signals
signal save_completed(slot_index: int)
signal load_completed(slot_index: int)
signal save_deleted(slot_index: int)
signal save_error(message: String)
#endregion

#region Constants
const SAVE_DIR: String = "user://saves/"
const SAVE_FILE_PREFIX: String = "save_slot_"
const SAVE_FILE_EXTENSION: String = ".json"
const AUTO_SAVE_SLOT: int = 0  # Slot 0 is reserved for auto-save
const MAX_SAVE_SLOTS: int = 5  # Slots 0-4 (0 = auto, 1-4 = manual)
const SETTINGS_FILE: String = "user://settings.json"
#endregion

#region Lifecycle
func _ready() -> void:
	_ensure_save_directory()
	print("[SaveManager] Initialized. Save path: %s" % SAVE_DIR)
#endregion

#region Directory Management
func _ensure_save_directory() -> void:
	"""Create save directory if it doesn't exist"""
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("saves"):
			dir.make_dir("saves")
			print("[SaveManager] Created saves directory")
#endregion

#region Save Functions
func save_game(slot_index: int = 1, custom_name: String = "") -> bool:
	"""Save game to specified slot"""
	if slot_index < 0 or slot_index >= MAX_SAVE_SLOTS:
		push_error("[SaveManager] Invalid slot index: %d" % slot_index)
		save_error.emit("Invalid save slot")
		return false
	
	# Gather save data
	var save_data = _create_save_data(custom_name)
	
	# Get player position
	if GameManager.current_player:
		save_data["player_position"] = [
			GameManager.current_player.global_position.x,
			GameManager.current_player.global_position.y
		]
	
	# Write to file
	var success = _write_save_file(slot_index, save_data)
	
	if success:
		save_completed.emit(slot_index)
		print("[SaveManager] Game saved to slot %d" % slot_index)
	
	return success


func auto_save(current_map: String, player_position: Vector2) -> bool:
	"""Perform auto-save to slot 0"""
	var save_data = _create_save_data("Auto-Save")
	save_data["player_position"] = [player_position.x, player_position.y]
	save_data["current_map"] = current_map
	save_data["is_auto_save"] = true
	
	var success = _write_save_file(AUTO_SAVE_SLOT, save_data)
	
	if success:
		print("[SaveManager] Auto-save completed")
	
	return success


func _create_save_data(save_name: String = "") -> Dictionary:
	"""Create save data dictionary"""
	return {
		"save_name": save_name,
		"timestamp": Time.get_unix_time_from_system(),
		"datetime": Time.get_datetime_string_from_system(),
		"current_map": GameManager.current_map,
		"player_position": [0, 0],  # Will be overwritten
		"player_data": PlayerData.to_dictionary(),
		"game_version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
		"is_auto_save": false
	}


func _write_save_file(slot_index: int, data: Dictionary) -> bool:
	"""Write save data to file"""
	var file_path = _get_save_path(slot_index)
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Could not open file for writing: %s" % file_path)
		save_error.emit("Could not create save file")
		return false
	
	var json_string = JSON.stringify(data, "\t")  # Pretty print with tabs
	file.store_string(json_string)
	file.close()
	
	return true
#endregion

#region Load Functions
func load_game(slot_index: int = -1) -> Variant:
	"""
	Load game from slot. 
	If slot_index is -1, loads the most recent save.
	Returns save data dictionary or null if failed.
	"""
	if slot_index == -1:
		slot_index = _get_most_recent_slot()
		if slot_index == -1:
			push_warning("[SaveManager] No saves found")
			return null
	
	if slot_index < 0 or slot_index >= MAX_SAVE_SLOTS:
		push_error("[SaveManager] Invalid slot index: %d" % slot_index)
		return null
	
	var save_data = _read_save_file(slot_index)
	
	if save_data:
		# Convert position to Vector2 safely
		var pos_data = save_data.get("player_position", null)
		
		if pos_data is Array and pos_data.size() >= 2:
			save_data["player_position"] = Vector2(float(pos_data[0]), float(pos_data[1]))
		elif pos_data is Dictionary:
			save_data["player_position"] = Vector2(
				float(pos_data.get("x", pos_data.get("0", 0))),
				float(pos_data.get("y", pos_data.get("1", 0)))
			)
		else:
			save_data["player_position"] = Vector2.ZERO
		
		load_completed.emit(slot_index)
		print("[SaveManager] Game loaded from slot %d" % slot_index)
	
	return save_data


func _read_save_file(slot_index: int) -> Variant:
	"""Read save data from file"""
	var file_path = _get_save_path(slot_index)
	
	if not FileAccess.file_exists(file_path):
		return null
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[SaveManager] Could not open file for reading: %s" % file_path)
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("[SaveManager] JSON parse error: %s" % json.get_error_message())
		return null
	
	return json.data
#endregion

#region Save Slot Management
func get_save_path(slot_index: int) -> String:
	"""Public accessor for save path"""
	return _get_save_path(slot_index)


func _get_save_path(slot_index: int) -> String:
	"""Get file path for a save slot"""
	return SAVE_DIR + SAVE_FILE_PREFIX + str(slot_index) + SAVE_FILE_EXTENSION


func does_save_exist(slot_index: int) -> bool:
	"""Check if a save exists in slot"""
	return FileAccess.file_exists(_get_save_path(slot_index))


func delete_save(slot_index: int) -> bool:
	"""Delete a save file"""
	if slot_index < 0 or slot_index >= MAX_SAVE_SLOTS:
		return false
	
	var file_path = _get_save_path(slot_index)
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		var error = dir.remove(SAVE_FILE_PREFIX + str(slot_index) + SAVE_FILE_EXTENSION)
		if error == OK:
			save_deleted.emit(slot_index)
			print("[SaveManager] Deleted save slot %d" % slot_index)
			return true
	
	return false


func get_all_saves() -> Array[Dictionary]:
	"""Get info about all save slots"""
	var saves: Array[Dictionary] = []
	
	for i in range(MAX_SAVE_SLOTS):
		var save_info = get_save_info(i)
		saves.append(save_info)
	
	return saves


func get_save_info(slot_index: int) -> Dictionary:
	"""Get metadata about a save slot without loading full data"""
	var info: Dictionary = {
		"slot_index": slot_index,
		"exists": false,
		"save_name": "",
		"datetime": "",
		"timestamp": 0,
		"current_map": "",
		"play_time": "",
		"is_auto_save": slot_index == AUTO_SAVE_SLOT
	}
	
	if not does_save_exist(slot_index):
		return info
	
	var save_data = _read_save_file(slot_index)
	if not save_data:
		return info
	
	info["exists"] = true
	info["save_name"] = save_data.get("save_name", "")
	info["datetime"] = save_data.get("datetime", "")
	info["timestamp"] = int(save_data.get("timestamp", 0))  # Convert to int
	info["current_map"] = save_data.get("current_map", "")
	info["is_auto_save"] = save_data.get("is_auto_save", false)
	
	# Extract play time from player data
	var player_data = save_data.get("player_data", {})
	var play_time_seconds = float(player_data.get("play_time", 0.0))
	info["play_time"] = _format_play_time(play_time_seconds)
	
	# Calculate relative time (e.g., "2 hours ago")
	info["relative_time"] = _get_relative_time(int(info["timestamp"]))
	
	return info


func _get_most_recent_slot() -> int:
	"""Find the most recently saved slot"""
	var most_recent_slot = -1
	var most_recent_time: int = 0
	
	for i in range(MAX_SAVE_SLOTS):
		var info = get_save_info(i)
		if info["exists"]:
			var timestamp = int(info.get("timestamp", 0))
			if timestamp > most_recent_time:
				most_recent_time = timestamp
				most_recent_slot = i
	
	return most_recent_slot
#endregion

#region Settings (Separate from game saves)
func save_settings(settings: Dictionary) -> bool:
	"""Save game settings"""
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] Could not save settings")
		return false
	
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()
	print("[SaveManager] Settings saved")
	return true


func load_settings() -> Dictionary:
	"""Load game settings"""
	if not FileAccess.file_exists(SETTINGS_FILE):
		return _get_default_settings()
	
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if not file:
		return _get_default_settings()
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return _get_default_settings()
	
	print("[SaveManager] Settings loaded")
	return json.data


func _get_default_settings() -> Dictionary:
	"""Default settings"""
	return {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"fullscreen": false,
		"vsync": true,
		"language": "en",
		"show_fps": false
	}
#endregion

#region Utility Functions
func _format_play_time(seconds: float) -> String:
	"""Format seconds into HH:MM:SS"""
	var hours = int(seconds / 3600)
	var minutes = int(fmod(seconds, 3600) / 60)
	var secs = int(fmod(seconds, 60))
	return "%02d:%02d:%02d" % [hours, minutes, secs]


func _get_relative_time(timestamp: int) -> String:
	"""Get relative time string (e.g., '2 hours ago')"""
	var now = Time.get_unix_time_from_system()
	var diff = now - timestamp
	
	if diff < 60:
		return "Just now"
	elif diff < 3600:
		var minutes = int(diff / 60)
		return "%d minute%s ago" % [minutes, "s" if minutes > 1 else ""]
	elif diff < 86400:
		var hours = int(diff / 3600)
		return "%d hour%s ago" % [hours, "s" if hours > 1 else ""]
	elif diff < 604800:
		var days = int(diff / 86400)
		return "%d day%s ago" % [days, "s" if days > 1 else ""]
	else:
		var weeks = int(diff / 604800)
		return "%d week%s ago" % [weeks, "s" if weeks > 1 else ""]
#endregion

#region Debug
func print_save_debug_info() -> void:
	"""Print debug info about all saves"""
	print("\n=== SAVE DEBUG INFO ===")
	var saves = get_all_saves()
	for save in saves:
		if save["exists"]:
			print("Slot %d: %s | %s | %s" % [
				save["slot_index"],
				save["save_name"],
				save["current_map"],
				save["relative_time"]
			])
		else:
			print("Slot %d: [Empty]" % save["slot_index"])
	print("========================\n")
#endregion

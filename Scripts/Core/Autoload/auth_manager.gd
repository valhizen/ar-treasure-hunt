extends Node
## AuthManager - Handles team authentication and session management
## AutoLoad Singleton

#region Signals
signal login_completed(user_data: Dictionary)
signal login_failed(error: String)
signal logout_completed
signal session_restored(user_data: Dictionary)
signal session_invalid
signal progress_loaded_from_server
#endregion

#region State
var is_logged_in: bool = false
var current_team: Dictionary = {}
var auth_token: String = ""
var team_id: int = 0
var team_code: String = ""
var team_name: String = ""
#endregion

#region Constants
const TOKEN_STORAGE_KEY: String = "user://auth_token.dat"
const TEAM_STORAGE_KEY: String = "user://team_data.dat"
#endregion


func _ready() -> void:
	_load_stored_session()
	print("[AuthManager] Initialized - Team Login System")


#region Session Persistence
func _load_stored_session() -> void:
	"""Load stored auth token and validate"""
	if not FileAccess.file_exists(TOKEN_STORAGE_KEY):
		session_invalid.emit()
		return
	
	var token_file = FileAccess.open(TOKEN_STORAGE_KEY, FileAccess.READ)
	if not token_file:
		session_invalid.emit()
		return
	
	auth_token = token_file.get_as_text().strip_edges()
	token_file.close()
	
	if auth_token.is_empty():
		session_invalid.emit()
		return
	
	# Load stored team data
	if FileAccess.file_exists(TEAM_STORAGE_KEY):
		var team_file = FileAccess.open(TEAM_STORAGE_KEY, FileAccess.READ)
		if team_file:
			var json = JSON.new()
			if json.parse(team_file.get_as_text()) == OK:
				current_team = json.data
				team_id = current_team.get("id", 0)
				team_code = current_team.get("team_code", "")
				team_name = current_team.get("team_name", "")
			team_file.close()
	
	# Set token in NetworkManager
	NetworkManager.set_auth_token(auth_token)
	
	# Validate with server
	_validate_session()


func _validate_session() -> void:
	"""Validate stored session with server"""
	var response = await NetworkManager.api_get("/auth/team/me")
	
	if response.success:
		current_team = response.data
		team_id = current_team.get("id", 0)
		team_code = current_team.get("team_code", "")
		team_name = current_team.get("team_name", "")
		is_logged_in = true
		_store_team_data(current_team)
		session_restored.emit(current_team)
		print("[AuthManager] Session valid for team: %s" % team_name)
		
		# Load progress from server
		await _load_progress_from_server()
	else:
		_clear_stored_session()
		session_invalid.emit()
		print("[AuthManager] Session invalid, cleared")


func _store_session(token: String, team: Dictionary) -> void:
	"""Store auth token and team data"""
	auth_token = token
	current_team = team
	team_id = team.get("id", 0)
	team_code = team.get("team_code", "")
	team_name = team.get("team_name", "")
	
	var token_file = FileAccess.open(TOKEN_STORAGE_KEY, FileAccess.WRITE)
	if token_file:
		token_file.store_string(token)
		token_file.close()
	
	_store_team_data(team)
	
	NetworkManager.set_auth_token(token)


func _store_team_data(team: Dictionary) -> void:
	"""Store team data separately"""
	var team_file = FileAccess.open(TEAM_STORAGE_KEY, FileAccess.WRITE)
	if team_file:
		team_file.store_string(JSON.stringify(team))
		team_file.close()


func _clear_stored_session() -> void:
	"""Clear stored session data"""
	auth_token = ""
	current_team = {}
	team_id = 0
	team_code = ""
	team_name = ""
	is_logged_in = false
	
	var dir = DirAccess.open("user://")
	if dir:
		if dir.file_exists("auth_token.dat"):
			dir.remove("auth_token.dat")
		if dir.file_exists("team_data.dat"):
			dir.remove("team_data.dat")
	
	NetworkManager.clear_auth()
#endregion


#region Team Authentication
func login_with_team(input_team_name: String, input_team_code: String) -> Dictionary:
	"""Login with team name and team code"""
	var response = await NetworkManager.api_post("/auth/team/login", {
		"team_name": input_team_name,
		"team_code": input_team_code
	})
	
	if response.success:
		_store_session(response.data.get("token", ""), response.data.get("team", {}))
		is_logged_in = true
		login_completed.emit(current_team)
		print("[AuthManager] Team logged in: %s (ID: %d, Code: %s)" % [team_name, team_id, team_code])
		
		# Load progress from server after login
		await _load_progress_from_server()
	else:
		var error_msg = response.get("error", "Invalid team name or code")
		login_failed.emit(error_msg)
	
	return response


func set_guest_mode() -> void:
	"""Set guest mode without backend"""
	is_logged_in = false
	team_name = "Guest"
	team_code = "GUEST"
	team_id = 0
	current_team = {
		"team_name": "Guest",
		"team_code": "GUEST",
		"is_guest": true
	}
	print("[AuthManager] Guest mode activated")


func logout() -> void:
	"""Logout current team"""
	# Sync progress before logout
	if is_logged_in:
		var score_manager = get_node_or_null("/root/ScoreManager")
		if score_manager and score_manager.has_method("sync_progress"):
			await score_manager.sync_progress()
	
	await NetworkManager.api_post("/auth/logout", {})
	_clear_stored_session()
	logout_completed.emit()
	print("[AuthManager] Logged out")
#endregion


#region Progress Sync
func _load_progress_from_server() -> void:
	"""
	Load progress from server and create local save.
	This ensures Continue button works on web after browser restart.
	"""
	if not is_logged_in:
		return
	
	print("[AuthManager] Loading progress from server...")
	
	var response = await NetworkManager.api_get("/progress/load")
	
	if response.success and response.data.get("player_data") != null:
		var server_player_data = response.data.get("player_data", {})
		
		if not server_player_data.is_empty():
			print("[AuthManager] Server has saved progress, restoring...")
			
			# 1. Load into PlayerData singleton
			var player_data = get_node_or_null("/root/PlayerData")
			if player_data and player_data.has_method("load_from_dictionary"):
				player_data.load_from_dictionary(server_player_data)
				print("[AuthManager] PlayerData restored from server")
			
			# 2. Create local save file so Continue button works
			var save_manager = get_node_or_null("/root/SaveManager")
			if save_manager:
				# Get map and position from server data
				var current_map = server_player_data.get("last_map", "")
				var map_positions = server_player_data.get("map_positions", {})
				var position = Vector2.ZERO
				
				# Try to get position for the last map
				if not current_map.is_empty() and map_positions.has(current_map):
					var pos_data = map_positions[current_map]
					if pos_data is Array and pos_data.size() >= 2:
						position = Vector2(float(pos_data[0]), float(pos_data[1]))
					elif pos_data is Dictionary:
						position = Vector2(float(pos_data.get("x", 0)), float(pos_data.get("y", 0)))
				
				# If no map, use a default
				if current_map.is_empty():
					current_map = "main_character_house"
				
				# Create save data
				var save_data = {
					"save_name": "Cloud Save",
					"timestamp": Time.get_unix_time_from_system(),
					"datetime": Time.get_datetime_string_from_system(),
					"current_map": current_map,
					"player_position": {
						"x": position.x,
						"y": position.y
					},
					"player_data": server_player_data,
					"game_version": ProjectSettings.get_setting("application/config/version", "1.0.0"),
					"is_auto_save": true,
					"is_cloud_save": true
				}
				
				# Write to auto-save slot (0)
				if save_manager.has_method("_write_save_file"):
					save_manager._write_save_file(0, save_data)
					print("[AuthManager] Created local save from server data (slot 0)")
					
					# Also write to slot 1 for manual continue
					save_manager._write_save_file(1, save_data)
					print("[AuthManager] Created local save from server data (slot 1)")
			
			progress_loaded_from_server.emit()
		else:
			print("[AuthManager] Server has no saved progress (new team)")
	else:
		print("[AuthManager] Could not load from server or no data: %s" % response.get("error", ""))
#endregion


#region Utility
func get_team_id() -> int:
	return team_id


func get_team_name() -> String:
	return team_name


func get_team_code() -> String:
	return team_code


func get_display_name() -> String:
	return team_name


func is_guest() -> bool:
	return current_team.get("is_guest", false)
#endregion

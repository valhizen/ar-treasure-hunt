extends Node
## AuthManager - Handles team authentication and session management
## AutoLoad Singleton
## UPDATED: Now supports player names (max 3 players per team)

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
var current_player: Dictionary = {}
var auth_token: String = ""
var team_id: int = 0
var team_code: String = ""
var team_name: String = ""
var player_id: String = ""
var player_name: String = ""
#endregion

#region Constants
const TOKEN_STORAGE_KEY: String = "user://auth_token.dat"
const TEAM_STORAGE_KEY: String = "user://team_data.dat"
const PLAYER_STORAGE_KEY: String = "user://player_data.dat"
#endregion


func _ready() -> void:
	_load_stored_session()
	print("[AuthManager] Initialized - Team Login System with Player Names")


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
	
	# Load stored player data
	if FileAccess.file_exists(PLAYER_STORAGE_KEY):
		var player_file = FileAccess.open(PLAYER_STORAGE_KEY, FileAccess.READ)
		if player_file:
			var json = JSON.new()
			if json.parse(player_file.get_as_text()) == OK:
				current_player = json.data
				player_id = current_player.get("id", "")
				player_name = current_player.get("player_name", "")
			player_file.close()
	
	# Set token in NetworkManager
	NetworkManager.set_auth_token(auth_token)
	
	# Validate with server
	_validate_session()


func _validate_session() -> void:
	"""Validate stored session with server"""
	var response = await NetworkManager.api_get("/auth/team/me")
	
	if response.success:
		# Handle new format with player and team
		if response.data.has("player"):
			current_player = response.data.player
			player_id = current_player.get("id", "")
			player_name = current_player.get("player_name", "")
			_store_player_data(current_player)
		
		if response.data.has("team"):
			current_team = response.data.team
			team_id = current_team.get("id", 0)
			team_code = current_team.get("team_code", "")
			team_name = current_team.get("team_name", "")
			_store_team_data(current_team)
		else:
			# Legacy format (backwards compatibility)
			current_team = response.data
			team_id = current_team.get("id", 0)
			team_code = current_team.get("team_code", "")
			team_name = current_team.get("team_name", "")
			_store_team_data(current_team)
		
		is_logged_in = true
		
		# Build combined user data for signal
		var user_data = _build_user_data()
		session_restored.emit(user_data)
		print("[AuthManager] Session valid for player: %s (Team: %s)" % [get_player_name(), team_name])
		
		# Load progress from server
		await _load_progress_from_server()
	else:
		_clear_stored_session()
		session_invalid.emit()
		print("[AuthManager] Session invalid, cleared")


func _store_session(token: String, team: Dictionary, player: Dictionary = {}) -> void:
	"""Store auth token, team data, and player data"""
	auth_token = token
	current_team = team
	team_id = team.get("id", 0)
	team_code = team.get("team_code", "")
	team_name = team.get("team_name", "")
	
	if not player.is_empty():
		current_player = player
		player_id = player.get("id", "")
		player_name = player.get("player_name", "")
	
	var token_file = FileAccess.open(TOKEN_STORAGE_KEY, FileAccess.WRITE)
	if token_file:
		token_file.store_string(token)
		token_file.close()
	
	_store_team_data(team)
	
	if not player.is_empty():
		_store_player_data(player)
	
	NetworkManager.set_auth_token(token)


func _store_team_data(team: Dictionary) -> void:
	"""Store team data separately"""
	var team_file = FileAccess.open(TEAM_STORAGE_KEY, FileAccess.WRITE)
	if team_file:
		team_file.store_string(JSON.stringify(team))
		team_file.close()


func _store_player_data(player: Dictionary) -> void:
	"""Store player data separately"""
	var player_file = FileAccess.open(PLAYER_STORAGE_KEY, FileAccess.WRITE)
	if player_file:
		player_file.store_string(JSON.stringify(player))
		player_file.close()


func _clear_stored_session() -> void:
	"""Clear stored session data"""
	auth_token = ""
	current_team = {}
	current_player = {}
	team_id = 0
	team_code = ""
	team_name = ""
	player_id = ""
	player_name = ""
	is_logged_in = false
	
	var dir = DirAccess.open("user://")
	if dir:
		if dir.file_exists("auth_token.dat"):
			dir.remove("auth_token.dat")
		if dir.file_exists("team_data.dat"):
			dir.remove("team_data.dat")
		if dir.file_exists("player_data.dat"):
			dir.remove("player_data.dat")
	
	NetworkManager.clear_auth()


func _build_user_data() -> Dictionary:
	"""Build combined user data dictionary for signals"""
	return {
		"player_id": player_id,
		"player_name": player_name,
		"team_id": team_id,
		"team_name": team_name,
		"team_code": team_code,
		"player_count": current_team.get("player_count", 0),
		"max_players": current_team.get("max_players", 3),
		"type": "team_player"
	}
#endregion


#region Team Authentication
func login_with_team(input_team_name: String, input_team_code: String, input_player_name: String = "") -> Dictionary:
	"""Login with team name, team code, and player name"""
	
	# Build request data
	var request_data = {
		"team_name": input_team_name,
		"team_code": input_team_code
	}
	
	# Add player name if provided
	if not input_player_name.is_empty():
		request_data["player_name"] = input_player_name
	
	var response = await NetworkManager.api_post("/auth/team/login", request_data)
	
	if response.success:
		var token = response.data.get("token", "")
		var team_data = response.data.get("team", {})
		var player_data = response.data.get("player", {})
		
		_store_session(token, team_data, player_data)
		is_logged_in = true
		
		var user_data = _build_user_data()
		login_completed.emit(user_data)
		
		print("[AuthManager] ✓ Login successful!")
		print("  Player: %s (ID: %s)" % [player_name, player_id])
		print("  Team: %s (ID: %d, Code: %s)" % [team_name, team_id, team_code])
		print("  Players in team: %d/%d" % [team_data.get("player_count", 0), team_data.get("max_players", 3)])
		
		# Load progress from server after login
		await _load_progress_from_server()
	else:
		var error_msg = response.get("error", "Invalid team name or code")
		
		# Check for team full error code
		
		
		login_failed.emit(error_msg)
	
	return response


func set_guest_mode() -> void:
	"""Set guest mode without backend"""
	is_logged_in = false
	team_name = "Guest"
	team_code = "GUEST"
	team_id = 0
	player_name = "Guest"
	player_id = "guest_local"
	current_team = {
		"team_name": "Guest",
		"team_code": "GUEST",
		"is_guest": true
	}
	current_player = {
		"id": "guest_local",
		"player_name": "Guest",
		"is_guest": true
	}
	print("[AuthManager] Guest mode activated")


func logout() -> void:
	"""Logout current player"""
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
			var player_data_node = get_node_or_null("/root/PlayerData")
			if player_data_node and player_data_node.has_method("load_from_dictionary"):
				player_data_node.load_from_dictionary(server_player_data)
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
					"save_name": "Cloud Save - %s" % player_name,
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
					"is_cloud_save": true,
					"player_name": player_name,
					"team_name": team_name
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
			print("[AuthManager] Server has no saved progress (new player)")
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


func get_player_id() -> String:
	return player_id


func get_player_name() -> String:
	"""Get the current player's name"""
	if not player_name.is_empty():
		return player_name
	# Fallback to team name for legacy sessions
	return team_name


func get_display_name() -> String:
	"""Get display name - player name if available, otherwise team name"""
	if not player_name.is_empty():
		return player_name
	return team_name


func get_full_display_name() -> String:
	"""Get full display name with team: 'PlayerName (TeamName)'"""
	if not player_name.is_empty() and not team_name.is_empty():
		return "%s (%s)" % [player_name, team_name]
	return get_display_name()


func is_guest() -> bool:
	return current_team.get("is_guest", false) or current_player.get("is_guest", false)


func get_player_count() -> int:
	"""Get current number of players in team"""
	return current_team.get("player_count", 0)


func get_max_players() -> int:
	"""Get maximum players allowed per team"""
	return current_team.get("max_players", 3)
#endregion

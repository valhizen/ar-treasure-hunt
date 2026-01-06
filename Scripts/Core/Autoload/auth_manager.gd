extends Node
## AuthManager - Handles authentication and session management
## AutoLoad Singleton

#region Signals
signal login_completed(user_data: Dictionary)
signal login_failed(error: String)
signal logout_completed
signal session_restored(user_data: Dictionary)
signal session_invalid
signal event_verified(event_data: Dictionary)
signal event_verification_failed(error: String)
signal progress_loaded_from_server  # NEW: Emitted when server progress is loaded
#endregion

#region State
var is_logged_in: bool = false
var current_user: Dictionary = {}
var current_event: Dictionary = {}
var auth_token: String = ""
#endregion

#region Constants
const TOKEN_STORAGE_KEY: String = "user://auth_token.dat"
const USER_STORAGE_KEY: String = "user://user_data.dat"
#endregion


func _ready() -> void:
	_load_stored_session()
	print("[AuthManager] Initialized")


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
	
	# Load stored user data
	if FileAccess.file_exists(USER_STORAGE_KEY):
		var user_file = FileAccess.open(USER_STORAGE_KEY, FileAccess.READ)
		if user_file:
			var json = JSON.new()
			if json.parse(user_file.get_as_text()) == OK:
				current_user = json.data
			user_file.close()
	
	# Set token in NetworkManager
	NetworkManager.set_auth_token(auth_token)
	
	# Validate with server
	_validate_session()


func _validate_session() -> void:
	"""Validate stored session with server"""
	var response = await NetworkManager.api_get("/auth/me")
	
	if response.success:
		current_user = response.data
		is_logged_in = true
		_store_user_data(current_user)
		session_restored.emit(current_user)
		print("[AuthManager] Session valid for: %s" % current_user.get("display_name", "Unknown"))
		
		# ========== KEY FIX: Load progress from server after session restore ==========
		await _load_progress_from_server()
	else:
		_clear_stored_session()
		session_invalid.emit()
		print("[AuthManager] Session invalid, cleared")


func _store_session(token: String, user: Dictionary) -> void:
	"""Store auth token and user data"""
	auth_token = token
	current_user = user
	
	var token_file = FileAccess.open(TOKEN_STORAGE_KEY, FileAccess.WRITE)
	if token_file:
		token_file.store_string(token)
		token_file.close()
	
	_store_user_data(user)
	
	NetworkManager.set_auth_token(token)


func _store_user_data(user: Dictionary) -> void:
	"""Store user data separately"""
	var user_file = FileAccess.open(USER_STORAGE_KEY, FileAccess.WRITE)
	if user_file:
		user_file.store_string(JSON.stringify(user))
		user_file.close()


func _clear_stored_session() -> void:
	"""Clear stored session data"""
	auth_token = ""
	current_user = {}
	is_logged_in = false
	
	var dir = DirAccess.open("user://")
	if dir:
		if dir.file_exists("auth_token.dat"):
			dir.remove("auth_token.dat")
		if dir.file_exists("user_data.dat"):
			dir.remove("user_data.dat")
	
	NetworkManager.clear_auth()
#endregion


#region Authentication Methods
func register(email: String, password: String, display_name: String) -> Dictionary:
	"""Register new user"""
	var response = await NetworkManager.api_post("/auth/register", {
		"email": email,
		"password": password,
		"display_name": display_name
	})
	
	if response.success:
		_store_session(response.data.get("token", ""), response.data.get("user", {}))
		is_logged_in = true
		login_completed.emit(current_user)
		print("[AuthManager] Registered: %s" % display_name)
	else:
		login_failed.emit(response.get("error", "Registration failed"))
	
	return response


func login(email: String, password: String) -> Dictionary:
	"""Login with email and password"""
	var response = await NetworkManager.api_post("/auth/login", {
		"email": email,
		"password": password
	})
	
	if response.success:
		_store_session(response.data.get("token", ""), response.data.get("user", {}))
		is_logged_in = true
		login_completed.emit(current_user)
		print("[AuthManager] Logged in: %s" % current_user.get("display_name", "Unknown"))
		
		# ========== KEY FIX: Load progress from server after login ==========
		await _load_progress_from_server()
	else:
		login_failed.emit(response.get("error", "Login failed"))
	
	return response


func login_as_guest() -> Dictionary:
	"""Login as guest"""
	var response = await NetworkManager.api_post("/auth/guest", {})
	
	if response.success:
		_store_session(response.data.get("token", ""), response.data.get("user", {}))
		is_logged_in = true
		current_user["is_guest"] = true
		login_completed.emit(current_user)
		print("[AuthManager] Guest login: %s" % current_user.get("display_name", "Guest"))
		
		# Guest users also get progress loaded (if they had any from before)
		await _load_progress_from_server()
	else:
		login_failed.emit(response.get("error", "Guest login failed"))
	
	return response


func logout() -> void:
	"""Logout current user"""
	# Sync progress before logout
	if is_logged_in:
		await ScoreManager.sync_progress()
	
	await NetworkManager.api_post("/auth/logout", {})
	_clear_stored_session()
	logout_completed.emit()
	print("[AuthManager] Logged out")
#endregion


#region Event Code
func verify_event_code(code: String) -> Dictionary:
	"""Verify an event code"""
	var response = await NetworkManager.api_post("/event/verify-code", {
		"code": code
	})
	
	if response.success:
		current_event = response.data
		event_verified.emit(current_event)
		print("[AuthManager] Event code valid: %s - %s" % [
			current_event.get("code", ""),
			current_event.get("event_name", "")
		])
	else:
		event_verification_failed.emit(response.get("error", "Invalid code"))
	
	return response


func is_event_active() -> bool:
	"""Check if an event is currently active"""
	if current_event.is_empty():
		return false
	
	var valid_until = current_event.get("valid_until", "")
	if valid_until.is_empty():
		return true
	
	# Parse ISO date and compare
	var now = Time.get_unix_time_from_system()
	var event_time = Time.get_unix_time_from_datetime_string(valid_until)
	return now < event_time


func get_event_code() -> String:
	"""Get current event code"""
	return current_event.get("code", "")
#endregion


#region Progress Sync - KEY FIX
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
func get_user_id() -> String:
	return current_user.get("id", "")


func get_display_name() -> String:
	return current_user.get("display_name", "Guest")


func is_guest() -> bool:
	return current_user.get("is_guest", false)
#endregion

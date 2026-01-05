extends Node
## AuthManager - Handles user authentication and event codes
## AutoLoad Singleton - UPDATED to connect with PlayerData

#region Signals
signal login_success(user_data: Dictionary)
signal login_failed(error: String)
signal registration_success(user_data: Dictionary)
signal registration_failed(error: String)
signal logout_completed
signal event_code_valid(event_data: Dictionary)
signal event_code_invalid(error: String)
#endregion

#region State
var is_logged_in: bool = false
var current_user: Dictionary = {}
var current_event: Dictionary = {}
var auth_token: String = ""
#endregion

#region Constants
const TOKEN_SAVE_PATH: String = "user://auth_token.dat"
const USER_SAVE_PATH: String = "user://user_data.dat"
#endregion

func _ready() -> void:
	# Try to restore previous session
	_load_saved_session()
	print("[AuthManager] Initialized")


#region Authentication
func register(email: String, password: String, display_name: String) -> Dictionary:
	"""Register a new user"""
	var data = {
		"email": email,
		"password": password,
		"display_name": display_name
	}
	
	var response = await NetworkManager.api_post("/auth/register", data)
	
	if response.success:
		var user_data = response.data
		_handle_auth_success(user_data)
		registration_success.emit(user_data)
		print("[AuthManager] Registration successful: %s" % email)
	else:
		registration_failed.emit(response.error)
		print("[AuthManager] Registration failed: %s" % response.error)
	
	return response


func login(email: String, password: String) -> Dictionary:
	"""Login with email and password"""
	var data = {
		"email": email,
		"password": password
	}
	
	var response = await NetworkManager.api_post("/auth/login", data)
	
	if response.success:
		var user_data = response.data
		_handle_auth_success(user_data)
		login_success.emit(user_data)
		print("[AuthManager] Login successful: %s" % email)
	else:
		login_failed.emit(response.error)
		print("[AuthManager] Login failed: %s" % response.error)
	
	return response


func logout() -> void:
	"""Logout current user"""
	# Sync progress before logout
	if is_logged_in:
		await ScoreManager.sync_progress()
	
	# Notify server
	await NetworkManager.api_post("/auth/logout", {})
	
	# Clear local state
	is_logged_in = false
	current_user = {}
	current_event = {}
	auth_token = ""
	
	NetworkManager.clear_auth()
	_delete_saved_session()
	
	# Reset PlayerData identity (but keep progress for offline play)
	if PlayerData:
		PlayerData.player_id = ""
		PlayerData.player_email = ""
		# Keep display_name for offline
	
	logout_completed.emit()
	print("[AuthManager] Logged out")


func _handle_auth_success(user_data: Dictionary) -> void:
	"""Handle successful authentication - CONNECTS TO PLAYERDATA"""
	is_logged_in = true
	current_user = user_data.get("user", user_data)
	auth_token = user_data.get("token", "")
	
	if not auth_token.is_empty():
		NetworkManager.set_auth_token(auth_token)
		_save_session()
	
	# ═══════════════════════════════════════════════════════════════════
	# THIS IS WHERE PLAYERDATA GETS UPDATED WITH USER INFO
	# ═══════════════════════════════════════════════════════════════════
	if PlayerData:
		PlayerData.player_id = str(current_user.get("id", ""))
		PlayerData.display_name = current_user.get("display_name", "Player")
		PlayerData.player_email = current_user.get("email", "")
		PlayerData.player_name = current_user.get("display_name", "Player")
		print("[AuthManager] PlayerData updated with user info")
	
	# Load progress from server (if exists)
	_load_server_progress()


func _load_server_progress() -> void:
	"""Load player progress from server"""
	var response = await NetworkManager.api_get("/progress/load")
	
	if response.success and response.data.get("player_data"):
		var server_data = response.data["player_data"]
		
		# Check if server has more progress than local
		var server_score = server_data.get("total_score", 0)
		var local_score = PlayerData.total_score if PlayerData else 0
		
		if server_score > local_score:
			print("[AuthManager] Loading progress from server (server has more progress)")
			if PlayerData:
				PlayerData.load_from_dictionary(server_data)
		else:
			print("[AuthManager] Keeping local progress (local has more progress)")


func check_session() -> Dictionary:
	"""Check if current session is still valid"""
	if auth_token.is_empty():
		return {"success": false, "error": "No token"}
	
	var response = await NetworkManager.api_get("/auth/me")
	
	if response.success:
		current_user = response.data
		is_logged_in = true
		
		# Update PlayerData
		if PlayerData:
			PlayerData.player_id = str(current_user.get("id", ""))
			PlayerData.display_name = current_user.get("display_name", "Player")
			PlayerData.player_email = current_user.get("email", "")
		
		print("[AuthManager] Session valid for: %s" % current_user.get("display_name", "Unknown"))
	else:
		# Token expired or invalid
		logout()
	
	return response
#endregion

#region Event Code System
func verify_event_code(code: String) -> Dictionary:
	"""Verify an event code from organizer"""
	var data = {"code": code}
	
	var response = await NetworkManager.api_post("/event/verify-code", data)
	
	if response.success:
		current_event = response.data
		event_code_valid.emit(response.data)
		print("[AuthManager] Event code valid: %s - %s" % [code, response.data.get("event_name", "")])
	else:
		event_code_invalid.emit(response.error)
		print("[AuthManager] Event code invalid: %s" % response.error)
	
	return response


func get_event_info() -> Dictionary:
	"""Get current event information"""
	if current_event.is_empty():
		return {"success": false, "error": "No event active"}
	return {"success": true, "data": current_event}


func is_event_active() -> bool:
	"""Check if user has valid event access"""
	return not current_event.is_empty()


func get_event_code() -> String:
	"""Get current event code"""
	return current_event.get("code", "")
#endregion

#region Guest Mode
func login_as_guest() -> Dictionary:
	"""Login as guest (limited features, scores not saved permanently)"""
	var response = await NetworkManager.api_post("/auth/guest", {"guest": true})
	
	if response.success:
		is_logged_in = true
		current_user = response.data.get("user", response.data)
		current_user["is_guest"] = true
		auth_token = response.data.get("token", "")
		
		if not auth_token.is_empty():
			NetworkManager.set_auth_token(auth_token)
		
		# Update PlayerData for guest
		if PlayerData:
			PlayerData.player_id = str(current_user.get("id", ""))
			PlayerData.display_name = current_user.get("display_name", "Guest")
			PlayerData.player_name = "Guest"
		
		print("[AuthManager] Guest login successful")
	
	return response


func is_guest() -> bool:
	"""Check if current user is a guest"""
	return current_user.get("is_guest", false)
#endregion

#region Session Persistence
func _save_session() -> void:
	"""Save auth token and user data locally"""
	# Save token
	var token_file = FileAccess.open(TOKEN_SAVE_PATH, FileAccess.WRITE)
	if token_file:
		token_file.store_string(auth_token)
		token_file.close()
	
	# Save user data
	var user_file = FileAccess.open(USER_SAVE_PATH, FileAccess.WRITE)
	if user_file:
		user_file.store_string(JSON.stringify(current_user))
		user_file.close()


func _load_saved_session() -> void:
	"""Load saved auth token and user data"""
	# Load token
	if FileAccess.file_exists(TOKEN_SAVE_PATH):
		var token_file = FileAccess.open(TOKEN_SAVE_PATH, FileAccess.READ)
		if token_file:
			auth_token = token_file.get_as_text()
			token_file.close()
			
			if not auth_token.is_empty():
				NetworkManager.set_auth_token(auth_token)
	
	# Load user data
	if FileAccess.file_exists(USER_SAVE_PATH):
		var user_file = FileAccess.open(USER_SAVE_PATH, FileAccess.READ)
		if user_file:
			var json = JSON.new()
			if json.parse(user_file.get_as_text()) == OK:
				current_user = json.data
			user_file.close()


func _delete_saved_session() -> void:
	"""Delete saved session data"""
	if FileAccess.file_exists(TOKEN_SAVE_PATH):
		DirAccess.remove_absolute(TOKEN_SAVE_PATH)
	if FileAccess.file_exists(USER_SAVE_PATH):
		DirAccess.remove_absolute(USER_SAVE_PATH)
#endregion

#region Utility
func get_user_id() -> String:
	"""Get current user ID"""
	return str(current_user.get("id", ""))


func get_display_name() -> String:
	"""Get current user display name"""
	return current_user.get("display_name", "Guest")


func get_email() -> String:
	"""Get current user email"""
	return current_user.get("email", "")
#endregion

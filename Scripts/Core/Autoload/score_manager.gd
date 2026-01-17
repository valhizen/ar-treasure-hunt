extends Node
## ScoreManager - Handles online score storage and leaderboard
## AutoLoad Singleton

#region Signals
signal score_submitted(minigame_id: String, score: int)
signal score_submit_failed(error: String)
signal leaderboard_loaded(leaderboard: Array)
signal leaderboard_load_failed(error: String)
signal progress_synced
signal progress_sync_failed(error: String)
#endregion

#region State
var cached_leaderboard: Dictionary = {}  # minigame_id -> leaderboard array
var pending_scores: Array = []  # Scores to submit when online
var last_sync_time: int = 0
#endregion

#region Constants
const PENDING_SCORES_PATH: String = "user://pending_scores.json"
const SYNC_INTERVAL: float = 30.0  # Sync every 30 seconds
#endregion

var sync_timer: float = 0.0

func _ready() -> void:
	_load_pending_scores()
	print("[ScoreManager] Initialized")


func _process(delta: float) -> void:
	# Periodic sync
	if AuthManager.is_logged_in:
		sync_timer += delta
		if sync_timer >= SYNC_INTERVAL:
			sync_timer = 0.0
			_try_submit_pending_scores()


#region Score Submission
func submit_score(minigame_id: String, score: int, extra_data: Dictionary = {}) -> Dictionary:
	"""Submit a score to the server"""
	if not AuthManager.is_logged_in:
		# Queue for later
		_queue_pending_score(minigame_id, score, extra_data)
		return {"success": false, "error": "Not logged in, score queued"}
	
	var data = {
		"minigame_id": minigame_id,
		"score": score,
		"event_code": AuthManager.team_code,  # FIXED: Use team_code instead of current_event
		"timestamp": Time.get_unix_time_from_system(),
		"extra_data": extra_data
	}
	
	var response = await NetworkManager.api_post("/scores/submit", data)
	
	if response.success:
		score_submitted.emit(minigame_id, score)
		print("[ScoreManager] Score submitted: %s = %d" % [minigame_id, score])
		
		# Update local cache
		_update_local_best(minigame_id, score)
	else:
		# Queue for retry
		_queue_pending_score(minigame_id, score, extra_data)
		score_submit_failed.emit(response.error)
		print("[ScoreManager] Score submit failed: %s" % response.error)
	
	return response


func submit_minigame_result(minigame_id: String, result) -> Dictionary:
	"""Submit a MinigameResult to server"""
	var score = 0
	var extra_data = {}
	
	if result is Resource:
		score = result.get("score") if result.get("score") != null else 0
		extra_data = {
			"time_taken": result.get("time_taken") if result.get("time_taken") != null else 0,
			"stars": result.get("stars") if result.get("stars") != null else 0,
			"success": result.get("success") if result.get("success") != null else false
		}
	elif result is Dictionary:
		score = result.get("score", 0)
		extra_data = {
			"time_taken": result.get("time_taken", 0),
			"stars": result.get("stars", 0),
			"success": result.get("success", false)
		}
	
	return await submit_score(minigame_id, score, extra_data)
#endregion

#region Leaderboard
func get_leaderboard(minigame_id: String, limit: int = 10) -> Dictionary:
	"""Get leaderboard for a minigame"""
	var endpoint = "/scores/leaderboard/%s?limit=%d" % [minigame_id, limit]
	
	var response = await NetworkManager.api_get(endpoint)
	
	if response.success:
		cached_leaderboard[minigame_id] = response.data
		leaderboard_loaded.emit(response.data)
		print("[ScoreManager] Leaderboard loaded: %s" % minigame_id)
	else:
		leaderboard_load_failed.emit(response.error)
		print("[ScoreManager] Leaderboard load failed: %s" % response.error)
	
	return response


func get_global_leaderboard(limit: int = 50) -> Dictionary:
	"""Get overall leaderboard (total scores)"""
	var endpoint = "/scores/leaderboard/global?limit=%d" % limit
	
	var response = await NetworkManager.api_get(endpoint)
	
	if response.success:
		cached_leaderboard["global"] = response.data
		leaderboard_loaded.emit(response.data)
	else:
		leaderboard_load_failed.emit(response.error)
	
	return response


func get_event_leaderboard(limit: int = 50) -> Dictionary:
	"""Get leaderboard for current event"""
	if not AuthManager.is_logged_in:  # FIXED: Use is_logged_in instead of is_event_active()
		return {"success": false, "error": "Not logged in"}
	
	var event_code = AuthManager.team_code  # FIXED: Use team_code instead of current_event
	var endpoint = "/scores/leaderboard/event/%s?limit=%d" % [event_code, limit]
	
	var response = await NetworkManager.api_get(endpoint)
	
	if response.success:
		cached_leaderboard["event"] = response.data
		leaderboard_loaded.emit(response.data)
	
	return response


func get_my_rank(minigame_id: String) -> Dictionary:
	"""Get current user's rank in a minigame"""
	var endpoint = "/scores/my-rank/%s" % minigame_id
	return await NetworkManager.api_get(endpoint)


func get_my_scores() -> Dictionary:
	"""Get all scores for current user"""
	return await NetworkManager.api_get("/scores/my-scores")
#endregion

#region Progress Sync
func sync_progress() -> Dictionary:
	"""Sync local progress with server"""
	if not AuthManager.is_logged_in:
		return {"success": false, "error": "Not logged in"}
	
	var local_data = PlayerData.to_dictionary()
	
	var response = await NetworkManager.api_post("/progress/sync", {
		"player_data": local_data,
		"timestamp": Time.get_unix_time_from_system()
	})
	
	if response.success:
		last_sync_time = Time.get_unix_time_from_system()
		progress_synced.emit()
		print("[ScoreManager] Progress synced")
		
		# Check if server has newer data
		var server_data = response.data.get("player_data", null)
		if server_data and response.data.get("use_server_data", false):
			PlayerData.load_from_dictionary(server_data)
			print("[ScoreManager] Loaded newer data from server")
	else:
		progress_sync_failed.emit(response.error)
	
	return response


func load_progress_from_server() -> Dictionary:
	"""Load progress from server (overwrites local)"""
	if not AuthManager.is_logged_in:
		return {"success": false, "error": "Not logged in"}
	
	var response = await NetworkManager.api_get("/progress/load")
	
	if response.success and response.data.has("player_data"):
		PlayerData.load_from_dictionary(response.data["player_data"])
		print("[ScoreManager] Progress loaded from server")
	
	return response
#endregion

#region Pending Scores (Offline Support)
func _queue_pending_score(minigame_id: String, score: int, extra_data: Dictionary) -> void:
	"""Queue score for later submission"""
	pending_scores.append({
		"minigame_id": minigame_id,
		"score": score,
		"extra_data": extra_data,
		"timestamp": Time.get_unix_time_from_system()
	})
	_save_pending_scores()
	print("[ScoreManager] Score queued for later: %s = %d" % [minigame_id, score])


func _try_submit_pending_scores() -> void:
	"""Try to submit any pending scores"""
	if pending_scores.is_empty() or not AuthManager.is_logged_in:
		return
	
	var scores_to_submit = pending_scores.duplicate()
	pending_scores.clear()
	
	for score_data in scores_to_submit:
		var response = await submit_score(
			score_data["minigame_id"],
			score_data["score"],
			score_data["extra_data"]
		)
		
		if not response.success:
			# Re-queue if still failing
			pending_scores.append(score_data)
	
	_save_pending_scores()


func _save_pending_scores() -> void:
	"""Save pending scores to file"""
	var file = FileAccess.open(PENDING_SCORES_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(pending_scores))
		file.close()


func _load_pending_scores() -> void:
	"""Load pending scores from file"""
	if not FileAccess.file_exists(PENDING_SCORES_PATH):
		return
	
	var file = FileAccess.open(PENDING_SCORES_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			pending_scores = json.data
		file.close()
#endregion

#region Local Cache
func _update_local_best(minigame_id: String, score: int) -> void:
	"""Update local best score"""
	if PlayerData:
		var current_best = PlayerData.get_minigame_best_score(minigame_id)
		if score > current_best:
			PlayerData.set_minigame_record(minigame_id, score)


func get_cached_leaderboard(minigame_id: String) -> Array:
	"""Get cached leaderboard (no network call)"""
	return cached_leaderboard.get(minigame_id, [])
#endregion

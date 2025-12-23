extends Node
## PlayerData - Player's persistent data with online support
## AutoLoad Singleton: Inventory, keys, collectibles, minigame progress, online scores

#region Signals
signal keys_changed(total_keys: int)
signal inventory_changed(item_id: String, amount: int)
signal collectible_found(collectible_id: String)
signal minigame_completed(minigame_id: String, map_name: String)
signal map_unlocked(map_name: String)
signal currency_changed(new_amount: int)
signal score_updated(minigame_id: String, new_score: int)
signal data_changed
#endregion

#region Player Identity (for online features)
var player_name: String = "Player"
var display_name: String = "Player"  # Shown on leaderboard
var player_id: String = ""           # Server-assigned ID
var player_email: String = ""        # For account
var player_avatar: int = 0           # Avatar index
#endregion

#region Online Statistics
var total_score: int = 0             # Sum of all best scores (for global ranking)
var minigames_played: int = 0        # Total attempts
var total_play_sessions: int = 0     # Number of times played
var highest_streak: int = 0          # Consecutive wins
var current_streak: int = 0          # Current win streak
#endregion

#region Keys System (Global collectibles found in minigames)
var keys_collected: Dictionary = {}  # {"key_id": true}
var total_keys: int = 0

func collect_key(key_id: String, map_name: String = "") -> void:
	"""Collect a key (usually from minigames)"""
	var full_id = key_id if map_name.is_empty() else "%s_%s" % [map_name, key_id]
	
	if not keys_collected.has(full_id):
		keys_collected[full_id] = true
		total_keys += 1
		keys_changed.emit(total_keys)
		data_changed.emit()
		print("[PlayerData] Key collected: %s (Total: %d)" % [full_id, total_keys])


func has_key(key_id: String, map_name: String = "") -> bool:
	"""Check if player has a specific key"""
	var full_id = key_id if map_name.is_empty() else "%s_%s" % [map_name, key_id]
	return keys_collected.has(full_id)


func get_keys_for_map(map_name: String) -> Array:
	"""Get all keys collected in a specific map"""
	var map_keys: Array = []
	for key_id in keys_collected.keys():
		if key_id.begins_with(map_name + "_"):
			map_keys.append(key_id)
	return map_keys


func get_total_keys() -> int:
	return total_keys
#endregion

#region Main Inventory (Persistent items across game)
var inventory: Dictionary = {}  # {"item_id": amount}
var special_items: Array[String] = []  # Unique story items

func add_item(item_id: String, amount: int = 1) -> void:
	"""Add item to inventory"""
	if inventory.has(item_id):
		inventory[item_id] += amount
	else:
		inventory[item_id] = amount
	
	inventory_changed.emit(item_id, inventory[item_id])
	data_changed.emit()
	print("[PlayerData] Added %d x %s" % [amount, item_id])


func remove_item(item_id: String, amount: int = 1) -> bool:
	"""Remove item from inventory. Returns false if not enough."""
	if not has_item(item_id, amount):
		return false
	
	inventory[item_id] -= amount
	if inventory[item_id] <= 0:
		inventory.erase(item_id)
		inventory_changed.emit(item_id, 0)
	else:
		inventory_changed.emit(item_id, inventory[item_id])
	
	data_changed.emit()
	print("[PlayerData] Removed %d x %s" % [amount, item_id])
	return true


func has_item(item_id: String, amount: int = 1) -> bool:
	"""Check if player has enough of an item"""
	return inventory.get(item_id, 0) >= amount


func get_item_count(item_id: String) -> int:
	"""Get quantity of an item"""
	return inventory.get(item_id, 0)


func add_special_item(item_id: String) -> void:
	"""Add a unique/story item"""
	if item_id not in special_items:
		special_items.append(item_id)
		data_changed.emit()
		print("[PlayerData] Special item acquired: %s" % item_id)


func has_special_item(item_id: String) -> bool:
	"""Check if player has a special item"""
	return item_id in special_items
#endregion

#region Currency
var currency: int = 0

func add_currency(amount: int) -> void:
	"""Add currency"""
	currency += amount
	currency_changed.emit(currency)
	data_changed.emit()
	print("[PlayerData] Currency +%d (Total: %d)" % [amount, currency])


func spend_currency(amount: int) -> bool:
	"""Spend currency. Returns false if not enough."""
	if currency < amount:
		return false
	
	currency -= amount
	currency_changed.emit(currency)
	data_changed.emit()
	print("[PlayerData] Currency -%d (Total: %d)" % [amount, currency])
	return true


func get_currency() -> int:
	return currency
#endregion

#region Collectibles (Achievements, photos, artifacts, etc.)
var collectibles: Dictionary = {}  # {"collectible_id": {data}}

func add_collectible(collectible_id: String, data: Dictionary = {}) -> void:
	"""Add a collectible with optional metadata"""
	if not collectibles.has(collectible_id):
		collectibles[collectible_id] = {
			"found_at": Time.get_datetime_string_from_system(),
			"data": data
		}
		collectible_found.emit(collectible_id)
		data_changed.emit()
		print("[PlayerData] Collectible found: %s" % collectible_id)


func has_collectible(collectible_id: String) -> bool:
	return collectibles.has(collectible_id)


func get_collectible_count() -> int:
	return collectibles.size()
#endregion

#region Minigame Progress & Scores
var completed_minigames: Dictionary = {}  # {"map_name": {"minigame_id": {score, time, stars, etc}}}
var minigame_records: Dictionary = {}     # {"minigame_id": {best_score, best_time, stars}}

func complete_minigame(minigame_id: String, map_name: String, result_data: Dictionary = {}) -> void:
	"""Mark a minigame as completed and record score"""
	if not completed_minigames.has(map_name):
		completed_minigames[map_name] = {}
	
	var was_new = not completed_minigames[map_name].has(minigame_id)
	var score = result_data.get("score", 0)
	var time_taken = result_data.get("time", result_data.get("time_taken", 0.0))
	var stars = result_data.get("stars", 0)
	var success = result_data.get("success", true)
	
	# Store completion data
	completed_minigames[map_name][minigame_id] = {
		"completed_at": Time.get_datetime_string_from_system(),
		"score": score,
		"time": time_taken,
		"stars": stars,
		"success": success
	}
	
	# Update records if score is better
	_update_minigame_record(minigame_id, score, time_taken, stars)
	
	# Update statistics
	minigames_played += 1
	
	# Update streak
	if success:
		current_streak += 1
		if current_streak > highest_streak:
			highest_streak = current_streak
	else:
		current_streak = 0
	
	# Recalculate total score
	_recalculate_total_score()
	
	if was_new:
		minigame_completed.emit(minigame_id, map_name)
		_check_map_unlock()
	
	score_updated.emit(minigame_id, score)
	data_changed.emit()
	
	print("[PlayerData] Minigame completed: %s/%s (Score: %d, Stars: %d)" % [map_name, minigame_id, score, stars])


func _update_minigame_record(minigame_id: String, score: int, time_taken: float, stars: int) -> void:
	"""Update best score/time/stars records"""
	if not minigame_records.has(minigame_id):
		minigame_records[minigame_id] = {
			"best_score": 0,
			"best_time": 999999.0,
			"stars": 0,
			"attempts": 0
		}
	
	var record = minigame_records[minigame_id]
	record["attempts"] = record.get("attempts", 0) + 1
	
	# Update if better
	if score > record["best_score"]:
		record["best_score"] = score
		print("[PlayerData] New best score for %s: %d" % [minigame_id, score])
	
	if time_taken > 0 and time_taken < record["best_time"]:
		record["best_time"] = time_taken
	
	if stars > record["stars"]:
		record["stars"] = stars


func _recalculate_total_score() -> void:
	"""Recalculate total score from all best scores"""
	total_score = 0
	for minigame_id in minigame_records:
		total_score += minigame_records[minigame_id].get("best_score", 0)


func is_minigame_completed(minigame_id: String, map_name: String = "") -> bool:
	"""Check if a specific minigame is completed"""
	if map_name.is_empty():
		# Check all maps
		for m in completed_minigames.values():
			if m.has(minigame_id):
				return true
		return false
	
	if completed_minigames.has(map_name):
		return completed_minigames[map_name].has(minigame_id)
	return false


func get_minigame_result(minigame_id: String, map_name: String) -> Dictionary:
	"""Get completion data for a minigame"""
	if completed_minigames.has(map_name):
		return completed_minigames[map_name].get(minigame_id, {})
	return {}


func get_completed_minigame_count(map_name: String) -> int:
	"""Get number of completed minigames for a map"""
	if completed_minigames.has(map_name):
		return completed_minigames[map_name].size()
	return 0


func get_total_completed_minigames() -> int:
	"""Get total completed minigames across all maps"""
	var total = 0
	for map_data in completed_minigames.values():
		total += map_data.size()
	return total


func get_completed_minigames_for_map(map_name: String) -> Array:
	"""Get list of completed minigame IDs for a map"""
	if completed_minigames.has(map_name):
		return completed_minigames[map_name].keys()
	return []


func get_minigame_best_score(minigame_id: String) -> int:
	"""Get best score for a minigame"""
	if minigame_records.has(minigame_id):
		return minigame_records[minigame_id].get("best_score", 0)
	return 0


func get_minigame_best_time(minigame_id: String) -> float:
	"""Get best time for a minigame"""
	if minigame_records.has(minigame_id):
		return minigame_records[minigame_id].get("best_time", 999999.0)
	return 999999.0


func get_minigame_stars(minigame_id: String) -> int:
	"""Get stars earned for a minigame"""
	if minigame_records.has(minigame_id):
		return minigame_records[minigame_id].get("stars", 0)
	return 0


func get_minigame_attempts(minigame_id: String) -> int:
	"""Get number of attempts for a minigame"""
	if minigame_records.has(minigame_id):
		return minigame_records[minigame_id].get("attempts", 0)
	return 0


func set_minigame_record(minigame_id: String, score: int) -> void:
	"""Set best score (used when loading from server)"""
	if not minigame_records.has(minigame_id):
		minigame_records[minigame_id] = {
			"best_score": 0,
			"best_time": 999999.0,
			"stars": 0,
			"attempts": 0
		}
	
	var current_best = minigame_records[minigame_id].get("best_score", 0)
	if score > current_best:
		minigame_records[minigame_id]["best_score"] = score
		_recalculate_total_score()
		data_changed.emit()
#endregion

#region Score & Statistics Getters
func get_total_score() -> int:
	"""Get total score across all minigames (for leaderboard)"""
	return total_score


func get_total_stars() -> int:
	"""Get total stars earned"""
	var stars = 0
	for record in minigame_records.values():
		stars += record.get("stars", 0)
	return stars


func get_completion_percentage() -> float:
	"""Get overall game completion percentage"""
	var total_minigames = 12  # Adjust based on your game
	return float(get_total_completed_minigames()) / float(total_minigames) * 100.0


func get_average_score() -> float:
	"""Get average score across all minigames"""
	if minigame_records.is_empty():
		return 0.0
	
	var total = 0.0
	for record in minigame_records.values():
		total += record.get("best_score", 0)
	
	return total / minigame_records.size()


func get_statistics() -> Dictionary:
	"""Get all player statistics for display"""
	return {
		"total_score": total_score,
		"total_stars": get_total_stars(),
		"total_keys": total_keys,
		"minigames_completed": get_total_completed_minigames(),
		"minigames_played": minigames_played,
		"completion_percentage": get_completion_percentage(),
		"play_time": play_time,
		"play_time_formatted": get_formatted_play_time(),
		"highest_streak": highest_streak,
		"current_streak": current_streak,
		"currency": currency,
		"maps_unlocked": unlocked_maps.size()
	}
#endregion

#region Map Unlock System
var unlocked_maps: Array[String] = ["bhaktapur"]

func unlock_map(map_name: String) -> void:
	"""Unlock a map for the player"""
	if map_name not in unlocked_maps:
		unlocked_maps.append(map_name)
		map_unlocked.emit(map_name)
		data_changed.emit()
		print("[PlayerData] Map unlocked: %s" % map_name)


func is_map_unlocked(map_name: String) -> bool:
	"""Check if a map is unlocked"""
	return map_name in unlocked_maps


func _check_map_unlock() -> void:
	"""Check if any new maps should be unlocked based on progress"""
	if get_completed_minigame_count("bhaktapur") >= 3:
		unlock_map("kathmandu")
	
	if get_completed_minigame_count("kathmandu") >= 3:
		unlock_map("patan")
	
	if get_completed_minigame_count("patan") >= 3:
		unlock_map("kathmandu_university")
#endregion

#region Map Positions (Last known position on each map)
var map_positions: Dictionary = {}  # {"map_name": Vector2}

func save_map_position(map_name: String, position: Vector2) -> void:
	"""Save player's position on a map"""
	map_positions[map_name] = position


func get_map_position(map_name: String) -> Vector2:
	"""Get saved position for a map (Vector2.ZERO if none)"""
	return map_positions.get(map_name, Vector2.ZERO)
#endregion

#region Play Statistics
var play_time: float = 0.0
var session_start_time: float = 0.0

func _ready() -> void:
	session_start_time = Time.get_unix_time_from_system()
	total_play_sessions += 1
	print("[PlayerData] Initialized (Session #%d)" % total_play_sessions)


func _process(delta: float) -> void:
	# Track play time when game is active
	if not get_tree().paused:
		play_time += delta


func get_formatted_play_time() -> String:
	"""Get play time as formatted string (HH:MM:SS)"""
	var hours = int(play_time / 3600)
	var minutes = int(fmod(play_time, 3600) / 60)
	var seconds = int(fmod(play_time, 60))
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func get_session_time() -> float:
	"""Get current session duration"""
	return Time.get_unix_time_from_system() - session_start_time
#endregion

#region Save/Load Data Conversion
func to_dictionary() -> Dictionary:
	"""Convert all player data to dictionary for saving"""
	return {
		# Identity
		"player_name": player_name,
		"display_name": display_name,
		"player_id": player_id,
		"player_email": player_email,
		"player_avatar": player_avatar,
		
		# Statistics
		"total_score": total_score,
		"minigames_played": minigames_played,
		"total_play_sessions": total_play_sessions,
		"highest_streak": highest_streak,
		"current_streak": current_streak,
		
		# Keys & Collectibles
		"keys_collected": keys_collected,
		"total_keys": total_keys,
		"collectibles": collectibles,
		
		# Inventory
		"inventory": inventory,
		"special_items": special_items,
		"currency": currency,
		
		# Progress
		"completed_minigames": completed_minigames,
		"minigame_records": minigame_records,
		"unlocked_maps": unlocked_maps,
		
		# Position & Time
		"map_positions": _vector2_dict_to_array(map_positions),
		"play_time": play_time
	}


func load_from_dictionary(data: Dictionary) -> void:
	"""Load player data from dictionary"""
	# Identity
	player_name = data.get("player_name", "Player")
	display_name = data.get("display_name", player_name)
	player_id = data.get("player_id", "")
	player_email = data.get("player_email", "")
	player_avatar = int(data.get("player_avatar", 0))
	
	# Statistics
	total_score = int(data.get("total_score", 0))
	minigames_played = int(data.get("minigames_played", 0))
	total_play_sessions = int(data.get("total_play_sessions", 0))
	highest_streak = int(data.get("highest_streak", 0))
	current_streak = int(data.get("current_streak", 0))
	
	# Keys & Collectibles
	keys_collected = data.get("keys_collected", {})
	total_keys = int(data.get("total_keys", 0))
	collectibles = data.get("collectibles", {})
	
	# Inventory
	inventory = data.get("inventory", {})
	special_items.assign(data.get("special_items", []))
	currency = int(data.get("currency", 0))
	
	# Progress
	completed_minigames = data.get("completed_minigames", {})
	minigame_records = data.get("minigame_records", {})
	unlocked_maps.assign(data.get("unlocked_maps", ["bhaktapur"]))
	
	# Position & Time
	map_positions = _array_dict_to_vector2(data.get("map_positions", {}))
	play_time = float(data.get("play_time", 0.0))
	
	# Recalculate derived values
	_recalculate_total_score()
	
	data_changed.emit()
	print("[PlayerData] Data loaded - Score: %d, Completed: %d" % [total_score, get_total_completed_minigames()])


func reset_all() -> void:
	"""Reset all player data (for new game)"""
	# Identity (keep some)
	# player_name = "Player"  # Keep name
	# display_name = "Player"  # Keep name
	# player_id = ""  # Keep ID
	# player_email = ""  # Keep email
	player_avatar = 0
	
	# Statistics
	total_score = 0
	minigames_played = 0
	highest_streak = 0
	current_streak = 0
	# total_play_sessions += 1  # Don't reset
	
	# Keys & Collectibles
	keys_collected.clear()
	total_keys = 0
	collectibles.clear()
	
	# Inventory
	inventory.clear()
	special_items.clear()
	currency = 0
	
	# Progress
	completed_minigames.clear()
	minigame_records.clear()
	unlocked_maps = ["bhaktapur"]
	
	# Position & Time
	map_positions.clear()
	play_time = 0.0
	
	data_changed.emit()
	print("[PlayerData] All progress reset (account preserved)")


func reset_all_including_account() -> void:
	"""Full reset including account data"""
	player_name = "Player"
	display_name = "Player"
	player_id = ""
	player_email = ""
	player_avatar = 0
	total_play_sessions = 0
	
	reset_all()
	print("[PlayerData] Complete reset including account")


# Helper functions for Vector2 serialization
func _vector2_dict_to_array(dict: Dictionary) -> Dictionary:
	var result = {}
	for key in dict.keys():
		var vec: Vector2 = dict[key]
		result[key] = [vec.x, vec.y]
	return result


func _array_dict_to_vector2(dict: Dictionary) -> Dictionary:
	var result = {}
	for key in dict.keys():
		var arr = dict[key]
		if arr is Array and arr.size() >= 2:
			result[key] = Vector2(float(arr[0]), float(arr[1]))
		elif arr is Dictionary:
			result[key] = Vector2(float(arr.get("x", 0)), float(arr.get("y", 0)))
	return result
#endregion

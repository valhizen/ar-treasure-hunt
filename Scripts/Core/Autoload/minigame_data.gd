extends Resource
class_name MinigameData
## MinigameData - Configuration resource for a minigame
## Create one of these for each minigame and assign it to triggers

@export_category("Identity")
@export var minigame_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var map_name: String = ""  # Which map this minigame belongs to

@export_category("Scene")
@export_file("*.tscn") var scene_path: String = ""
@export var icon: Texture2D = null

@export_category("Difficulty & Rewards")
@export_enum("Easy", "Medium", "Hard") var difficulty: int = 0
@export var max_score: int = 1000
@export var time_limit: float = 0.0  # 0 = no limit
@export var keys_available: int = 0
@export var base_currency_reward: int = 10

@export_category("Star Thresholds")
## Score percentage needed for each star (0-100)
@export var star_1_threshold: int = 30
@export var star_2_threshold: int = 60
@export var star_3_threshold: int = 90

@export_category("Requirements")
@export var required_keys: int = 0  # Keys needed to unlock
@export var required_items: Array[String] = []  # Items needed to play
@export var prerequisite_minigames: Array[String] = []  # Must complete these first

@export_category("Custom Settings")
## Any minigame-specific configuration data
@export var custom_settings: Dictionary = {}


func get_stars_for_score(score: int) -> int:
	"""Calculate stars earned based on score"""
	var percentage = float(score) / float(max_score) * 100.0 if max_score > 0 else 0.0
	
	if percentage >= star_3_threshold:
		return 3
	elif percentage >= star_2_threshold:
		return 2
	elif percentage >= star_1_threshold:
		return 1
	return 0


func calculate_rewards(score: int, time_taken: float) -> Dictionary:
	"""Calculate rewards based on performance"""
	var stars = get_stars_for_score(score)
	var currency = base_currency_reward * (stars + 1)
	
	# Bonus for fast completion if there's a time limit
	if time_limit > 0 and time_taken < time_limit * 0.5:
		currency = int(currency * 1.5)
	
	return {
		"stars": stars,
		"currency": currency
	}


func is_unlocked() -> bool:
	"""Check if this minigame is unlocked for the player"""
	# Check key requirement
	if required_keys > 0:
		var player_data = Engine.get_singleton("PlayerData") if Engine.has_singleton("PlayerData") else null
		if player_data and player_data.total_keys < required_keys:
			return false
	
	# Check item requirements
	for item_id in required_items:
		var player_data = Engine.get_singleton("PlayerData") if Engine.has_singleton("PlayerData") else null
		if player_data and not player_data.has_item(item_id):
			return false
	
	# Check prerequisite minigames
	for prereq_id in prerequisite_minigames:
		var player_data = Engine.get_singleton("PlayerData") if Engine.has_singleton("PlayerData") else null
		if player_data and not player_data.is_minigame_completed(prereq_id):
			return false
	
	return true


func get_difficulty_name() -> String:
	match difficulty:
		0: return "Easy"
		1: return "Medium"
		2: return "Hard"
		_: return "Unknown"


func to_registry_entry() -> Dictionary:
	"""Convert to format used by MinigameManager registry"""
	return {
		"id": minigame_id,
		"display_name": display_name,
		"description": description,
		"map": map_name,
		"scene_path": scene_path,
		"difficulty": difficulty,
		"max_score": max_score,
		"time_limit": time_limit,
		"keys_available": keys_available,
		"base_currency_reward": base_currency_reward,
		"star_thresholds": [star_1_threshold, star_2_threshold, star_3_threshold],
		"required_keys": required_keys,
		"required_items": required_items,
		"prerequisite_minigames": prerequisite_minigames,
		"custom_settings": custom_settings
	}

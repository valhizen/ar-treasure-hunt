extends Resource
class_name MinigameResult
## MinigameResult - Stores the outcome of a minigame session

var minigame_id: String = ""
var map_name: String = ""

# Core results
var success: bool = false
var score: int = 0
var time_taken: float = 0.0
var stars: int = 0

# Rewards
var keys_found: Array[String] = []
var items_awarded: Array = []
var currency_awarded: int = 0

# Failure info
var failure_reason: String = ""

# Custom data
var custom_data: Dictionary = {}


static func create_success(mg_id: String, mg_score: int, mg_time: float = 0.0, mg_stars: int = 0) -> MinigameResult:
	var result = MinigameResult.new()
	result.minigame_id = mg_id
	result.success = true
	result.score = mg_score
	result.time_taken = mg_time
	result.stars = mg_stars
	return result


static func create_failure(mg_id: String, reason: String = "Failed") -> MinigameResult:
	var result = MinigameResult.new()
	result.minigame_id = mg_id
	result.success = false
	result.failure_reason = reason
	return result


func to_dictionary() -> Dictionary:
	return {
		"minigame_id": minigame_id,
		"map_name": map_name,
		"success": success,
		"score": score,
		"time_taken": time_taken,
		"stars": stars,
		"keys_found": keys_found,
		"items_awarded": items_awarded,
		"currency_awarded": currency_awarded,
		"failure_reason": failure_reason,
		"custom_data": custom_data
	}
